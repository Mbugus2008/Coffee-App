import 'package:flutter/foundation.dart';

import 'farmer_api.dart';
import 'farmer_model.dart';
import 'user_database.dart';
import 'user_repository.dart';

class FarmerSaveResult {
  const FarmerSaveResult({
    required this.savedLocally,
    required this.syncedToBc,
    this.syncError,
  });

  final bool savedLocally;
  final bool syncedToBc;
  final String? syncError;
}

class FarmerRepository extends ChangeNotifier {
  FarmerRepository(this._db, {FarmerApi? api}) : _api = api ?? FarmerApi();

  final UserDatabase _db;
  final FarmerApi _api;
  final List<Farmer> _farmers = [];
  final Set<String> _failedSyncNos = <String>{};

  List<Farmer> get farmers => List.unmodifiable(_farmers);

  String _normalizeNo(String farmerNo) => farmerNo.trim().toLowerCase();

  bool isFarmerSyncFailed(String farmerNo) {
    final key = _normalizeNo(farmerNo);
    if (key.isEmpty) {
      return false;
    }
    return _failedSyncNos.contains(key);
  }

  void _markSyncFailed(String farmerNo) {
    final key = _normalizeNo(farmerNo);
    if (key.isEmpty) {
      return;
    }
    _failedSyncNos.add(key);
  }

  void _clearSyncFailed(String farmerNo) {
    final key = _normalizeNo(farmerNo);
    if (key.isEmpty) {
      return;
    }
    _failedSyncNos.remove(key);
  }

  bool hasFarmerNo(String farmerNo, {String? excludingNo}) {
    final normalizedNo = farmerNo.trim().toLowerCase();
    if (normalizedNo.isEmpty) {
      return false;
    }

    final excluded = excludingNo?.trim().toLowerCase();
    return _farmers.any((farmer) {
      final currentNo = farmer.no.trim().toLowerCase();
      if (excluded != null && currentNo == excluded) {
        return false;
      }
      return currentNo == normalizedNo;
    });
  }

  Future<void> loadFarmers() async {
    final loaded = await _db.getFarmers();
    _farmers
      ..clear()
      ..addAll(loaded);

    final pendingNos = <String>{
      for (final farmer in loaded)
        if (farmer.updated == true) _normalizeNo(farmer.no),
    };
    _failedSyncNos.removeWhere((key) => !pendingNos.contains(key));

    notifyListeners();
  }

  Future<void> syncFromServer(List<Farmer> farmers) async {
    final local = await _db.getFarmers();
    final localByNo = <String, Farmer>{
      for (final farmer in local) farmer.no.trim().toLowerCase(): farmer,
    };

    final merged = <Farmer>[];
    final seen = <String>{};
    for (final remote in farmers) {
      final key = remote.no.trim().toLowerCase();
      seen.add(key);
      final localFarmer = localByNo[key];
      final localDirty = (localFarmer?.updated ?? false) == true;
      if (localDirty) {
        merged.add(localFarmer!);
      } else {
        merged.add(remote.copyWith(updated: false));
      }
    }

    for (final localFarmer in local) {
      final key = localFarmer.no.trim().toLowerCase();
      if (!seen.contains(key) && (localFarmer.updated ?? false) == true) {
        merged.add(localFarmer);
      }
    }

    await _db.replaceFarmers(merged);
    await loadFarmers();
  }

  Future<void> refreshFromServer() async {
    final farmers = await _api.fetchFarmers();
    if (farmers.isEmpty) {
      await loadFarmers();
      return;
    }
    await syncFromServer(farmers);
    await retryPendingFarmerSyncs();
    await UserRepository(_db).retryPendingPasswordSyncs();
  }

  Future<FarmerSaveResult> addFarmer(Farmer farmer) async {
    if (hasFarmerNo(farmer.no)) {
      return const FarmerSaveResult(
        savedLocally: false,
        syncedToBc: false,
        syncError: 'Farmer number already exists.',
      );
    }

    final localFarmer = farmer.copyWith(updated: true);
    await _db.insertFarmer(localFarmer);
    await loadFarmers();

    var syncedToBc = false;
    String? syncError;
    try {
      await _api.createFarmer(localFarmer);
      syncedToBc = true;
      await _db.clearFarmerUpdatedFlag(localFarmer.no);
      _clearSyncFailed(localFarmer.no);
    } catch (error, stackTrace) {
      _markSyncFailed(localFarmer.no);
      syncError = error.toString();
      debugPrint(
        'BC farmer create failed for "${localFarmer.no}": $error\n$stackTrace',
      );
    }

    await loadFarmers();
    return FarmerSaveResult(
      savedLocally: true,
      syncedToBc: syncedToBc,
      syncError: syncError,
    );
  }

  Future<FarmerSaveResult> updateFarmer(Farmer farmer) async {
    final localFarmer = farmer.copyWith(updated: true);
    await _db.updateFarmer(localFarmer);
    await loadFarmers();

    var syncedToBc = false;
    String? syncError;
    try {
      await _api.updateFarmer(localFarmer);
      syncedToBc = true;
      await _db.clearFarmerUpdatedFlag(localFarmer.no);
      _clearSyncFailed(localFarmer.no);
    } catch (error, stackTrace) {
      _markSyncFailed(localFarmer.no);
      syncError = error.toString();
      debugPrint(
        'BC farmer update failed for "${localFarmer.no}": $error\n$stackTrace',
      );
    }

    await loadFarmers();
    return FarmerSaveResult(
      savedLocally: true,
      syncedToBc: syncedToBc,
      syncError: syncError,
    );
  }

  Future<void> retryPendingFarmerSyncs() async {
    final pending = await _db.getFarmersWithPendingSync();
    for (final farmer in pending) {
      try {
        await _api.updateFarmer(farmer);
        await _db.clearFarmerUpdatedFlag(farmer.no);
        _clearSyncFailed(farmer.no);
      } catch (error, stackTrace) {
        final message = error.toString().toLowerCase();
        final missingInBc = message.contains('not found');
        if (missingInBc) {
          try {
            await _api.createFarmer(farmer);
            await _db.clearFarmerUpdatedFlag(farmer.no);
            _clearSyncFailed(farmer.no);
            continue;
          } catch (createError, createStackTrace) {
            _markSyncFailed(farmer.no);
            debugPrint(
              'Retry BC farmer create failed for "${farmer.no}": $createError\n$createStackTrace',
            );
          }
        }
        _markSyncFailed(farmer.no);
        debugPrint(
          'Retry BC farmer sync failed for "${farmer.no}": $error\n$stackTrace',
        );
      }
    }
    await loadFarmers();
  }
}
