import 'package:flutter/foundation.dart';

import '../services/bc/bc_services.dart';
import '../services/bc/bc_settings_store.dart';
import 'daily_collection_api.dart';
import 'daily_collection_model.dart';
import 'user_database.dart';
import 'user_repository.dart';

class DailyCollectionSaveResult {
  const DailyCollectionSaveResult({
    required this.savedLocally,
    required this.syncedToBc,
    this.syncError,
  });

  final bool savedLocally;
  final bool syncedToBc;
  final String? syncError;
}

class DailyCollectionSyncResult {
  const DailyCollectionSyncResult({
    required this.attempted,
    required this.synced,
    required this.failed,
    this.fetchedFromBc = 0,
    this.refreshError,
    this.lastError,
    this.failureDetails = const [],
  });

  final int attempted;
  final int synced;
  final int failed;
  final int fetchedFromBc;
  final String? refreshError;
  final String? lastError;
  final List<String> failureDetails;
}

class DailyCollectionRepository extends ChangeNotifier {
  DailyCollectionRepository(this._db, {DailyCollectionApi? api})
    : _api = api ?? DailyCollectionApi();

  final UserDatabase _db;
  final DailyCollectionApi _api;
  final List<DailyCollection> _items = [];

  bool _isDuplicateCollectionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('internal_entitywithsamekeyexists') ||
        (message.contains('already exists') &&
            message.contains('collection number'));
  }

  List<DailyCollection> get items => List.unmodifiable(_items);

  Future<void> loadCollections() async {
    final loaded = await _db.getDailyCollections();
    _items
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> syncFromServer(List<DailyCollection> items) async {
    await _db.replaceDailyCollectionsFromServer(items);
    await loadCollections();
  }

  Future<int> refreshFromServer() async {
    final items = await _api.fetchDailyCollections();
    await syncFromServer(items);
    await UserRepository(_db).retryPendingPasswordSyncs();
    return items.length;
  }

  Future<DailyCollectionSyncResult> syncPendingToBc({int? onlyNo}) async {
    final pending = await _db.getPendingDailyCollections();
    final queue = onlyNo == null
        ? pending
        : pending.where((item) => item.no == onlyNo).toList();

    if (queue.isEmpty) {
      return const DailyCollectionSyncResult(
        attempted: 0,
        synced: 0,
        failed: 0,
      );
    }

    var synced = 0;
    var failed = 0;
    String? lastError;
    final failureDetails = <String>[];

    for (final item in queue) {
      try {
        await BcServices.instance.createDailyCollection(item);
        await _db.updateDailyCollectionBcSyncStatus(
          no: item.no,
          status: 'synced',
        );
        synced += 1;
      } catch (error) {
        if (_isDuplicateCollectionError(error)) {
          await _db.updateDailyCollectionBcSyncStatus(
            no: item.no,
            status: 'synced',
          );
          synced += 1;
          debugPrint(
            'Collection already exists in BC, marking as synced locally: ${item.collectionNumber}',
          );
          continue;
        }

        lastError = error.toString();
        failed += 1;
        final collectionNumber = item.collectionNumber.trim().isEmpty
            ? item.no.toString()
            : item.collectionNumber.trim();
        failureDetails.add('$collectionNumber: $lastError');
        debugPrint('Failed to sync collection to BC: $error');
        await _db.updateDailyCollectionBcSyncStatus(
          no: item.no,
          status: 'failed',
          error: lastError,
        );
      }
    }

    await loadCollections();
    return DailyCollectionSyncResult(
      attempted: queue.length,
      synced: synced,
      failed: failed,
      lastError: lastError,
      failureDetails: failureDetails,
    );
  }

  Future<DailyCollectionSyncResult> syncWithBc() async {
    final pendingResult = await syncPendingToBc();
    var fetchedFromBc = 0;
    String? refreshError;

    try {
      fetchedFromBc = await refreshFromServer();
    } catch (error) {
      refreshError = error.toString();
      debugPrint('Failed to refresh collections from BC: $error');
    }

    final combinedFailures = <String>[
      ...pendingResult.failureDetails,
      if (refreshError != null) 'Refresh from BC failed: $refreshError',
    ];

    return DailyCollectionSyncResult(
      attempted: pendingResult.attempted,
      synced: pendingResult.synced,
      failed: pendingResult.failed,
      fetchedFromBc: fetchedFromBc,
      refreshError: refreshError,
      lastError: pendingResult.lastError ?? refreshError,
      failureDetails: combinedFailures,
    );
  }

  Future<DailyCollectionSaveResult> addCollection(DailyCollection item) async {
    final settings = await BcSettingsStore.instance.load();
    final configuredFactory = settings.factory.trim();

    final toSave = configuredFactory.isEmpty
        ? item
        : DailyCollection(
            farmersNumber: item.farmersNumber,
            collectionsDate: item.collectionsDate,
            collectionNumber: item.collectionNumber,
            coffeeType: item.coffeeType,
            no: item.no,
            farmersName: item.farmersName,
            kgCollected: item.kgCollected,
            cancelled: item.cancelled,
            paid: item.paid,
            idNumber: item.idNumber,
            factory: configuredFactory,
            sent: item.sent,
            comments: item.comments,
            cumm: item.cumm,
            userName: item.userName,
            can: item.can,
            collectionTime: item.collectionTime,
            collectType: item.collectType,
            crop: item.crop,
            gross: item.gross,
            tare: item.tare,
            noOfBags: item.noOfBags,
            deliveredBy: item.deliveredBy,
            coffeTypeName: item.coffeTypeName,
            updated: item.updated,
          );

    await _db.insertPendingDailyCollection(toSave);
    await loadCollections();

    final syncResult = await syncPendingToBc(onlyNo: toSave.no);
    return DailyCollectionSaveResult(
      savedLocally: true,
      syncedToBc: syncResult.failed == 0,
      syncError: syncResult.lastError,
    );
  }
}
