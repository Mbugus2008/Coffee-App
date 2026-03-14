import 'package:flutter/foundation.dart';

import 'store_models.dart';
import 'user_database.dart';

class StoreRepository extends ChangeNotifier {
  StoreRepository(this._db);

  final UserDatabase _db;
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

  Future<void> addStoreLine(Store line) async {
    await _db.insertStore(line);
  }

  Future<void> addStoreLineAndUpdateHeader(Store line) async {
    await _db.insertStore(line);

    final header = await _db.getStoreHeaderByEntry(line.entry);
    if (header == null) return;

    final lines = await _db.getStoresByEntry(line.entry);
    final recomputedTotal = lines.fold<double>(0, (sum, item) {
      final lineTotal = item.lineTotal ?? ((item.amount ?? 0) * (item.quantity ?? 0));
      return sum + lineTotal;
    });

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
