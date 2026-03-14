import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_permission_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/bluetooth_settings_service.dart';
import '../services/classic_scale_service.dart';
import 'brand_logo.dart';

class _BluetoothChoice {
  const _BluetoothChoice({
    required this.name,
    required this.address,
    this.printerDevice,
    required this.source,
  });

  final String name;
  final String address;
  final PrinterDeviceInfo? printerDevice;
  final String source;

  bool get supportsPrinter => printerDevice != null;

  bool get supportsScale => true;
}

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

//flutter_pos_printer_platform_image_3
class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  bool _loading = true;
  bool _isConnected = false;
  List<_BluetoothChoice> _devices = [];
  String? _loadError;
  bool _showPermissionSettingsAction = false;
  _BluetoothChoice? _selectedPrinter;
  _BluetoothChoice? _selectedScale;

  BluetoothAttachment? _attachedPrinter;
  BluetoothAttachment? _attachedScale;

  bool _isScaleConnecting = false;
  bool _isScaleConnected = false;
  double? _latestWeight;
  StreamSubscription<double>? _scaleSub;

  String _normalizeAddress(String value) {
    return value
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedAttachments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDevices();
    });
  }

  Future<bool> _ensurePermissionsOrNotify() async {
    final permissionState = await AppPermissionService.instance.ensureReady();
    if (permissionState.granted) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permissionState.permanentlyDenied
              ? 'Bluetooth permission denied permanently. Open app settings and allow Nearby devices.'
              : 'Bluetooth permission denied. Allow Nearby devices, then try again.',
        ),
        action: permissionState.permanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ),
    );
    return false;
  }

  Future<void> _loadSavedAttachments() async {
    final attachedPrinter = await BluetoothSettingsService.instance
        .getAttachedPrinter();
    final attachedScale = await BluetoothSettingsService.instance
        .getAttachedScale();

    if (!mounted) return;
    setState(() {
      _attachedPrinter = attachedPrinter;
      _attachedScale = attachedScale;
    });
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    List<_BluetoothChoice> devices = [];
    bool connected = false;
    BluetoothAttachment? attachedPrinter;
    BluetoothAttachment? attachedScale;
    String? loadError;

    try {
      var permissionState = await AppPermissionService.instance.ensureReady();
      if (!permissionState.granted && !permissionState.permanentlyDenied) {
        // Try requesting again right away (user may have dismissed/denied once).
        permissionState = await AppPermissionService.instance.ensureReady();
      }

      if (!permissionState.granted) {
        const message =
            'Bluetooth permission is required. Allow Nearby devices and try again.';
        loadError = message;
        _showPermissionSettingsAction = permissionState.permanentlyDenied;
        attachedPrinter = await BluetoothSettingsService.instance
            .getAttachedPrinter();
        attachedScale = await BluetoothSettingsService.instance
            .getAttachedScale();
      } else {
        _showPermissionSettingsAction = false;

        final bluetoothOn = await BluetoothPrinterService.instance
            .isBluetoothOn()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        if (!bluetoothOn) {
          loadError =
              'Bluetooth is turned off. Turn it on, pair your printer or scale, then tap refresh.';
          attachedPrinter = await BluetoothSettingsService.instance
              .getAttachedPrinter();
          attachedScale = await BluetoothSettingsService.instance
              .getAttachedScale();
        } else {
          final printerDevices = await BluetoothPrinterService.instance
              .getBondedDevices()
              .timeout(const Duration(seconds: 8), onTimeout: () => []);

          final byAddress = <String, _BluetoothChoice>{};
          for (final device in printerDevices) {
            final address = device.address.trim();
            if (address.isEmpty) continue;
            byAddress[_normalizeAddress(address)] = _BluetoothChoice(
              name: device.name,
              address: address,
              printerDevice: device,
              source: device.source,
            );
          }
          devices = byAddress.values.toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          connected = await BluetoothPrinterService.instance
              .isAttachedPrinterConnected()
              .timeout(const Duration(seconds: 5), onTimeout: () => false);
          attachedPrinter = await BluetoothSettingsService.instance
              .getAttachedPrinter();
          attachedScale = await BluetoothSettingsService.instance
              .getAttachedScale();
        }
      }
    } on TimeoutException {
      loadError =
          'Bluetooth request timed out. Ensure Bluetooth is on and permissions are allowed, then tap refresh.';
      _showPermissionSettingsAction = false;
      attachedPrinter = await BluetoothSettingsService.instance
          .getAttachedPrinter();
      attachedScale = await BluetoothSettingsService.instance
          .getAttachedScale();
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('permission')) {
        loadError =
            'Bluetooth permission is missing. Allow Nearby devices and try again.';
        _showPermissionSettingsAction = true;
      } else if (message.toLowerCase().contains('off') ||
          message.toLowerCase().contains('disabled') ||
          message.toLowerCase().contains('adapter')) {
        loadError =
            'Bluetooth is unavailable right now. Turn it on in system settings, then tap refresh.';
        _showPermissionSettingsAction = false;
      } else {
        loadError = 'Unable to load Bluetooth devices: $message';
        _showPermissionSettingsAction = false;
      }
      attachedPrinter = await BluetoothSettingsService.instance
          .getAttachedPrinter();
      attachedScale = await BluetoothSettingsService.instance
          .getAttachedScale();
    }

    _BluetoothChoice? selectedPrinter;
    _BluetoothChoice? selectedScale;
    if (attachedPrinter != null) {
      for (final device in devices) {
        if (_normalizeAddress(device.address) ==
            _normalizeAddress(attachedPrinter.address)) {
          selectedPrinter = device;
          break;
        }
      }
    }
    if (attachedScale != null) {
      for (final device in devices) {
        if (_normalizeAddress(device.address) ==
            _normalizeAddress(attachedScale.address)) {
          selectedScale = device;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _devices = devices;
      _isConnected = connected;
      _attachedPrinter = attachedPrinter;
      _attachedScale = attachedScale;
      _selectedPrinter = selectedPrinter;
      _selectedScale = selectedScale;
      _loadError = loadError;
      _loading = false;
    });
  }

  Future<void> _pickDevice({required bool isPrinter}) async {
    final candidates = isPrinter
        ? _devices.where((d) => d.supportsPrinter).toList()
        : _devices.where((d) => d.supportsScale).toList();

    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPrinter
                ? 'No paired classic Bluetooth printers found. Pair the printer in Android Bluetooth settings, then tap refresh.'
                : 'No paired classic Bluetooth devices found. Pair the scale in Android Bluetooth settings, then tap refresh.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<_BluetoothChoice>(
      context: context,
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: candidates.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = candidates[index];
            return ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(device.name),
              subtitle: Text(
                '${device.address} • ${device.source}${device.supportsPrinter ? ' • Printer' : ''}${device.supportsScale ? ' • Scale' : ''}',
              ),
              onTap: () => Navigator.of(context).pop(device),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      if (isPrinter) {
        _selectedPrinter = selected;
      } else {
        _selectedScale = selected;
      }
    });
  }

  Future<void> _attachPrinter() async {
    if (!await _ensurePermissionsOrNotify()) return;
    if (!mounted) return;

    final selected = _selectedPrinter;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a printer device first.')),
      );
      return;
    }

    var selectedChoice = selected;

    try {
      final printerDevice = selectedChoice.printerDevice;
      if (printerDevice != null) {
        await BluetoothPrinterService.instance.connect(printerDevice);
      } else {
        await BluetoothPrinterService.instance.connectByAddress(
          name: selectedChoice.name,
          address: selectedChoice.address,
        );
      }
    } catch (error) {
      debugPrint('Unable to connect printer: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to connect: $error\nEnsure the printer is paired, powered on, and in printer/SPP mode.',
          ),
        ),
      );
      return;
    }

    await BluetoothSettingsService.instance.attachPrinter(
      name: selectedChoice.name,
      address: selectedChoice.address,
    );

    if (!mounted) return;
    setState(() {
      _attachedPrinter = BluetoothAttachment(
        name: selectedChoice.name,
        address: selectedChoice.address,
      );
      _selectedPrinter = selectedChoice;
      _isConnected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer attached: ${selectedChoice.name}')),
    );
  }

  Future<void> _detachPrinter() async {
    await BluetoothPrinterService.instance.disconnectAttachedPrinter();
    await BluetoothSettingsService.instance.clearAttachedPrinter();
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _attachedPrinter = null;
      _selectedPrinter = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer detached.')));
  }

  Future<void> _attachScale() async {
    final device = _selectedScale;
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a scale device first.')),
      );
      return;
    }

    await BluetoothSettingsService.instance.attachScale(
      name: device.name,
      address: device.address,
    );

    if (!mounted) return;
    setState(() {
      _attachedScale = BluetoothAttachment(
        name: device.name,
        address: device.address,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Scale attached: ${device.name}')));
  }

  Future<void> _detachScale() async {
    await ClassicScaleService.instance.disconnect();
    await _scaleSub?.cancel();
    _scaleSub = null;
    await BluetoothSettingsService.instance.clearAttachedScale();
    if (!mounted) return;
    setState(() {
      _isScaleConnected = false;
      _attachedScale = null;
      _selectedScale = null;
      _latestWeight = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scale detached.')));
  }

  Future<void> _connectScale() async {
    if (!await _ensurePermissionsOrNotify()) return;
    if (!mounted) return;

    setState(() {
      _isScaleConnecting = true;
    });

    final connected = await ClassicScaleService.instance.connectToScale();
    final scaleError = ClassicScaleService.instance.lastErrorMessage;

    if (!mounted) return;
    setState(() {
      _isScaleConnecting = false;
      _isScaleConnected = connected;
    });

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scaleError?.isNotEmpty == true
                ? 'Scale connection failed: $scaleError'
                : 'Scale connection failed. Ensure the scale is powered on and paired in Bluetooth settings.',
          ),
        ),
      );
      return;
    }

    await _scaleSub?.cancel();
    _scaleSub = ClassicScaleService.instance.weightStream.listen((weight) {
      if (!mounted) return;
      setState(() {
        _latestWeight = weight;
      });
    });
  }

  Future<void> _disconnectScale() async {
    await ClassicScaleService.instance.disconnect();
    await _scaleSub?.cancel();
    _scaleSub = null;
    if (!mounted) return;
    setState(() {
      _isScaleConnected = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scale disconnected.')));
  }

  @override
  void dispose() {
    _scaleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushNamed('/dashboard');
            }
          },
        ),
        title: const BrandedAppBarTitle('Bluetooth Settings1'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Refreshing...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_loadError != null) ...[
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.errorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    _loadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  trailing: _showPermissionSettingsAction
                      ? TextButton(
                          onPressed: openAppSettings,
                          child: const Text('Open Settings'),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                ),
                title: const Text('Attached Printer'),
                subtitle: Text(
                  _attachedPrinter == null
                      ? 'No printer attached'
                      : '${_attachedPrinter!.name}\n${_attachedPrinter!.address}',
                ),
                trailing: _attachedPrinter == null
                    ? null
                    : TextButton(
                        onPressed: _detachPrinter,
                        child: const Text('Detach'),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDevice(isPrinter: true),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(
                      _selectedPrinter == null
                          ? 'Select Printer'
                          : _selectedPrinter!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _attachPrinter,
                  child: const Text('Attach'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _isScaleConnected ? Icons.scale : Icons.scale_outlined,
                ),
                title: const Text('Attached Scale'),
                subtitle: Text(
                  _attachedScale == null
                      ? 'No scale attached'
                      : '${_attachedScale!.name}\n${_attachedScale!.address}',
                ),
                trailing: _attachedScale == null
                    ? null
                    : TextButton(
                        onPressed: _detachScale,
                        child: const Text('Detach'),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDevice(isPrinter: false),
                    icon: const Icon(Icons.scale_outlined),
                    label: Text(
                      _selectedScale == null
                          ? 'Select Scale'
                          : _selectedScale!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _attachScale,
                  child: const Text('Attach'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _isScaleConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_searching,
                ),
                title: const Text('Scale Live Connection'),
                subtitle: Text(
                  _latestWeight == null
                      ? 'Optional: connect to read live weight while keeping the printer connected.'
                      : 'Latest weight: ${_latestWeight!.toStringAsFixed(2)} kg',
                ),
                trailing: _isScaleConnected
                    ? TextButton(
                        onPressed: _disconnectScale,
                        child: const Text('Disconnect'),
                      )
                    : FilledButton(
                        onPressed: _isScaleConnecting ? null : _connectScale,
                        child: Text(
                          _isScaleConnecting ? 'Connecting' : 'Connect',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Paired Devices: ${_devices.length}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text(
                        'No paired Bluetooth devices found. Pair devices in phone settings then tap refresh.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final capabilities = <String>[
                          if (device.supportsPrinter) 'Printer',
                          if (device.supportsScale) 'Scale',
                        ];
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(device.name),
                          subtitle: Text(
                            '${device.address} • ${device.source}${capabilities.isEmpty ? '' : ' • ${capabilities.join(' / ')}'}',
                          ),
                          trailing: capabilities.isEmpty
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (value) {
                                    setState(() {
                                      if (value == 'printer') {
                                        _selectedPrinter = device;
                                      } else {
                                        _selectedScale = device;
                                      }
                                    });
                                  },
                                  itemBuilder: (_) => [
                                    if (device.supportsPrinter)
                                      const PopupMenuItem(
                                        value: 'printer',
                                        child: Text('Use as Printer'),
                                      ),
                                    if (device.supportsScale)
                                      const PopupMenuItem(
                                        value: 'scale',
                                        child: Text('Use as Scale'),
                                      ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
