import 'package:flutter/services.dart';

import '../data/daily_collection_model.dart';
import '../data/store_models.dart';
import 'bluetooth_serial_service.dart';
import 'bluetooth_settings_service.dart';

class PrinterDeviceInfo {
  const PrinterDeviceInfo({
    required this.name,
    required this.address,
    required this.source,
    required this.isBle,
    this.rawDevice,
  });

  final String name;
  final String address;
  final String source;
  final bool isBle;
  final dynamic rawDevice;
}

class _BlueThermalPrinterDevice {
  const _BlueThermalPrinterDevice({
    required this.name,
    required this.address,
    required this.macAddress,
  });

  final String name;
  final String address;
  final String macAddress;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'address': address,
      'macAddress': macAddress,
    };
  }
}

class _BlueThermalPrinterAdapter {
  _BlueThermalPrinterAdapter._();

  static final _BlueThermalPrinterAdapter instance =
      _BlueThermalPrinterAdapter._();

  static const MethodChannel _channel = MethodChannel(
    'blue_thermal_printer/methods',
  );

  Future<List<dynamic>> getBondedDevices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getBondedDevices');
    if (raw == null) {
      return const [];
    }

    return raw.map((item) {
      if (item is Map) {
        final map = item.cast<dynamic, dynamic>();
        final name = (map['name'] ?? '').toString();
        final address = (map['address'] ?? '').toString();
        final macAddress = (map['macAddress'] ?? '').toString();
        return _BlueThermalPrinterDevice(
          name: name,
          address: address,
          macAddress: macAddress,
        );
      }
      return const _BlueThermalPrinterDevice(
        name: '',
        address: '',
        macAddress: '',
      );
    }).toList();
  }

  Future<void> connect(dynamic device) async {
    String address = '';
    if (device is _BlueThermalPrinterDevice) {
      address = device.address.isNotEmpty ? device.address : device.macAddress;
    } else if (device is Map) {
      final map = device.cast<dynamic, dynamic>();
      address = (map['address'] ?? map['macAddress'] ?? '').toString();
    }

    if (address.isEmpty) {
      throw Exception('Unable to connect: invalid printer device.');
    }

    await _channel.invokeMethod('connect', <String, dynamic>{
      'address': address,
    });
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  Future<bool> get isOn async {
    final enabled = await _channel.invokeMethod<dynamic>('isOn');
    return enabled == true;
  }

  Future<void> openSettings() async {
    await _channel.invokeMethod('openSettings');
  }

  Future<bool> get isConnected async {
    final connected = await _channel.invokeMethod<dynamic>('isConnected');
    return connected == true;
  }

  Future<void> printCustom(String message, int size, int align) async {
    await _channel.invokeMethod('printCustom', <String, dynamic>{
      'message': message,
      'size': size,
      'align': align,
    });
  }

  Future<void> printLeftRight(
    String left,
    String right,
    int size, {
    String? format,
  }) async {
    await _channel.invokeMethod('printLeftRight', <String, dynamic>{
      'string1': left,
      'string2': right,
      'size': size,
      'format': format,
    });
  }

  Future<void> printNewLine() async {
    await _channel.invokeMethod('printNewLine');
  }
}

class BluetoothPrinterService {
  BluetoothPrinterService._();

  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  final dynamic _printer = _BlueThermalPrinterAdapter.instance;
  final BluetoothSerialService _serial = BluetoothSerialService.instance;

  Future<List<PrinterDeviceInfo>> getBondedDevices() async {
    final dynamic bonded = await _printer.getBondedDevices();
    if (bonded is! List) {
      return const [];
    }

    final devices = <PrinterDeviceInfo>[];
    for (final device in bonded) {
      final name = _stringValue(device, 'name').trim();
      final address =
          (_stringValue(device, 'address').isNotEmpty
                  ? _stringValue(device, 'address')
                  : _stringValue(device, 'macAddress'))
              .trim();
      if (address.isEmpty) {
        continue;
      }
      devices.add(
        PrinterDeviceInfo(
          name: name.isEmpty ? 'Unknown' : name,
          address: address,
          source: 'Classic Bluetooth',
          isBle: false,
          rawDevice: device,
        ),
      );
    }

    devices.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return devices;
  }

  Future<void> connect(PrinterDeviceInfo device) async {
    await connectByAddress(name: device.name, address: device.address);
  }

  Future<void> connectByAddress({
    required String name,
    required String address,
    bool isBleHint = false,
  }) async {
    final normalizedAddress = _normalizeAddress(address);
    if (normalizedAddress.isEmpty) {
      throw Exception('Selected device has no valid Bluetooth address.');
    }

    await _serial.connectByAddress(address);
  }

  Future<void> disconnect() async {
    await _serial.disconnect();
  }

  Future<bool> isBluetoothOn() async {
    return _serial.isBluetoothOn();
  }

  Future<void> openBluetoothSettings() async {
    await _serial.openBluetoothSettings();
  }

  Future<bool> isConnected() async {
    return _serial.isConnected();
  }

  Future<bool> isAttachedPrinterConnected() async {
    final attachment = await BluetoothSettingsService.instance
        .getAttachedPrinter();
    if (attachment == null) {
      return false;
    }
    return _serial.isConnectedToAddress(attachment.address);
  }

