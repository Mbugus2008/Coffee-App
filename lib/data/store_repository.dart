import 'package:flutter/foundation.dart';

import 'item_api.dart';
import 'store_models.dart';
import '../services/bc/bc_services.dart';
import 'user_database.dart';

class StoreSyncResult {
  const StoreSyncResult({
    required this.attempted,
    required this.synced,
    required this.failed,
    this.lastError,
    this.failureDetails = const [],
  });

  final int attempted;
  final int synced;
  final int failed;
  final String? lastError;
  final List<String> failureDetails;
}

class StoreRepository extends ChangeNotifier {
  StoreRepository(this._db, {ItemApi? itemApi})
    : _itemApi = itemApi ?? ItemApi();

  final UserDatabase _db;
  final ItemApi _itemApi;
  final List<StoreHeader> _headers = [];
  final List<Item> _items = [];

  List<StoreHeader> get headers => List.unmodifiable(_headers);
  List<Item> get items => List.unmodifiable(_items);

  Future<void> loadStoreHeaders() async {
    final loaded = await _db.getStoreHeaders();
    _headers
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> addStoreHeader(StoreHeader header) async {
    await _db.insertStoreHeader(header);
    await loadStoreHeaders();
  }

  Future<void> updateStoreHeader(StoreHeader header) async {
    await _db.updateStoreHeader(header);
    await loadStoreHeaders();
  }

  Future<List<Store>> loadStoreLines(String entry) {
    return _db.getStoresByEntry(entry);
  }

  Future<void> createStore(Store store) {
    return addStoreLineAndUpdateHeader(store);
  }

  Future<List<Store>> readStoresByEntry(String entry) {
    return loadStoreLines(entry);
  }

  Future<void> updateStore(Store store) {
    return updateStoreLineAndUpdateHeader(store);
  }

  Future<void> deleteStore({required int id, required String entry}) {
    return deleteStoreLineAndUpdateHeader(lineId: id, entry: entry);
  }

  Future<void> addStoreLine(Store line) async {
    await _db.insertStore(line);
  }

  Future<void> addStoreLineAndUpdateHeader(Store line) async {
    await _db.insertStore(line);

    final header = await _db.getStoreHeaderByEntry(line.entry);
    if (header == null) return;

    final lines = await _db.getStoresByEntry(line.entry);
    final recomputedTotal = lines.fold<double>(
      0,
      (sum, item) => sum + (item.amount ?? 0),
    );

    final amountPaid = header.amountPaid ?? 0;
    final updatedHeader = header.copyWith(
      total: recomputedTotal,
      itemCount: lines.length,
      balance: recomputedTotal - amountPaid,
    );

    await _db.updateStoreHeader(updatedHeader);
    await loadStoreHeaders();
  }

  Future<void> updateStoreLineAndUpdateHeader(Store line) async {
    await _db.updateStore(line);

    final header = await _db.getStoreHeaderByEntry(line.entry);
    if (header == null) return;

    final lines = await _db.getStoresByEntry(line.entry);
    final recomputedTotal = lines.fold<double>(
      0,
      (sum, item) => sum + (item.amount ?? 0),
    );

    final amountPaid = header.amountPaid ?? 0;
    final updatedHeader = header.copyWith(
      total: recomputedTotal,
      itemCount: lines.length,
      balance: recomputedTotal - amountPaid,
    );

    await _db.updateStoreHeader(updatedHeader);
    await loadStoreHeaders();
  }

  Future<void> deleteStoreLineAndUpdateHeader({
    required int lineId,
    required String entry,
  }) async {
    await _db.deleteStoreById(lineId);

    final header = await _db.getStoreHeaderByEntry(entry);
    if (header == null) return;

    final lines = await _db.getStoresByEntry(entry);
    final recomputedTotal = lines.fold<double>(
      0,
      (sum, item) => sum + (item.amount ?? 0),
    );

    final amountPaid = header.amountPaid ?? 0;
    final updatedHeader = header.copyWith(
      total: recomputedTotal,
      itemCount: lines.length,
      balance: recomputedTotal - amountPaid,
    );

    await _db.updateStoreHeader(updatedHeader);
    await loadStoreHeaders();
  }

  Future<void> loadItems() async {
    var loaded = await _db.getItems();
    if (loaded.isEmpty) {
      await _seedSampleItems();
      loaded = await _db.getItems();
    }
    _items
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> refreshItemsFromServer() async {
    try {
      final remoteItems = await _itemApi.fetchItems();
      if (remoteItems.isNotEmpty) {
        await _db.replaceItems(remoteItems);
      }
    } catch (_) {
      // Keep using local cache when BC is unreachable.
    }

    await loadItems();
  }

  Future<StoreSyncResult> syncWithBc() async {
    return syncPendingToBc();
  }

  Future<StoreSyncResult> syncPendingToBc() async {
    final pendingHeaders = await _db.getPendingStoreHeaders();
    final pendingLines = await _db.getPendingStores();

    final attempted = pendingHeaders.length + pendingLines.length;
    if (attempted == 0) {
      return const StoreSyncResult(attempted: 0, synced: 0, failed: 0);
    }

    var synced = 0;
    var failed = 0;
    String? lastError;
    final failureDetails = <String>[];

    for (final header in pendingHeaders) {
      try {
        await BcServices.instance.createStoreHeader(header);
        await _db.updateStoreHeaderBcSyncStatus(
          entry: header.entry,
          status: 'synced',
        );
        synced += 1;
      } catch (error) {
        lastError = error.toString();
        failed += 1;
        failureDetails.add('Header ${header.entry}: $lastError');
        debugPrint('Failed to sync store header to BC: $error');
        await _db.updateStoreHeaderBcSyncStatus(
          entry: header.entry,
          status: 'failed',
        );
      }
    }

    for (final line in pendingLines) {
      final id = line.id;
      if (id == null) {
        failed += 1;
        failureDetails.add('Line without local ID for entry ${line.entry}.');
        continue;
      }

      try {
        await BcServices.instance.createStoreLine(line);
        await _db.updateStoreBcSyncStatus(id: id, status: 'synced');
        synced += 1;
      } catch (error) {
        lastError = error.toString();
        failed += 1;
        failureDetails.add('Line $id (${line.entry}): $lastError');
        debugPrint('Failed to sync store line to BC: $error');
        await _db.updateStoreBcSyncStatus(id: id, status: 'failed');
      }
    }

    await loadStoreHeaders();

    return StoreSyncResult(
      attempted: attempted,
      synced: synced,
      failed: failed,
      lastError: lastError,
      failureDetails: failureDetails,
    );
  }

  Future<void> _seedSampleItems() async {
    final samples = <Item>[
      const Item(
        no: 'ITM001',
        description: 'Fertilizer 50kg',
        baseUnitOfMeasure: 'Bag',
        lastDirectCost: 2100,
        unitCost: 2200,
        unitPrice: 2300,
        inventory: 100,
        preventNegativeInventory: 1,
      ),
      const Item(
        no: 'ITM002',
        description: 'Pesticide 1L',
        baseUnitOfMeasure: 'Bottle',
        lastDirectCost: 850,
        unitCost: 900,
        unitPrice: 950,
        inventory: 200,
        preventNegativeInventory: 1,
      ),
      const Item(
        no: 'ITM003',
        description: 'Seedlings',
        baseUnitOfMeasure: 'Unit',
        lastDirectCost: 45,
        unitCost: 50,
        unitPrice: 60,
        inventory: 1000,
        preventNegativeInventory: 0,
      ),
    ];

    for (final item in samples) {
      await _db.insertItem(item);
    }
  }
}
