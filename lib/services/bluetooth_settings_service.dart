import 'package:sqflite/sqflite.dart';

import '../data/user_database.dart';

class BluetoothAttachment {
  const BluetoothAttachment({required this.name, required this.address});

  final String name;
  final String address;

  bool get isEmpty => name.trim().isEmpty || address.trim().isEmpty;
}

class BluetoothSettingsService {
  BluetoothSettingsService._();

  static final BluetoothSettingsService instance = BluetoothSettingsService._();

  static const _table = 'app_settings';
  static const _printerNameKey = 'attached_printer_name';
  static const _printerAddressKey = 'attached_printer_address';
  static const _scaleNameKey = 'attached_scale_name';
  static const _scaleAddressKey = 'attached_scale_address';

  Future<void> _ensureTable() async {
    final db = await UserDatabase.instance.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_table('
      'key TEXT PRIMARY KEY, '
      'value TEXT NOT NULL'
      ')',
    );
  }

  Future<String?> _getValue(String key) async {
    await _ensureTable();
    final db = await UserDatabase.instance.database;
    final rows = await db.query(
      _table,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _setValue(String key, String value) async {
    await _ensureTable();
    final db = await UserDatabase.instance.database;
    await db.insert(
      _table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _removeValue(String key) async {
    await _ensureTable();
    final db = await UserDatabase.instance.database;
    await db.delete(_table, where: 'key = ?', whereArgs: [key]);
  }

  Future<BluetoothAttachment?> getAttachedPrinter() async {
    final name = await _getValue(_printerNameKey) ?? '';
    final address = await _getValue(_printerAddressKey) ?? '';
    final attachment = BluetoothAttachment(name: name, address: address);
    return attachment.isEmpty ? null : attachment;
  }

  Future<BluetoothAttachment?> getAttachedScale() async {
    final name = await _getValue(_scaleNameKey) ?? '';
    final address = await _getValue(_scaleAddressKey) ?? '';
    final attachment = BluetoothAttachment(name: name, address: address);
    return attachment.isEmpty ? null : attachment;
  }

  Future<void> attachPrinter({
    required String name,
    required String address,
  }) async {
    await _setValue(_printerNameKey, name);
    await _setValue(_printerAddressKey, address);
  }

  Future<void> attachScale({
    required String name,
    required String address,
  }) async {
    await _setValue(_scaleNameKey, name);
    await _setValue(_scaleAddressKey, address);
  }

  Future<void> clearAttachedPrinter() async {
    await _removeValue(_printerNameKey);
    await _removeValue(_printerAddressKey);
  }

  Future<void> clearAttachedScale() async {
    await _removeValue(_scaleNameKey);
    await _removeValue(_scaleAddressKey);
  }
}
