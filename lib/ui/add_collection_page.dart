import 'dart:async';
import 'dart:math';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_model.dart';
import '../data/daily_collection_repository.dart';
import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import '../data/user_repository.dart';
import '../services/bc/bc_settings_store.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/classic_scale_service.dart';
import '../services/collection_settings_service.dart';
import '../services/session_store.dart';

class AddCollectionPage extends StatefulWidget {
  const AddCollectionPage({super.key});

  @override
  State<AddCollectionPage> createState() => _AddCollectionPageState();
}

class _HeldLoad {
  const _HeldLoad({required this.kg, required this.bags});

  final double kg;
  final int bags;
}

class _AddCollectionPageState extends State<AddCollectionPage> {
  StreamSubscription<int?>? _btStateSub;
  static final _random = Random();
  final _formKey = GlobalKey<FormState>();
  final _kgController = TextEditingController();
  final _bagsController = TextEditingController();
  TextEditingController? _farmerSearchController;
  FocusNode? _farmerSearchFocusNode;
  bool _isSaving = false;
  bool _isConnectingScale = false;
  bool _isScaleConnected = false;
  bool _isPrinterConnected = false;
  bool _isUpdatingGrossFromScale = false;
  bool _grossWeightFromScale = false;
  bool _awaitingGrossResetAfterHold = false;
  bool _isAdmin = false;
  bool _bagsManuallyEdited = false;
  String _scaleStatus = 'Checking Classic Bluetooth...';
  StreamSubscription<double>? _weightSub;
  DateTime _lastScaleWeightAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _connectionMonitorTimer;
  DateTime _lastScaleReconnectAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPrinterReconnectAttempt = DateTime.fromMillisecondsSinceEpoch(
    0,
  );
  String _farmerNumber = '';
  String _farmerName = '';
  String _factory = '';
  String _currentFactory = '';
  bool _useAutoCalculate = true;
  static const double _tarePerBag = 0.5;
  static const double _grossResetThresholdKg = 0.05;
  static const Duration _printerReconnectInterval = Duration(seconds: 3);
  static const Duration _scaleReconnectInterval = Duration(seconds: 6);
  static const Duration _scaleStreamStaleAfter = Duration(seconds: 3);
  final List<_HeldLoad> _heldLoads = [];

  // Add a FocusNode for the Gross Weight field
  final _grossWeightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bagsController.text = '0';
    _startBluetoothConnectionMonitor();
    unawaited(_initializeScale());
    unawaited(_resolveAdminRights());
    unawaited(_loadCurrentFactory());

