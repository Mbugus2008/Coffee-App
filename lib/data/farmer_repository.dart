import 'package:flutter/foundation.dart';

import 'farmer_api.dart';
import 'farmer_model.dart';
import 'user_database.dart';
import 'user_repository.dart';

class FarmerRepository extends ChangeNotifier {
  FarmerRepository(this._db, {FarmerApi? api}) : _api = api ?? FarmerApi();

  final UserDatabase _db;
  final FarmerApi _api;
  final List<Farmer> _farmers = [];

  List<Farmer> get farmers => List.unmodifiable(_farmers);

  Future<void> loadFarmers() async {
    final loaded = await _db.getFarmers();
    _farmers
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> syncFromServer(List<Farmer> farmers) async {
    await _db.replaceFarmers(farmers);
    await loadFarmers();
  }

  Future<void> refreshFromServer() async {
    final farmers = await _api.fetchFarmers();
    if (farmers.isEmpty) {
      await loadFarmers();
      return;
    }
    await syncFromServer(farmers);
    await UserRepository(_db).retryPendingPasswordSyncs();
  }

  Future<void> addFarmer(Farmer farmer) async {
    await _db.insertFarmer(farmer);
    await loadFarmers();
  }

  Future<void> updateFarmer(Farmer farmer) async {
    await _db.updateFarmer(farmer);
    await loadFarmers();
  }
}
