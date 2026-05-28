import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_permission_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/bluetooth_settings_service.dart';
import '../services/classic_scale_service.dart';
import 'back_button_guard.dart';
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
class _PrinterSettingsPageState extends State<PrinterSettingsPage> with BackButtonGuard {
  bool _loading = true;
  bool _isConnected = false;
  List<_BluetoothChoice> _devices = [];
  String? _loadError;
  bool _showPermissionSettingsAction = false;
  BluetoothAttachment? _attachedPrinter;
  BluetoothAttachment? _attachedScale;
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
    bool scaleConnected = false;
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
          scaleConnected = await ClassicScaleService.instance
              .isConnected()
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

    if (!mounted) return;
    setState(() {
      _devices = devices;
      _isConnected = connected;
      _attachedPrinter = attachedPrinter;
      _attachedScale = attachedScale;
      _isScaleConnected = scaleConnected;
      _loadError = loadError;
      _loading = false;
    });
  }

  Future<void> _onConnectPrinterPressed() async {
    if (!await _ensurePermissionsOrNotify()) return;

    final candidates = _devices.where((d) => d.supportsPrinter).toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No paired printers found. Pair the printer in Android Bluetooth settings, then tap refresh.',
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
              leading: const Icon(Icons.print_outlined),
              title: Text(device.name),
              subtitle: Text(device.address),
              onTap: () => Navigator.of(context).pop(device),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;

    // Always save the attachment so auto-connect can pick it up later,
    // even if the device is off or out of range right now.
    await BluetoothSettingsService.instance.attachPrinter(
      name: selected.name,
      address: selected.address,
    );

    if (!mounted) return;
    setState(() {
      _attachedPrinter = BluetoothAttachment(
        name: selected.name,
        address: selected.address,
      );
    });

    // Attempt to connect, but don't block saving on success.
    var connectedNow = false;
    try {
      final printerDevice = selected.printerDevice;
      if (printerDevice != null) {
        await BluetoothPrinterService.instance.connect(printerDevice);
      } else {
        await BluetoothPrinterService.instance.connectByAddress(
          name: selected.name,
          address: selected.address,
        );
      }
      connectedNow = true;
    } catch (error) {
      debugPrint('Unable to connect printer immediately: $error');
    }

    if (!mounted) return;
    setState(() {
      _isConnected = connectedNow;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connectedNow
              ? 'Printer connected: ${selected.name}'
              : 'Printer saved: ${selected.name}. It will connect automatically when turned on.',
        ),
      ),
    );
  }

  Future<void> _onConnectScalePressed() async {
    if (!await _ensurePermissionsOrNotify()) return;

    final candidates = _devices.where((d) => d.supportsScale).toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No paired devices found. Pair the scale in Android Bluetooth settings, then tap refresh.',
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
              leading: const Icon(Icons.scale_outlined),
              title: Text(device.name),
              subtitle: Text(device.address),
              onTap: () => Navigator.of(context).pop(device),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;

    // Always save the attachment so auto-connect can pick it up later,
    // even if the device is off or out of range right now.
    await BluetoothSettingsService.instance.attachScale(
      name: selected.name,
      address: selected.address,
    );

    if (!mounted) return;
    setState(() {
      _attachedScale = BluetoothAttachment(
        name: selected.name,
        address: selected.address,
      );
    });

    // Attempt to connect, but don't block saving on success.
    final connected = await ClassicScaleService.instance.connectToScale();
    final scaleError = ClassicScaleService.instance.lastErrorMessage;

    if (!mounted) return;
    setState(() {
      _isScaleConnected = connected;
    });

    if (connected) {
      await _scaleSub?.cancel();
      _scaleSub = ClassicScaleService.instance.weightStream.listen((weight) {
        if (!mounted) return;
        setState(() {
          _latestWeight = weight;
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scale connected: ${selected.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scaleError?.isNotEmpty == true
                ? 'Scale saved: ${selected.name}. It will connect automatically when turned on.'
                : 'Scale saved: ${selected.name}. It will connect automatically when turned on.',
          ),
        ),
      );
    }
  }

  Future<void> _onDisconnectPrinterPressed() async {
    await BluetoothPrinterService.instance.disconnectAttachedPrinter();
    await BluetoothSettingsService.instance.clearAttachedPrinter();
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _attachedPrinter = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Printer disconnected.')));
  }

  Future<void> _onDisconnectScalePressed() async {
    await ClassicScaleService.instance.disconnect();
    await _scaleSub?.cancel();
    _scaleSub = null;
    await BluetoothSettingsService.instance.clearAttachedScale();
    if (!mounted) return;
    setState(() {
      _isScaleConnected = false;
      _attachedScale = null;
      _latestWeight = null;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildStatusCard({
      required String label,
      required String? deviceName,
      required bool isConnected,
      required IconData icon,
      required VoidCallback onConnect,
      required VoidCallback onDisconnect,
    }) {
      final connected = isConnected && deviceName != null;
      return Card(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: connected ? colorScheme.primary : colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceName ?? 'Not connected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                deviceName != null
                                    ? colorScheme.onSurface
                                    : colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          connected
                              ? Colors.green
                              : colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: onDisconnect,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('Disconnect'),
                      )
                    : FilledButton.icon(
                        onPressed: _loading ? null : onConnect,
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Connect'),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return guard(Scaffold(
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
        title: const BrandedAppBarTitle('Bluetooth Settings'),
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
        child: ListView(
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
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_loadError != null) ...[
              Card(
                elevation: 0,
                color: colorScheme.errorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    _loadError!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
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
            buildStatusCard(
              label: 'Printer',
              deviceName: _attachedPrinter?.name,
              isConnected: _isConnected,
              icon: Icons.print_outlined,
              onConnect: _onConnectPrinterPressed,
              onDisconnect: _onDisconnectPrinterPressed,
            ),
            const SizedBox(height: 12),
            buildStatusCard(
              label: 'Scale',
              deviceName: _attachedScale?.name,
              isConnected: _isScaleConnected,
              icon: Icons.scale_outlined,
              onConnect: _onConnectScalePressed,
              onDisconnect: _onDisconnectScalePressed,
            ),
            if (_isScaleConnected && _latestWeight != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Live weight: ${_latestWeight?.toStringAsFixed(2) ?? '--'} kg',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_devices.isNotEmpty)
              Text(
                'Paired devices: ${_devices.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    ));
  }
}
