import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'collection_settings_model.dart';
import 'daily_collection_model.dart';
import 'farmer_model.dart';
import 'store_models.dart';
import 'user_model.dart';

class UserDatabase {
  UserDatabase._();

  static final UserDatabase instance = UserDatabase._();

  static const _dbName = 'coffee.db';
  static const _dbVersion = 9;
  static const _tableCollectionSettings = 'collection_settings';
  static const _tableUsers = 'users';
  static const _tableFarmers = 'farmers';
  static const _tableDailyCollections = 'daily_collections';
  static const _tableStoreHeaders = 'store_headers';
  static const _tableStores = 'stores';
  static const _tableItems = 'items';

  Database? _database;
  bool _userSchemaEnsured = false;

  Future<Database> get database async {
    final db = _database;
    if (db != null) {
      if (!_userSchemaEnsured) {
        await _ensureUsersSchema(db);
      }
      return db;
    }
    _database = await _initDatabase();
    await _ensureUsersSchema(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final filePath = path.join(dbPath, _dbName);
    return openDatabase(
      filePath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableUsers('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, '
          'username TEXT NOT NULL, '
          'password TEXT NOT NULL, '
          'Type TEXT NOT NULL DEFAULT "", '
          'email TEXT NOT NULL, '
          'phone TEXT NOT NULL, '
          'Updated INTEGER NOT NULL DEFAULT 0'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableFarmers('
          'No TEXT PRIMARY KEY, '
          'Name TEXT NOT NULL, '
          'Phone TEXT NOT NULL, '
          'Email TEXT NOT NULL, '
          'ID_No TEXT NOT NULL, '
          'Cum_Cherry REAL, '
          'Cum_Mbuni REAL, '
          'Updated INTEGER, '
          'Account_Category INTEGER, '
          'Factory TEXT NOT NULL, '
          'Comments TEXT NOT NULL, '
          'Gender INTEGER, '
          'Bank TEXT NOT NULL, '
          'Bank_Account TEXT NOT NULL, '
          'Acreage REAL, '
          'No_of_Trees INTEGER, '
          'Other_Loans REAL, '
          'Previous_Crop_collection REAL, '
          'Limit_percentage REAL, '
          '"Limit" REAL, '
          'Total_Stores REAL, '
          'Current_Crop_collection_Cherry_1 REAL, '
          'Current_Crop_collection_Cherry_2 REAL, '
          'Current_Crop_collection REAL, '
          'Bank_Code TEXT NOT NULL, '
          'Bank_Name TEXT NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE TABLE $_tableDailyCollections('
          'Farmers_Number TEXT NOT NULL, '
          'Collections_Date TEXT NOT NULL, '
          'Collection_Number TEXT NOT NULL, '
          'Coffee_Type TEXT NOT NULL, '
          'No_ INTEGER PRIMARY KEY, '
          'Farmers_Name TEXT NOT NULL, '
          'Kg__Collected REAL, '
          'Cancelled TEXT NOT NULL, '
          'Paid INTEGER, '
          'ID_Number TEXT NOT NULL, '
          'Factory TEXT NOT NULL, '
          'Sent INTEGER, '
          'Comments TEXT NOT NULL, '
          'Cumm REAL, '
          '"User" TEXT NOT NULL, '
          'Can TEXT NOT NULL, '
          'Collection_time TEXT, '
          'Collect_type TEXT NOT NULL, '
          'Crop TEXT NOT NULL, '
          'Gross REAL, '
          'Tare REAL, '
          'No_of_Bags INTEGER, '
          'Delivered_By TEXT NOT NULL, '
          'Coffe_Type_Name TEXT NOT NULL, '
          'Updated INTEGER'
          ')',
        );
        await _createCollectionSettingsTable(db);
        await _createStoreHeadersTable(db);
        await _createStoresTable(db);
        await _createItemsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_tableUsers ADD COLUMN username TEXT NOT NULL DEFAULT ""',
          );
          await db.execute(
            'ALTER TABLE $_tableUsers ADD COLUMN password TEXT NOT NULL DEFAULT ""',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE $_tableFarmers('
            'No TEXT PRIMARY KEY, '
            'Name TEXT NOT NULL, '
            'Phone TEXT NOT NULL, '
            'Email TEXT NOT NULL, '
            'ID_No TEXT NOT NULL, '
            'Cum_Cherry REAL, '
            'Cum_Mbuni REAL, '
            'Updated INTEGER, '
            'Account_Category INTEGER, '
            'Factory TEXT NOT NULL, '
            'Comments TEXT NOT NULL, '
            'Gender INTEGER, '
            'Bank TEXT NOT NULL, '
            'Bank_Account TEXT NOT NULL, '
            'Acreage REAL, '
            'No_of_Trees INTEGER, '
            'Other_Loans REAL, '
            'Previous_Crop_collection REAL, '
            'Limit_percentage REAL, '
            '"Limit" REAL, '
            'Total_Stores REAL, '
            'Current_Crop_collection_Cherry_1 REAL, '
            'Current_Crop_collection_Cherry_2 REAL, '
            'Current_Crop_collection REAL, '
            'Bank_Code TEXT NOT NULL, '
            'Bank_Name TEXT NOT NULL'
            ')',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE $_tableFarmers ADD COLUMN Email TEXT NOT NULL DEFAULT ""',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE $_tableDailyCollections('
            'Farmers_Number TEXT NOT NULL, '
            'Collections_Date TEXT NOT NULL, '
            'Collection_Number TEXT NOT NULL, '
            'Coffee_Type TEXT NOT NULL, '
            'No_ INTEGER PRIMARY KEY, '
            'Farmers_Name TEXT NOT NULL, '
            'Kg__Collected REAL, '
            'Cancelled TEXT NOT NULL, '
            'Paid INTEGER, '
            'ID_Number TEXT NOT NULL, '
            'Factory TEXT NOT NULL, '
            'Sent INTEGER, '
            'Comments TEXT NOT NULL, '
            'Cumm REAL, '
            '"User" TEXT NOT NULL, '
            'Can TEXT NOT NULL, '
            'Collection_time TEXT, '
            'Collect_type TEXT NOT NULL, '
            'Crop TEXT NOT NULL, '
            'Gross REAL, '
            'Tare REAL, '
            'No_of_Bags INTEGER, '
            'Delivered_By TEXT NOT NULL, '
            'Coffe_Type_Name TEXT NOT NULL, '
            'Updated INTEGER'
            ')',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE $_tableUsers ADD COLUMN Updated INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 7) {
          await _createStoreHeadersTable(db);
          await _createStoresTable(db);
          await _createItemsTable(db);
        }
        if (oldVersion < 8) {
          await _createCollectionSettingsTable(db);
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE $_tableUsers ADD COLUMN Type TEXT NOT NULL DEFAULT ""',
          );
        }
      },
    );
  }