    // Listen to native Bluetooth adapter/device events from the plugin state stream.
    _btStateSub = BlueThermalPrinter.instance.onStateChanged().listen(
      _onBluetoothStateChanged,
      onError: (_) {},
    );
  }

  void _onBluetoothStateChanged(int? state) {
    if (!mounted) return;

    switch (state) {
      case BlueThermalPrinter.CONNECTED:
        // ACL connected can happen outside the app; explicitly reconnect scale thread.
        if (!_isConnectingScale) {
          unawaited(_connectScale());
        }
        unawaited(_refreshPrinterStatus());
        break;
      case BlueThermalPrinter.DISCONNECTED:
      case BlueThermalPrinter.DISCONNECT_REQUESTED:
      case BlueThermalPrinter.STATE_ON:
      case BlueThermalPrinter.STATE_OFF:
      case BlueThermalPrinter.STATE_TURNING_ON:
      case BlueThermalPrinter.STATE_TURNING_OFF:
        unawaited(_monitorBluetoothConnections());
        break;
      default:
        break;
    }
  }

  void _startBluetoothConnectionMonitor() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_monitorBluetoothConnections());
    });
  }

  Future<void> _monitorBluetoothConnections() async {
    await Future.wait<void>([_refreshPrinterStatus(), _refreshScaleStatus()]);

    if (!mounted) return;

    if (!_isScaleConnected &&
        !_isConnectingScale &&
        _canAttemptScaleReconnect(_lastScaleReconnectAttempt)) {
      _lastScaleReconnectAttempt = DateTime.now();
      await _connectScale();
    }

    if (!_isPrinterConnected &&
        _canAttemptPrinterReconnect(_lastPrinterReconnectAttempt)) {
      _lastPrinterReconnectAttempt = DateTime.now();
      await _reconnectAttachedPrinter();
    }
  }

  bool _canAttemptPrinterReconnect(DateTime lastAttempt) {
    return DateTime.now().difference(lastAttempt) >= _printerReconnectInterval;
  }

  bool _canAttemptScaleReconnect(DateTime lastAttempt) {
    return DateTime.now().difference(lastAttempt) >= _scaleReconnectInterval;
  }

  Future<void> _initializeScale() async {
    await _refreshPrinterStatus();
    await _refreshScaleStatus();
    await _connectScale();
  }

  Future<void> _loadCurrentFactory() async {
    final settings = await BcSettingsStore.instance.load();
    if (!mounted) return;
    setState(() => _currentFactory = settings.factory.trim());
  }

  Future<void> _resolveAdminRights() async {
    final username = await SessionStore.instance.getCurrentUsername();
    if (!mounted || username == null) return;
    final user = await context.read<UserRepository>().getLocalUserByUsername(
      username,
    );
    if (!mounted) return;
    setState(() {
      _isAdmin = user?.rights.trim() == 'Admin';
    });
  }

  Future<void> _refreshPrinterStatus() async {
    bool connected = false;
    try {
      // Check whether the *attached* printer is connected, not just any
      // Bluetooth socket. This avoids stale state from the plugin singleton.
      connected = await BluetoothPrinterService.instance
          .isAttachedPrinterConnected();
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    setState(() {
      _isPrinterConnected = connected;
    });
  }

  Future<void> _reconnectAttachedPrinter() async {
    // Burst-retry up to 3 times with 2-second gaps. Thermal printers often
    // need a few seconds after power-on before their Bluetooth module accepts
    // connections.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final connected = await BluetoothPrinterService.instance
            .connectAttachedPrinter();
        if (connected) {
          await _refreshPrinterStatus();
          return;
        }
      } catch (error) {
        debugPrint('Printer reconnect attempt $attempt failed: $error');
      }
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _refreshScaleStatus() async {
    bool connected = false;
    try {
      connected = await ClassicScaleService.instance.isConnected();
    } catch (_) {
      connected = false;
    }

    // If scale is connected but we are not listening yet, establish the stream once.
    if (connected && _weightSub == null && !_isConnectingScale) {
      await _connectScale();
      return; // _connectScale will update state and status
    }

    if (!connected) {
      await _weightSub?.cancel();
      _weightSub = null;
    }

    if (!mounted) return;
    final shouldUpdateStatusText =
        !connected || (!_isConnectingScale && !_awaitingGrossResetAfterHold);
    setState(() {
      _isScaleConnected = connected;
      if (!connected) {
        _awaitingGrossResetAfterHold = false;
      }
      if (shouldUpdateStatusText) {
        _scaleStatus = connected
            ? 'Connected (Classic Bluetooth)'
            : 'Disconnected (Classic Bluetooth)';
      }
    });
  }

  @override
  void dispose() {
    _grossWeightFocusNode.dispose(); // Dispose the FocusNode
    _connectionMonitorTimer?.cancel();
    _weightSub?.cancel();
    _btStateSub?.cancel();
    _kgController.dispose();
    _bagsController.dispose();
    super.dispose();
  }

  Future<void> _connectScale() async {
    if (_isConnectingScale) {
      return;
    }

    setState(() {
      _isConnectingScale = true;
      _scaleStatus = 'Connecting (Classic Bluetooth)...';
    });

    final connected = await ClassicScaleService.instance.connectToScale();

    await _weightSub?.cancel();
    if (connected) {
      _weightSub = ClassicScaleService.instance.weightStream.listen((weight) {
        _handleLiveScaleWeight(weight);
      });
    }

    if (!mounted) return;
    setState(() {
      _isConnectingScale = false;
      _isScaleConnected = connected;
      _scaleStatus = connected
          ? 'Connected (Classic Bluetooth)'
          : 'Disconnected (Classic Bluetooth)';
    });
  }

  Future<void> _disconnectScale() async {
    await _weightSub?.cancel();
    _weightSub = null;
    await ClassicScaleService.instance.disconnect();
    if (!mounted) return;
    setState(() {
      _isScaleConnected = false;
      _isConnectingScale = false;
      _awaitingGrossResetAfterHold = false;
      _scaleStatus = 'Disconnected (Classic Bluetooth)';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = context.read<DailyCollectionRepository>();

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final no = now.millisecondsSinceEpoch;
    final uniqueSuffix = _random.nextInt(1000000).toString().padLeft(6, '0');
    final kg = double.tryParse(_kgController.text.trim());
    final noOfBags = _currentAutoBags();
    final settings = await CollectionSettingsService.instance.load();
    final tare = settings.tareWeight * noOfBags;
    final currentUser =
        (await SessionStore.instance.getCurrentUsername())?.trim() ?? 'local';

    final collection = DailyCollection(
      farmersNumber: _farmerNumber.trim(),
      collectionsDate: now,
      collectionNumber: 'COL-$no-$uniqueSuffix',
      coffeeType: settings.coffeeType,
      no: no,
      farmersName: _farmerName,
      kgCollected: kg,
      cancelled: 'N',
      paid: 0,
      idNumber: '',
      factory: _factory,
      sent: false,
      comments: '',
      cumm: null,
      userName: currentUser,
      can: '',
      collectionTime: now,
      collectType: _currentCollectType(),
      crop: settings.crop,
      gross: null,
      tare: tare,
      noOfBags: noOfBags,
      deliveredBy: '',
      coffeTypeName: '',
      updated: false,
    );

    await repository.addCollection(collection);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  int _bagsFromWeight(double kg) {
    if (kg <= 0) return 0;
    return (kg / 90).ceil();
  }

  int _currentAutoBags() {
    return int.tryParse(_bagsController.text.trim()) ?? 0;
  }

  void _updateAutoBags() {
    if (_bagsManuallyEdited) return;
    final bags = _bagsFromWeight(
      double.tryParse(_kgController.text.trim()) ?? 0,
    ).toString();
    if (_bagsController.text != bags) {
      _bagsController.text = bags;
    }
  }

  bool _isGrossReset(double kg) => kg.abs() <= _grossResetThresholdKg;

  bool _hasFarmerNumber() => _farmerNumber.trim().isNotEmpty;

  bool _hasActiveScaleStream() {
    if (!_isScaleConnected || _weightSub == null) {
      return false;
    }
    return DateTime.now().difference(_lastScaleWeightAt) <=
        _scaleStreamStaleAfter;
  }

  void _handleLiveScaleWeight(double weight) {
    _lastScaleWeightAt = DateTime.now();
    if (!_hasFarmerNumber()) {
      return;
    }

    final nextValue = weight.toStringAsFixed(2);
    if (_kgController.text != nextValue) {
      _isUpdatingGrossFromScale = true;
      _kgController.text = nextValue;
      _kgController.selection = TextSelection.collapsed(
        offset: nextValue.length,
      );
      _isUpdatingGrossFromScale = false;
    }

    if (!mounted) return;
    setState(() {
      _grossWeightFromScale = true;
      _bagsManuallyEdited = false;
      _updateAutoBags();
      if (_awaitingGrossResetAfterHold && _isGrossReset(weight)) {
        _awaitingGrossResetAfterHold = false;
        _scaleStatus = 'Connected (Classic Bluetooth)';
      }
    });
  }

  void _addHeldLoad() {
    if (_awaitingGrossResetAfterHold) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wait for Gross Weight to reset to 0.00 kg before next Hold.',
          ),
        ),
      );
      return;
    }

    final kg = double.tryParse(_kgController.text.trim()) ?? 0;
    final bags = _currentAutoBags();
    if (kg <= 0 && bags <= 0) return;

    setState(() {
      _heldLoads.add(_HeldLoad(kg: kg, bags: bags));
      _kgController.text = '0.00';
      _bagsController.clear();
      _updateAutoBags();
      if (_isScaleConnected) {
        _awaitingGrossResetAfterHold = true;
        _scaleStatus =
            'Hold captured. Waiting for Gross Weight to reset to 0.00 kg...';
      }
    });
  }

  void _removeHeldLoad(int index) {
    setState(() {
      _heldLoads.removeAt(index);
    });
  }

  double _heldGrossTotal() {
    return _heldLoads.fold(0, (sum, item) => sum + item.kg);
  }

  int _heldBagsTotal() {
    return _heldLoads.fold(0, (sum, item) => sum + item.bags);
  }

  double _calculateGrossTotal() {
    final kg = double.tryParse(_kgController.text) ?? 0;
    return kg + _heldGrossTotal();
  }

  double _calculateTare() {
    final currentBags = _currentAutoBags();
    final totalBags = currentBags + _heldBagsTotal();
    return totalBags * _tarePerBag;
  }

  double _calculateNetCollected() {
    return _calculateGrossTotal() - _calculateTare();
  }

  DateTime _collectionTimestamp(DailyCollection item) {
    return item.collectionTime ?? item.collectionsDate;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _reversalKeyFor(DailyCollection collection) {
    final collectionNumber = collection.collectionNumber.trim();
    return collectionNumber.isEmpty
        ? collection.no.toString()
        : collectionNumber;
  }

  String _reversalCommentFor(DailyCollection collection) {
    return 'Reversal of ${_reversalKeyFor(collection)}';
  }

  bool _isReversalEntry(DailyCollection collection) {
    final collectType = collection.collectType.trim().toLowerCase();
    final comments = collection.comments.trim().toLowerCase();
    return collectType == 'reversal' || comments.startsWith('reversal of ');
  }

  bool _hasReversalFor(
    DailyCollection original,
    List<DailyCollection> allCollections,
  ) {
    final expectedComment = _reversalCommentFor(original).toLowerCase();
    return allCollections.any(
      (entry) =>
          entry.no != original.no &&
          entry.comments.trim().toLowerCase() == expectedComment,
    );
  }

  Farmer? _selectedFarmer(List<Farmer> farmers) {
    final farmerNo = _farmerNumber.trim();
    if (farmerNo.isEmpty) {
      return null;
    }
    for (final farmer in farmers) {
      if (farmer.no.trim().toLowerCase() == farmerNo.toLowerCase()) {
        return farmer;
      }
    }
    return null;
  }

  double _totalKgTodayForFarmer(
    List<DailyCollection> allCollections,
    String farmerNo,
    DateTime day,
  ) {
    final normalizedFarmerNo = farmerNo.trim().toLowerCase();
    return allCollections
        .where((item) {
          return item.farmersNumber.trim().toLowerCase() ==
                  normalizedFarmerNo &&
              _isSameDate(_collectionTimestamp(item), day);
        })
        .fold(0.0, (sum, item) => sum + (item.kgCollected ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const accentColor = Color(0xFF0F766E);
    const accentSoft = Color(0xFF99F6E4);
    const pageTop = Color(0xFFF0FDFA);
    const pageBottom = Color(0xFFFFFFFF);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final farmers = context.watch<FarmerRepository>().farmers;
    final collections = context.watch<DailyCollectionRepository>().items;
    final now = DateTime.now();
    final factoryCollections = collections.where((item) {
      return item.factory.trim().toUpperCase() == _currentFactory.toUpperCase();
    }).toList();

    final todayCollections =
        factoryCollections
            .where((item) => _isSameDate(_collectionTimestamp(item), now))
            .toList()
          ..sort(
            (a, b) =>
                _collectionTimestamp(b).compareTo(_collectionTimestamp(a)),
          );
    final totalTodayKg = todayCollections.fold<double>(
      0,
      (sum, item) => sum + (item.kgCollected ?? 0),
    );

    final grossTotal = _calculateGrossTotal();
    _updateAutoBags();
    final totalTare = _calculateTare();
    final netCollected = _calculateNetCollected();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'Total: ${totalTodayKg.toStringAsFixed(2)} kg',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _buildConnectionBadge(
            label: 'Printer',
            connected: _isPrinterConnected,
            checking: false,
          ),
          const SizedBox(width: 8),
          _buildConnectionBadge(
            label: 'Scale',
            connected: _isScaleConnected,
            checking: _isConnectingScale,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pageTop, pageBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: accentSoft.withAlpha(80),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: accentSoft.withAlpha(55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        shrinkWrap: true,
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        children: [
                          // Farmer Search Card
                          Card(
                            elevation: 3,
                            color: colors.surface.withAlpha(245),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Autocomplete<Farmer>(
                                          optionsBuilder: (textEditingValue) {
                                            final query = textEditingValue.text
                                                .trim()
                                                .toLowerCase();
                                            if (query.isEmpty) {
                                              return const Iterable<
                                                Farmer
                                              >.empty();
                                            }
                                            return farmers.where((farmer) {
                                              return farmer.no
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  farmer.name
                                                      .toLowerCase()
                                                      .contains(query);
                                            });
                                          },
                                          displayStringForOption: (farmer) =>
                                              farmer.no,
                                          onSelected: (farmer) {
                                            setState(() {
                                              _farmerNumber = farmer.no;
                                              _farmerName = farmer.name;
                                              _factory = farmer.factory;
                                            });
                                            // Move focus to the Gross Weight field
                                            _grossWeightFocusNode
                                                .requestFocus();

                                            if (!_hasActiveScaleStream()) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (!mounted) return;
                                                    final text =
                                                        _kgController.text;
                                                    _kgController.selection =
                                                        TextSelection(
                                                          baseOffset: 0,
                                                          extentOffset:
                                                              text.length,
                                                        );
                                                  });
                                            }
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                textEditingController,
                                                focusNode,
                                                onFieldSubmitted,
                                              ) {
                                                _farmerSearchController =
                                                    textEditingController;
                                                _farmerSearchFocusNode =
                                                    focusNode;
                                                if (textEditingController
                                                        .text !=
                                                    _farmerNumber) {
                                                  textEditingController.text =
                                                      _farmerNumber;
                                                  textEditingController
                                                          .selection =
                                                      TextSelection.collapsed(
                                                        offset: _farmerNumber
                                                            .length,
                                                      );
                                                }
                                                return TextFormField(
                                                  controller:
                                                      textEditingController,
                                                  focusNode: focusNode,
                                                  autofocus: true,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _farmerNumber = value;
                                                      if (value
                                                          .trim()
                                                          .isEmpty) {
                                                        _farmerName = '';
                                                        _factory = '';
                                                      }
                                                    });
                                                  },
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Farmer Number',
                                                        prefixIcon: Icon(
                                                          Icons.search,
                                                        ),
                                                        border:
                                                            InputBorder.none,
                                                      ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.trim().isEmpty) {
                                                      return 'Enter farmer number';
                                                    }
                                                    return null;
                                                  },
                                                );
                                              },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: OverflowBox(
                                                alignment: Alignment.topLeft,
                                                maxWidth: MediaQuery.of(
                                                  context,
                                                ).size.width,
                                                child: Material(
                                                  elevation: 4,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width -
                                                        32,
                                                    child: ListView.separated(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      shrinkWrap: true,
                                                      itemCount: options.length,
                                                      separatorBuilder:
                                                          (_, __) =>
                                                              const Divider(
                                                                height: 1,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        final farmer = options
                                                            .elementAt(index);
                                                        return ListTile(
                                                          title: Text(
                                                            farmer.no,
                                                          ),
                                                          subtitle: Row(
                                                            children: [
                                                              if (farmer
                                                                      .multipleDelivery ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        right:
                                                                            4,
                                                                      ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .repeat,
                                                                    size: 16,
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                              Flexible(
                                                                child: Text(
                                                                  farmer.name,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                              if (farmer
                                                                      .multipleDelivery ==
                                                                  true)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        left: 4,
                                                                      ),
                                                                  child: Text(
                                                                    '(Multiple)',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.primary,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          onTap: () =>
                                                              onSelected(
                                                                farmer,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.all(8),
                                          child: Row(
                                            children: [
                                              if (_farmerName.isNotEmpty)
                                                Builder(
                                                  builder: (ctx) {
                                                    final farmersList = ctx
                                                        .watch<
                                                          FarmerRepository
                                                        >()
                                                        .farmers;
                                                    final farmer = farmersList
                                                        .where(
                                                          (f) =>
                                                              f.no
                                                                  .trim()
                                                                  .toLowerCase() ==
                                                              _farmerNumber
                                                                  .trim()
                                                                  .toLowerCase(),
                                                        )
                                                        .firstOrNull;
                                                    if (farmer
                                                            ?.multipleDelivery ==
                                                        true) {
                                                      return Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 4,
                                                                ),
                                                            child: Icon(
                                                              Icons.repeat,
                                                              size: 16,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                          ),
                                                          Text(
                                                            '(Multiple)',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                        ],
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              Flexible(
                                                child: Text(
                                                  _farmerName.isEmpty
                                                      ? 'Farmer name'
                                                      : _farmerName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            _farmerName.isEmpty
                                                            ? colors
                                                                  .onSurfaceVariant
                                                            : colors.onSurface,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Weight & Bags Card
                          Card(
                            elevation: 3,
                            color: colors.surface.withAlpha(245),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Weight & Bags',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        'Tare setting: 0.50 kg/bag',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 5),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: FilledButton.icon(
                                          onPressed:
                                              _awaitingGrossResetAfterHold
                                              ? null
                                              : _addHeldLoad,
                                          icon: const Icon(
                                            Icons.pause_circle_outlined,
                                          ),
                                          label: const Text('Hold'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                colors.surfaceContainerHighest,
                                            foregroundColor: colors.onSurface,
                                            minimumSize: const Size(150, 48),
                                          ),
                                        ),
                                      ),
                                      if (_heldLoads.isNotEmpty) ...[
                                        const SizedBox(width: 7),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceContainer,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                ..._heldLoads.asMap().entries.map((
                                                  entry,
                                                ) {
                                                  final idx = entry.key;
                                                  final load = entry.value;
                                                  return Align(
                                                    alignment: Alignment.center,
                                                    child: FractionallySizedBox(
                                                      widthFactor: 0.9,
                                                      child: Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 4,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: colors.surface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: colors
                                                                .outlineVariant,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                '${idx + 1}: ${load.kg.toStringAsFixed(2)} kg, ${load.bags} bags',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                            ),
                                                            InkWell(
                                                              onTap: () =>
                                                                  _removeHeldLoad(
                                                                    idx,
                                                                  ),
                                                              child: const Padding(
                                                                padding:
                                                                    EdgeInsets.all(
                                                                      2,
                                                                    ),
                                                                child: Icon(
                                                                  Icons.close,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                                Text(
                                                  'Held total: ${_heldGrossTotal().toStringAsFixed(2)} kg, ${_heldBagsTotal()} bags',
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_awaitingGrossResetAfterHold)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Reset scale Gross Weight to 0.00 kg to enable next Hold.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Gross Weight',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: colors.outline,
                                                  ),
                                                ),
                                              ),
                                              child: TextFormField(
                                                controller: _kgController,
                                                focusNode:
                                                    _grossWeightFocusNode, // Attach the FocusNode here
                                                textAlign: TextAlign.center,
                                                readOnly:
                                                    !_hasFarmerNumber() ||
                                                    !_isAdmin,
                                                onTap: () {
                                                  if (!_hasFarmerNumber()) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Enter farmer number first.',
                                                        ),
                                                      ),
                                                    );
                                                  } else if (!_isAdmin) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Only admins can enter gross weight manually.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                      hintText: '0',
                                                    ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                validator: (value) {
                                                  if (!_hasFarmerNumber()) {
                                                    return 'Enter farmer number first';
                                                  }
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return 'Enter kg';
                                                  }
                                                  if (double.tryParse(value) ==
                                                      null) {
                                                    return 'Valid number';
                                                  }
                                                  return null;
                                                },
                                                onChanged: (_) {
                                                  _bagsManuallyEdited = false;
                                                  _updateAutoBags();
                                                  setState(() {});
                                                  if (!_isUpdatingGrossFromScale) {
                                                    _grossWeightFromScale =
                                                        false;
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'No of Bags',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: colors.outline,
                                                  ),
                                                ),
                                              ),
                                              child: TextFormField(
                                                controller: _bagsController,
                                                textAlign: TextAlign.center,
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                      hintText: '0',
                                                    ),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (_) {
                                                  _bagsManuallyEdited = true;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoBox(
                                          context,
                                          'Gross total',
                                          '${grossTotal.toStringAsFixed(2)} kg',
                                          colors,
                                          theme.textTheme,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildInfoBox(
                                          context,
                                          'Total tare',
                                          '${totalTare.toStringAsFixed(2)} kg',
                                          colors,
                                          theme.textTheme,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildInfoBox(
                                          context,
                                          'Net collected',
                                          '${netCollected.toStringAsFixed(2)} kg',
                                          colors,
                                          theme.textTheme,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Today\'s collections',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Total: ${totalTodayKg.toStringAsFixed(2)} kg',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: todayCollections.isEmpty
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'No collections recorded today.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: todayCollections.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 10),
                                      itemBuilder: (context, index) {
                                        final item = todayCollections[index];
                                        final farmerNumber = item.farmersNumber
                                            .trim();
                                        final farmerName = item.farmersName
                                            .trim();
                                        final summary =
                                            '${(item.kgCollected ?? 0).toStringAsFixed(2)} kg • ${item.noOfBags ?? 0} bags';
                                        final hasExistingReversal =
                                            _hasReversalFor(item, collections);
                                        final isReversal = _isReversalEntry(
                                          item,
                                        );
                                        final canReverse =
                                            !_isReversalEntry(item) &&
                                            !hasExistingReversal &&
                                            ((item.kgCollected ?? 0) > 0 ||
                                                (item.gross ?? 0) > 0 ||
                                                (item.tare ?? 0) > 0);
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    farmerNumber,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    farmerName.isEmpty
                                                        ? 'No name'
                                                        : farmerName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontSize: 11,
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              summary,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            IconButton(
                                              tooltip:
                                                  isReversal ||
                                                      hasExistingReversal
                                                  ? 'Reversed transactions cannot be printed'
                                                  : 'Reprint receipt',
                                              onPressed:
                                                  _isSaving ||
                                                      isReversal ||
                                                      hasExistingReversal
                                                  ? null
                                                  : () => _reprintCollection(
                                                      item,
                                                    ),
                                              icon: const Icon(
                                                Icons.print_outlined,
                                                size: 18,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: canReverse
                                                  ? 'Reverse entry'
                                                  : (hasExistingReversal
                                                        ? 'Already reversed'
                                                        : 'Not reversible'),
                                              onPressed:
                                                  _isSaving || !canReverse
                                                  ? null
                                                  : () =>
                                                        _confirmReverseCollection(
                                                          item,
                                                        ),
                                              icon: Icon(
                                                Icons.undo,
                                                size: 18,
                                                color: canReverse
                                                    ? Colors.red.shade700
                                                    : colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 84),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    keyboardInset > 0 ? keyboardInset + 8 : 16,
                  ),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _printReceipt,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      _isSaving
                          ? 'Printing...'
                          : 'Print ${netCollected.toStringAsFixed(2)} kg',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    final farmers = context.read<FarmerRepository>().farmers;
    final selectedFarmer = _selectedFarmer(farmers);
    final now = DateTime.now();
    final allowsMultiple = selectedFarmer?.multipleDelivery == true;
    final totalKgToday = _totalKgTodayForFarmer(
      context.read<DailyCollectionRepository>().items,
      _farmerNumber,
      now,
    );
    if (!allowsMultiple && totalKgToday > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This farmer is limited to one collection per day (already collected ${totalKgToday.toStringAsFixed(2)} kg). Enable Multiple delivery to allow more.',
          ),
        ),
      );
      return;
    }

    if (_calculateNetCollected() < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Net collected is negative. Adjust weight or bags before printing.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      // Save first so collection persistence does not depend on printer state.
      final repository = context.read<DailyCollectionRepository>();
      final no = now.millisecondsSinceEpoch;
      final uniqueSuffix = _random.nextInt(1000000).toString().padLeft(6, '0');
      final kg = double.tryParse(_kgController.text.trim());
      final noOfBags = _currentAutoBags();
      final allItems = context.read<DailyCollectionRepository>().items;
      final settings = await CollectionSettingsService.instance.load();
      final tare = settings.tareWeight * noOfBags;
      final currentUser =
          (await SessionStore.instance.getCurrentUsername())?.trim() ?? 'local';
      final existingTotal = allItems
          .where((c) {
            return c.farmersNumber.trim().toLowerCase() ==
                    _farmerNumber.trim().toLowerCase() &&
                !_isReversalEntry(c);
          })
          .fold(0.0, (sum, c) => sum + (c.kgCollected ?? 0));
      final seasonCumm = existingTotal + (kg ?? 0);

      final collection = DailyCollection(
        farmersNumber: _farmerNumber.trim(),
        collectionsDate: now,
        collectionNumber: 'COL-$no-$uniqueSuffix',
        coffeeType: settings.coffeeType,
        no: no,
        farmersName: _farmerName,
        kgCollected: kg,
        cancelled: 'N',
        paid: 0,
        idNumber: '',
        factory: _factory,
        sent: false,
        comments: '',
        cumm: seasonCumm,
        userName: currentUser,
        can: '',
        collectionTime: now,
        collectType: _currentCollectType(),
        crop: settings.crop,
        gross: null,
        tare: tare,
        noOfBags: noOfBags,
        deliveredBy: '',
        coffeTypeName: '',
        updated: false,
      );

      await repository.addCollection(collection);

      // Fire-and-forget printing so the UI is never blocked by Bluetooth.
      _printToThermalPrinter(collection);

      if (!mounted) return;
      _resetForNextCollectionSession();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved successfully. Printing receipt...'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }

  void _resetForNextCollectionSession() {
    setState(() {
      _isSaving = false;
      _farmerNumber = '';
      _farmerName = '';
      _factory = '';
      _grossWeightFromScale = false;
      _kgController.text = '0.00';
      _bagsController.text = '0';
      _bagsManuallyEdited = false;
      _heldLoads.clear();
      _awaitingGrossResetAfterHold = false;
      if (_isScaleConnected) {
        _scaleStatus = 'Connected (Classic Bluetooth)';
      }
    });
    // Explicitly clear controller-backed fields to avoid stale values.
    _farmerSearchController?.value = const TextEditingValue(text: '');
    _kgController.value = const TextEditingValue(text: '0.00');
    _bagsController.value = const TextEditingValue(text: '0');

    // Return focus to farmer search for the next entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _farmerSearchFocusNode?.requestFocus();
    });
  }

  String _currentCollectType() {
    return _grossWeightFromScale ? 'Auto' : 'Manual';
  }

  Future<void> _printToThermalPrinter(DailyCollection collection) async {
    try {
      bool connected = await BluetoothPrinterService.instance.isConnected();
      if (!connected) {
        connected = await BluetoothPrinterService.instance
            .connectAttachedPrinter();
        if (mounted) {
          setState(() => _isPrinterConnected = connected);
        }
      }
      if (!connected) {
        throw 'Printer not connected. Attach and connect a printer in Settings.';
      }

      final allItems = context.read<DailyCollectionRepository>().items;
      final breakdown = BluetoothPrinterService.buildFactoryBreakdown(
        allItems,
        collection.farmersNumber,
      );

      await BluetoothPrinterService.instance.printReceipt(
        collection,
        factoryBreakdown: breakdown,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt printed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Printing failed: $error')));
    }
  }

  void _reprintCollection(DailyCollection collection) {
    final repository = context.read<DailyCollectionRepository>();
    if (_isReversalEntry(collection) ||
        _hasReversalFor(collection, repository.items)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reversal transactions cannot be printed.'),
        ),
      );
      return;
    }

    // Fire-and-forget so the UI is never blocked by Bluetooth.
    _printToThermalPrinter(collection);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reprint queued.')));
  }

  Future<void> _confirmReverseCollection(DailyCollection original) async {
    final farmerLabel = original.farmersName.trim().isEmpty
        ? original.farmersNumber
        : original.farmersName;
    final shouldReverse = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reverse collection?'),
          content: Text(
            'Create a reversing entry for $farmerLabel with negative kg, gross, and tare?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reverse'),
            ),
          ],
        );
      },
    );

    if (shouldReverse != true) {
      return;
    }

    await _reverseCollection(original);
  }

  Future<void> _reverseCollection(DailyCollection original) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = context.read<DailyCollectionRepository>();
      if (_isReversalEntry(original) ||
          _hasReversalFor(original, repository.items)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This transaction has already been reversed.'),
            ),
          );
        }
        return;
      }

      final now = DateTime.now();
      final no = now.millisecondsSinceEpoch;
      final uniqueSuffix = _random.nextInt(1000000).toString().padLeft(6, '0');
      final reversedKg = -(original.kgCollected ?? 0);
      final reversedGross = -(original.gross ?? original.kgCollected ?? 0);
      final reversedTare = -(original.tare ?? 0);
      final reversedBags = original.noOfBags == null
          ? null
          : -original.noOfBags!;

      final reversal = DailyCollection(
        farmersNumber: original.farmersNumber,
        collectionsDate: now,
        collectionNumber: 'REV-$no-$uniqueSuffix',
        coffeeType: original.coffeeType,
        no: no,
        farmersName: original.farmersName,
        kgCollected: reversedKg,
        cancelled: original.cancelled,
        paid: original.paid,
        idNumber: original.idNumber,
        factory: original.factory,
        sent: false,
        comments: _reversalCommentFor(original),
        cumm: original.cumm,
        userName: original.userName,
        can: original.can,
        collectionTime: now,
        collectType: 'Reversal',
        crop: original.crop,
        gross: reversedGross,
        tare: reversedTare,
        noOfBags: reversedBags,
        deliveredBy: original.deliveredBy,
        coffeTypeName: original.coffeTypeName,
        updated: false,
      );

      await repository.addCollection(reversal);

      if (!mounted) return;
      final farmerLabel = original.farmersName.trim().isEmpty
          ? original.farmersNumber
          : original.farmersName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reversed entry created for $farmerLabel.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reverse failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildInfoBox(
    BuildContext context,
    String label,
    String value,
    ColorScheme colors,
    TextTheme theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge({
    required String label,
    required bool connected,
    required bool checking,
  }) {
    final stateText = checking
        ? 'Checking'
        : (connected ? 'Connected' : 'Disconnected');
    final stateColor = checking
        ? Colors.amber.shade700
        : (connected ? Colors.green.shade700 : Colors.red.shade700);
    final iconData = label == 'Printer' ? Icons.print : Icons.scale;

    return Tooltip(
      message: '$label: $stateText',
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: stateColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: stateColor.withValues(alpha: 0.35)),
        ),
        child: Icon(iconData, size: 16, color: stateColor),
      ),
    );
  }
}
