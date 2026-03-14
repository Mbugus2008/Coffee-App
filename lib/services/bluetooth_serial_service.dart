import 'package:flutter/services.dart';

class BluetoothSerialService {
  BluetoothSerialService._();

  static final BluetoothSerialService instance = BluetoothSerialService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'blue_thermal_printer/methods',
  );
  static const EventChannel _readChannel = EventChannel(
    'blue_thermal_printer/read',
  );

  String? _connectedAddress;
  Stream<String>? _readStream;

  String? get connectedAddress => _connectedAddress;

  Stream<String> get readStream {
    return _readStream ??= _readChannel
        .receiveBroadcastStream()
        .map((event) {
          return event?.toString() ?? '';
        })
        .where((chunk) => chunk.isNotEmpty);
  }

  Future<void> connectByAddress(String address) async {
    final normalizedAddress = _normalizeAddress(address);
    if (normalizedAddress.isEmpty) {
      throw Exception('Selected device has no valid Bluetooth address.');
    }

    final connected = await isConnected();
    if (connected) {
      if (_connectedAddress == normalizedAddress) {
        return;
      }
      await disconnect();
    }

    await _methodChannel.invokeMethod('connect', <String, dynamic>{
      'address': address.trim(),
    });
    _connectedAddress = normalizedAddress;
  }

  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } finally {
      _connectedAddress = null;
    }
  }

  Future<bool> isBluetoothOn() async {
    final enabled = await _methodChannel.invokeMethod<dynamic>('isOn');
    return enabled == true;
  }

  Future<void> openBluetoothSettings() async {
    await _methodChannel.invokeMethod('openSettings');
  }

  Future<bool> isConnected() async {
    final connected = await _methodChannel.invokeMethod<dynamic>('isConnected');
    return connected == true;
  }

  Future<bool> isConnectedToAddress(String address) async {
    return await isConnected() &&
        _connectedAddress == _normalizeAddress(address);
  }

  String _normalizeAddress(String value) {
    return value
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();
  }
}