  Future<bool> connectAttachedPrinter() async {
    final attachment = await BluetoothSettingsService.instance
        .getAttachedPrinter();
    if (attachment == null) {
      return false;
    }

    try {
      await connectByAddress(
        name: attachment.name,
        address: attachment.address,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectAttachedPrinter() async {
    final attachment = await BluetoothSettingsService.instance
        .getAttachedPrinter();
    if (attachment == null) {
      return;
    }
    if (await _serial.isConnectedToAddress(attachment.address)) {
      await _serial.disconnect();
    }
  }

  Future<void> printReceipt(DailyCollection collection) async {
    await _printer.printCustom('Collection\nReceipt', 2, 1);
    await _printer.printNewLine();
    await _printReceiptField('Farmer', collection.farmersName);
    await _printReceiptField('Number', collection.farmersNumber);
    if (collection.factory.trim().isNotEmpty) {
      await _printReceiptField('Factory', collection.factory);
    }
    await _printReceiptField(
      'Coll',
      collection.collectionNumber,
      ellipsisAtStart: true,
    );
    await _printReceiptField(
      'Kg',
      (collection.kgCollected ?? 0).toStringAsFixed(2),
    );
    await _printReceiptField(
      'Date',
      _formatDate(collection.collectionTime ?? collection.collectionsDate),
    );
    await _printer.printNewLine();
    await _printer.printCustom('Thank you', 1, 1);
    await _printer.printNewLine();
    await _printer.printNewLine();
  }

  Future<void> printStoresReceipt(StoreHeader header, List<Store> lines) async {
    await _printer.printCustom('Stores Receipt', 2, 1);
    await _printer.printNewLine();

    await _printReceiptField('Entry', header.entry, ellipsisAtStart: true);
    await _printReceiptField('Farmer', header.memberName);
    await _printReceiptField('Number', header.client);
    final factoryLabel = header.factoryName.trim().isNotEmpty
        ? header.factoryName
        : header.factory;
    if (factoryLabel.trim().isNotEmpty) {
      await _printReceiptField('Factory', factoryLabel);
    }
    if ((header.collector.trim()).isNotEmpty) {
      await _printReceiptField('Collector', header.collector);
    }
    if (header.date != null) {
      await _printReceiptField('Date', _formatDate(header.date!));
    }

    await _printer.printNewLine();
    await _printer.printCustom('Lines', 1, 0);
    await _printer.printNewLine();
    await _printer.printLeftRight('Item', 'Amount', 1, format: '%-18s%14s%n');
    await _printer.printLeftRight(
      '------------------',
      '--------------',
      1,
      format: '%-18s%14s%n',
    );

    for (final line in lines) {
      final quantity = (line.quantity ?? 0).toStringAsFixed(2);
      final left = '${line.item} x$quantity';
      final total =
          (line.lineTotal ?? ((line.amount ?? 0) * (line.quantity ?? 0)))
              .toStringAsFixed(2);
      await _printer.printLeftRight(
        _truncateForColumn(left, 18),
        _truncateForColumn(total, 14, ellipsisAtStart: true),
        1,
        format: '%-18s%14s%n',
      );
      if (line.variant.trim().isNotEmpty) {
        await _printer.printCustom(_truncateForColumn(line.variant, 32), 0, 0);
      }
    }

    await _printer.printNewLine();
    await _printReceiptField('Total', (header.total ?? 0).toStringAsFixed(2));
    await _printReceiptField(
      'Paid',
      (header.amountPaid ?? 0).toStringAsFixed(2),
    );
    await _printReceiptField(
      'Balance',
      (header.balance ?? 0).toStringAsFixed(2),
    );
    await _printer.printNewLine();
    await _printer.printCustom('Thank you', 1, 1);
    await _printer.printNewLine();
    await _printer.printNewLine();
  }

  Future<void> _printReceiptField(
    String label,
    String value, {
    bool ellipsisAtStart = false,
  }) async {
    const labelWidth = 12;
    const valueWidth = 20;
    await _printer.printLeftRight(
      _truncateForColumn('$label:', labelWidth),
      _truncateForColumn(
        value.trim(),
        valueWidth,
        ellipsisAtStart: ellipsisAtStart,
      ),
      1,
      format: '%-${labelWidth}s%${valueWidth}s%n',
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  String _normalizeAddress(String value) {
    return value
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();
  }

  String _truncateForColumn(
    String value,
    int maxWidth, {
    bool ellipsisAtStart = false,
  }) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxWidth) {
      return normalized;
    }
    if (maxWidth <= 3) {
      return normalized.substring(0, maxWidth);
    }
    if (ellipsisAtStart) {
      return '...${normalized.substring(normalized.length - (maxWidth - 3))}';
    }
    return '${normalized.substring(0, maxWidth - 3)}...';
  }

  String _stringValue(dynamic object, String propertyName) {
    try {
      final dynamic value = (object as dynamic).toJson()[propertyName];
      if (value == null) {
        return '';
      }
      return value.toString();
    } catch (_) {
      try {
        final dynamic value = _readProperty(object, propertyName);
        if (value == null) {
          return '';
        }
        return value.toString();
      } catch (_) {
        return '';
      }
    }
  }

  dynamic _readProperty(dynamic object, String propertyName) {
    switch (propertyName) {
      case 'name':
        return object.name;
      case 'address':
        return object.address;
      case 'macAddress':
        return object.macAddress;
      default:
        return null;
    }
  }
}