  Future<void> _ensureUsersSchema(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_tableUsers)');
    final hasType = columns.any((row) => row['name'] == 'Type');
    if (!hasType) {
      await db.execute(
        'ALTER TABLE $_tableUsers ADD COLUMN Type TEXT NOT NULL DEFAULT ""',
      );
    }
    _userSchemaEnsured = true;
  }

  Future<void> _createCollectionSettingsTable(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_tableCollectionSettings('
      'ID INTEGER PRIMARY KEY CHECK (ID = 1), '
      'Crop TEXT NOT NULL, '
      'Tare_Weight REAL NOT NULL'
      ')',
    );
    await db.insert(
      _tableCollectionSettings,
      CollectionSettings.defaults.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureCollectionSettingsTable(DatabaseExecutor db) async {
    await _createCollectionSettingsTable(db);
  }

  Future<void> _createStoreHeadersTable(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_tableStoreHeaders('
      'ID INTEGER PRIMARY KEY AUTOINCREMENT, '
      'Client TEXT NOT NULL, '
      'Date TEXT, '
      'Entry TEXT NOT NULL UNIQUE, '
      'Total REAL, '
      'Posted INTEGER, '
      'Paymode INTEGER, '
      'Amount_Paid REAL, '
      'Balance REAL, '
      '"Limit" REAL, '
      'Stores REAL, '
      'Limit_Available REAL, '
      'Collector TEXT NOT NULL, '
      'Collector_No TEXT NOT NULL, '
      'Member_Name TEXT NOT NULL, '
      'Collector_is_Member INTEGER, '
      'Mpesa_Code TEXT NOT NULL, '
      'Mpesa_No TEXT NOT NULL, '
      'Mpesa_Name TEXT NOT NULL, '
      'Crop_Year TEXT NOT NULL, '
      'Factory TEXT NOT NULL, '
      'Factory_Name TEXT NOT NULL, '
      'Served_By TEXT NOT NULL, '
      'Sent INTEGER, '
      'Credit_Amount REAL, '
      'Comments TEXT NOT NULL, '
      'Reversed INTEGER, '
      'Item_Count INTEGER'
      ')',
    );
  }

  Future<void> _createStoresTable(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_tableStores('
      'ID INTEGER PRIMARY KEY AUTOINCREMENT, '
      'Entry TEXT NOT NULL, '
      'Client TEXT NOT NULL, '
      'Item TEXT NOT NULL, '
      'Variant TEXT NOT NULL, '
      'Amount REAL, '
      'Quantity REAL, '
      'Time TEXT, '
      'Date TEXT, '
      'Served_By TEXT NOT NULL, '
      'Status TEXT NOT NULL, '
      'Factory TEXT NOT NULL, '
      'Sent INTEGER, '
      'Comments TEXT NOT NULL, '
      'Line_total REAL, '
      'Stock TEXT NOT NULL, '
      'Crop TEXT NOT NULL, '
      'Balance INTEGER, '
      'Paymode INTEGER, '
      'Amount_Paid REAL, '
      'FOREIGN KEY (Entry) REFERENCES $_tableStoreHeaders(Entry) '
      'ON DELETE CASCADE ON UPDATE CASCADE'
      ')',
    );
  }

  Future<void> _createItemsTable(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_tableItems('
      'No TEXT PRIMARY KEY, '
      'Description TEXT NOT NULL, '
      'Base_Unit_of_Measure TEXT NOT NULL, '
      'Last_Direct_Cost REAL, '
      'Unit_Cost REAL, '
      'Unit_Price REAL, '
      'Inventory REAL, '
      'Prevent_Negative_Inventory INTEGER'
      ')',
    );
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return db.insert(
      _tableUsers,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    final id = user.id;
    if (id == null) return 0;
    return db.update(
      _tableUsers,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete(_tableUsers, where: 'id = ?', whereArgs: [id]);
  }

  Future<CollectionSettings> getCollectionSettings() async {
    final db = await database;
    await _ensureCollectionSettingsTable(db);
    final rows = await db.query(_tableCollectionSettings, limit: 1);
    if (rows.isEmpty) {
      await saveCollectionSettings(CollectionSettings.defaults);
      return CollectionSettings.defaults;
    }
    return CollectionSettings.fromMap(rows.first);
  }

  Future<void> saveCollectionSettings(CollectionSettings settings) async {
    final db = await database;
    await _ensureCollectionSettingsTable(db);
    await db.insert(
      _tableCollectionSettings,
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceUsers(List<User> users) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableUsers);
      for (final user in users) {
        await txn.insert(_tableUsers, user.toMap());
      }
    });
  }

  Future<List<User>> getUsers() async {
    final db = await database;
    final rows = await db.query(_tableUsers, orderBy: 'id DESC');
    return rows.map(User.fromMap).toList();
  }

  Future<int> getUserCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM $_tableUsers');
    if (rows.isEmpty) return 0;
    final value = rows.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final u = username.trim();
    if (u.isEmpty) return null;
    final rows = await db.query(
      _tableUsers,
      where: 'TRIM(username) = ? COLLATE NOCASE',
      whereArgs: [u],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<int> updateUserPassword({
    required String username,
    required String password,
  }) async {
    final db = await database;
    final u = username.trim();
    if (u.isEmpty) return 0;
    return db.update(
      _tableUsers,
      {'password': password},
      where: 'TRIM(username) = ? COLLATE NOCASE',
      whereArgs: [u],
    );
  }

  Future<int> updateUserPasswordMarkUpdated({
    required String username,
    required String password,
  }) async {
    final db = await database;
    final u = username.trim();
    if (u.isEmpty) return 0;
    return db.update(
      _tableUsers,
      {'password': password, 'Updated': 1},
      where: 'TRIM(username) = ? COLLATE NOCASE',
      whereArgs: [u],
    );
  }

  Future<List<User>> getUsersWithPendingPasswordSync() async {
    final db = await database;
    final rows = await db.query(
      _tableUsers,
      where: 'Updated = 1 AND TRIM(password) <> ""',
      orderBy: 'id DESC',
    );
    return rows.map(User.fromMap).toList();
  }

  Future<int> clearUserUpdatedFlag(String username) async {
    final db = await database;
    final u = username.trim();
    if (u.isEmpty) return 0;
    return db.update(
      _tableUsers,
      {'Updated': 0},
      where: 'TRIM(username) = ? COLLATE NOCASE',
      whereArgs: [u],
    );
  }

  Future<User?> getUserByCredentials(String username, String password) async {
    final db = await database;
    final u = username.trim();
    if (u.isEmpty) return null;
    final rows = await db.query(
      _tableUsers,
      where: 'TRIM(username) = ? COLLATE NOCASE AND password = ?',
      whereArgs: [u, password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _userSchemaEnsured = false;
    }
  }

  Future<void> replaceFarmers(List<Farmer> farmers) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableFarmers);
      for (final farmer in farmers) {
        await txn.insert(_tableFarmers, farmer.toMap());
      }
    });
  }

  Future<List<Farmer>> getFarmers() async {
    final db = await database;
    final rows = await db.query(_tableFarmers, orderBy: 'Name ASC');
    return rows.map(Farmer.fromMap).toList();
  }

  Future<void> insertFarmer(Farmer farmer) async {
    final db = await database;
    await db.insert(
      _tableFarmers,
      farmer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFarmer(Farmer farmer) async {
    final db = await database;
    await db.update(
      _tableFarmers,
      farmer.toMap(),
      where: 'No = ?',
      whereArgs: [farmer.no],
    );
  }

  Future<void> replaceDailyCollections(List<DailyCollection> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableDailyCollections);
      for (final item in items) {
        await txn.insert(_tableDailyCollections, item.toMap());
      }
    });
  }

  Future<void> replaceDailyCollectionsFromServer(
    List<DailyCollection> items,
  ) async {
    final db = await database;
    final pendingRows = await db.query(
      _tableDailyCollections,
      where: 'COALESCE(Sent, 0) = 0',
    );
    final pendingItems = pendingRows.map(DailyCollection.fromMap).toList();

    await db.transaction((txn) async {
      await txn.delete(_tableDailyCollections);
      for (final item in items) {
        await txn.insert(
          _tableDailyCollections,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final item in pendingItems) {
        await txn.insert(
          _tableDailyCollections,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<DailyCollection>> getDailyCollections() async {
    final db = await database;
    final rows = await db.query(
      _tableDailyCollections,
      orderBy: 'Collections_Date DESC',
    );
    return rows.map(DailyCollection.fromMap).toList();
  }

  Future<void> insertDailyCollection(DailyCollection item) async {
    final db = await database;
    await db.insert(
      _tableDailyCollections,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPendingDailyCollection(DailyCollection item) async {
    final db = await database;
    final pendingItem = DailyCollection(
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
      factory: item.factory,
      sent: false,
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
      updated: true,
    );
    await db.insert(
      _tableDailyCollections,
      pendingItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyCollection>> getPendingDailyCollections() async {
    final db = await database;
    final rows = await db.query(
      _tableDailyCollections,
      where: 'COALESCE(Sent, 0) = 0',
      orderBy: 'Collections_Date DESC, No_ DESC',
    );
    return rows.map(DailyCollection.fromMap).toList();
  }

  Future<int> updateDailyCollectionBcSyncStatus({
    required int no,
    required String status,
    String? error,
  }) async {
    final db = await database;
    final normalizedStatus = status.trim().toLowerCase();
    final values = <String, Object?>{
      'Sent': normalizedStatus == 'synced' ? 1 : 0,
      'Updated': normalizedStatus == 'synced' ? 0 : 1,
    };
    return db.update(
      _tableDailyCollections,
      values,
      where: 'No_ = ?',
      whereArgs: [no],
    );
  }

  Future<void> replaceStoreHeaders(List<StoreHeader> headers) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableStoreHeaders);
      for (final header in headers) {
        await txn.insert(_tableStoreHeaders, header.toMap());
      }
    });
  }

  Future<List<StoreHeader>> getStoreHeaders() async {
    final db = await database;
    final rows = await db.query(
      _tableStoreHeaders,
      orderBy: 'Date DESC, ID DESC',
    );
    return rows.map(StoreHeader.fromMap).toList();
  }

  Future<StoreHeader?> getStoreHeaderByEntry(String entry) async {
    final db = await database;
    final rows = await db.query(
      _tableStoreHeaders,
      where: 'Entry = ?',
      whereArgs: [entry],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreHeader.fromMap(rows.first);
  }

  Future<void> insertStoreHeader(StoreHeader header) async {
    final db = await database;
    await db.insert(
      _tableStoreHeaders,
      header.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStoreHeader(StoreHeader header) async {
    final db = await database;
    await db.update(
      _tableStoreHeaders,
      header.toMap(),
      where: 'Entry = ?',
      whereArgs: [header.entry],
    );
  }

  Future<void> replaceStores(List<Store> stores) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableStores);
      for (final store in stores) {
        await txn.insert(_tableStores, store.toMap());
      }
    });
  }

  Future<List<Store>> getStoresByEntry(String entry) async {
    final db = await database;
    final rows = await db.query(
      _tableStores,
      where: 'Entry = ?',
      whereArgs: [entry],
      orderBy: 'ID DESC',
    );
    return rows.map(Store.fromMap).toList();
  }

  Future<void> insertStore(Store store) async {
    final db = await database;
    await db.insert(
      _tableStores,
      store.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceItems(List<Item> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tableItems);
      for (final item in items) {
        await txn.insert(_tableItems, item.toMap());
      }
    });
  }

  Future<List<Item>> getItems() async {
    final db = await database;
    final rows = await db.query(_tableItems, orderBy: 'Description ASC');
    return rows.map(Item.fromMap).toList();
  }

  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.insert(
      _tableItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
