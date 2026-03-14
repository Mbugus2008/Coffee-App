import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bluetooth_settings_service.dart';

class ClassicScaleService {
  ClassicScaleService._();

  static final ClassicScaleService instance = ClassicScaleService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'blue_thermal_printer/methods',
  );
  static const EventChannel _readChannel = EventChannel(
    'blue_thermal_printer/scale_read',
  );

  final StreamController<double> _weightController =
      StreamController<double>.broadcast();

  StreamSubscription<String>? _readSub;
  Stream<String>? _readStream;
  String _buffer = '';
  String? _lastErrorMessage;

  Stream<double> get weightStream => _weightController.stream;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> connectToScale() async {
    final attachment = await BluetoothSettingsService.instance
        .getAttachedScale();
    if (attachment == null) {
      _lastErrorMessage = 'No scale is attached in Bluetooth settings.';
      debugPrint('[Scale] $_lastErrorMessage');
      return false;
    }

    await _readSub?.cancel();
    _buffer = '';
    _lastErrorMessage = null;

    if (await isConnected()) {
      debugPrint('[Scale] Already connected');
      return true;
    }

    debugPrint(
      '[Scale] Connecting to ${attachment.name} (${attachment.address.trim()})',
    );

    try {
      await _methodChannel.invokeMethod('connectScale', <String, dynamic>{
        'address': attachment.address.trim(),
      });
    } on PlatformException catch (error, stackTrace) {
      if (_isAlreadyConnectedError(error)) {
        debugPrint('[Scale] Already connected');
        return true;
      }
      _lastErrorMessage = _describePlatformException(error);
      debugPrint('[Scale] Connect failed: $_lastErrorMessage');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      _lastErrorMessage = error.toString();
      debugPrint('[Scale] Connect failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }

    _readSub =
        (_readStream ??= _readChannel
                .receiveBroadcastStream()
                .map((event) => event?.toString() ?? '')
                .where((chunk) => chunk.isNotEmpty))
            .listen(
              _handleChunk,
              onError: (Object error, StackTrace stackTrace) {
                _lastErrorMessage = error.toString();
                debugPrint('[Scale] Read error: $error');
                debugPrintStack(stackTrace: stackTrace);
              },
              onDone: () {
                debugPrint('[Scale] Read stream closed');
              },
            );
    debugPrint('[Scale] Connected');
    return true;
  }

  Future<bool> isConnected() async {
    final connected = await _methodChannel.invokeMethod<dynamic>(
      'isScaleConnected',
    );
    return connected == true;
  }

  Future<void> disconnect() async {
    await _readSub?.cancel();
    _readSub = null;

    if (await isConnected()) {
      debugPrint('[Scale] Disconnecting');
      await _methodChannel.invokeMethod('disconnectScale');
    }
  }

  void _handleChunk(String chunk) {
    debugPrint('[Scale] Chunk: ${_formatChunk(chunk)}');
    _buffer = '$_buffer$chunk';
    if (_buffer.length > 256) {
      _buffer = _buffer.substring(_buffer.length - 256);
    }

    final weight = _extractLatestWeight(_buffer);
    if (weight != null) {
      debugPrint('[Scale] Parsed weight: ${weight.toStringAsFixed(2)} kg');
      _weightController.add(weight);
    }
  }

  double? _extractLatestWeight(String source) {
    final weightMatches = RegExp(
      r'([+-])?\s*(\d+(?:\.\d+)?)\s*(?:KG|kg)',
    ).allMatches(source).toList();
    if (weightMatches.isNotEmpty) {
      final latest = weightMatches.last;
      final sign = latest.group(1) == '-' ? '-' : '';
      final value = latest.group(2);
      return value == null ? null : double.tryParse('$sign$value');
    }

    final normalized = source.replaceAllMapped(
      RegExp(r'([+-])\s+(?=\d)'),
      (match) => match.group(1) ?? '',
    );
    final fallbackMatches = RegExp(
      r'[+-]?\d+(?:\.\d+)?',
    ).allMatches(normalized).toList();
    if (fallbackMatches.isEmpty) {
      return null;
    }

    final latest = fallbackMatches.last.group(0);
    return latest == null ? null : double.tryParse(latest);
  }

  String _describePlatformException(PlatformException error) {
    final parts = <String>[];
    if (error.code.isNotEmpty) {
      parts.add(error.code);
    }
    if (error.message?.isNotEmpty == true) {
      parts.add(error.message!);
    }
    final details = error.details?.toString();
    if (details != null && details.isNotEmpty) {
      parts.add(details);
    }
    if (parts.isEmpty) {
      return 'Unknown platform error while connecting to scale.';
    }
    return parts.join(' | ');
  }

  bool _isAlreadyConnectedError(PlatformException error) {
    return error.code == 'connect_error' &&
        (error.message?.toLowerCase().contains('already connected') ?? false);
  }

  String _formatChunk(String chunk) {
    return chunk
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
  }
}
