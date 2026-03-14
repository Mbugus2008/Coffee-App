import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_model.dart';
import '../data/daily_collection_repository.dart';
import '../data/farmer_repository.dart';
import '../services/bluetooth_printer_service.dart';
import 'add_collection_page.dart';
import 'app_drawer.dart' as app_drawer;
import 'brand_logo.dart';

class DailyCollectionsPage extends StatefulWidget {
  const DailyCollectionsPage({super.key});

  @override
  State<DailyCollectionsPage> createState() => _DailyCollectionsPageState();
}

class _DailyCollectionsPageState extends State<DailyCollectionsPage> {
  bool _isSyncingToBc = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DailyCollectionRepository>().refreshFromServer();
      context.read<FarmerRepository>().loadFarmers();
    });
  }

  Future<void> _syncToBc() async {
    if (_isSyncingToBc) return;

    setState(() {
      _isSyncingToBc = true;
    });

    final result = await context.read<DailyCollectionRepository>().syncWithBc();

    if (!mounted) return;
    setState(() {
      _isSyncingToBc = false;
    });

    var message = 'Collections refreshed from BC.';
    if (result.attempted > 0) {
      message =
          'Synced ${result.synced}/${result.attempted} pending collections to BC.';
      if (result.failed > 0) {
        message = '$message ${result.failed} failed.';
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (result.failureDetails.isNotEmpty) {
      await _showSyncErrors(result.failureDetails);
    }
  }

  Future<void> _showSyncErrors(List<String> errors) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('BC Sync Errors'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(errors.join('\n\n')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectPrinter() async {
    final devices = await BluetoothPrinterService.instance.getBondedDevices();
    if (!mounted) return;

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paired printers found.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<PrinterDeviceInfo>(
      context: context,
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              title: Text(device.name),
              subtitle: Text('${device.address} • ${device.source}'),
              onTap: () => Navigator.of(context).pop(device),
            );
          },
        );
      },
    );

    if (selected == null) return;

    try {
      await BluetoothPrinterService.instance.connect(selected);
    } catch (error) {
      debugPrint('Printer connect failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Printer connect failed: $error')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Connected to ${selected.name}')));
  }

  Future<void> _printReceipt(DailyCollection item) async {
    var connected = await BluetoothPrinterService.instance.isConnected();
    if (!connected) {
      connected = await BluetoothPrinterService.instance
          .connectAttachedPrinter();
    }

    if (!connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach and connect a printer first.')),
      );
      return;
    }

    try {
      await BluetoothPrinterService.instance.printReceipt(item);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receipt sent to printer.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to print receipt.')));
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<DailyCollectionRepository>().items;
    final totalFarmersInDb = context.watch<FarmerRepository>().farmers.length;
    final totalOverallKgCollected = items.fold<double>(
      0,
      (sum, item) => sum + (item.kgCollected ?? 0),
    );
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentRoute = routeName == '/' ? '/dashboard' : routeName;
    final isHome = (currentRoute ?? '/dashboard') == '/dashboard';
    final now = DateTime.now();

    final todayItems = items.where((item) {
      final timestamp = item.collectionTime ?? item.collectionsDate;
      return _isSameDate(timestamp, now);
    }).toList();

    final servedFarmers = <String>{};
    double totalKgCollected = 0;
    for (final item in todayItems) {
      final farmerNo = item.farmersNumber.trim();
      if (farmerNo.isNotEmpty) {
        servedFarmers.add(farmerNo);
      }
      totalKgCollected += item.kgCollected ?? 0;
    }

    final topThreeByKg = [...todayItems]
      ..sort((a, b) => (b.kgCollected ?? 0).compareTo(a.kgCollected ?? 0));
    final topThree = topThreeByKg.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Dashboard v2'),
        leadingWidth: 96,
        leading: Builder(
          builder: (context) {
            return Row(
              children: [
                IconButton(
                  tooltip: 'Back to home',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: isHome
                      ? null
                      : () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/dashboard',
                            (route) => false,
                          );
                        },
                ),
                IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Sync to Business Central',
            icon: _isSyncingToBc
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            onPressed: _isSyncingToBc ? null : _syncToBc,
          ),
          IconButton(
            tooltip: 'Collections',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/collections');
            },
          ),
          IconButton(
            tooltip: 'Connect printer',
            icon: const Icon(Icons.print_outlined),
            onPressed: _selectPrinter,
          ),
        ],
      ),
      drawer: app_drawer.AppDrawer(currentRoute: currentRoute ?? '/dashboard'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'NEW BUILD: Dashboard + Collections',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today Dashboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people_alt_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Farmers Served',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onTertiaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${servedFarmers.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onTertiaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.scale_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Total Kg Collected',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  totalKgCollected.toStringAsFixed(2),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Top 3 Highest Kgs',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (topThree.isEmpty)
                      Text(
                        'No collections recorded today.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      )
                    else
                      ...topThree.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final farmerLabel = item.farmersName.trim().isEmpty
                            ? item.farmersNumber
                            : item.farmersName;
                        final rankColor = switch (index) {
                          0 => Theme.of(context).colorScheme.tertiaryContainer,
                          1 => Theme.of(context).colorScheme.secondaryContainer,
                          _ => Theme.of(context).colorScheme.surface,
                        };
                        final rankOnColor = switch (index) {
                          0 => Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                          1 => Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          _ => Theme.of(context).colorScheme.onSurface,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: rankColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: rankOnColor,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: rankColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    farmerLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: rankOnColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${(item.kgCollected ?? 0).toStringAsFixed(2)} kg',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: rankOnColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No collections yet.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final dateTimeText = _formatDateTime(
                          item.collectionTime ?? item.collectionsDate,
                        );

                        return Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            title: Text(item.farmersName),
                            subtitle: Text(
                              '${item.farmersNumber} • ${item.coffeeType} • $dateTimeText',
                            ),
                            trailing: SizedBox(
                              width: 110,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Kg'),
                                      Text(
                                        '${item.kgCollected ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Print receipt',
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                    ),
                                    onPressed: () => _printReceipt(item),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Farmers (DB): $totalFarmersInDb',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Overall Kg Collected: ${totalOverallKgCollected.toStringAsFixed(2)}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final repository = context.read<DailyCollectionRepository>();
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddCollectionPage()),
          );
          if (!mounted) return;
          if (result == true) {
            await repository.loadCollections();
          }
        },
        tooltip: 'Add collection',
        child: const Icon(Icons.add),
      ),
    );
  }
}
