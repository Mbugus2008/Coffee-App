import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_model.dart';
import '../data/daily_collection_repository.dart';
import '../data/farmer_repository.dart';
import '../services/bluetooth_printer_service.dart';
import 'add_collection_page.dart';
import 'app_drawer.dart' as app_drawer;
import 'brand_logo.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      context.read<DailyCollectionRepository>().loadCollections(),
      context.read<FarmerRepository>().loadFarmers(),
    ]);
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
      showDragHandle: true,
      builder: (context) {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.print_outlined),
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to ${selected.name}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Printer connect failed: $error')));
    }
  }

  Future<void> _printReceipt(DailyCollection item) async {
    var connected = await BluetoothPrinterService.instance.isConnected();
    if (!connected) {
      connected = await BluetoothPrinterService.instance.connectAttachedPrinter();
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

  Future<void> _openAddCollection() async {
    final repository = context.read<DailyCollectionRepository>();
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddCollectionPage()));
    if (!mounted) return;
    if (result == true) {
      await repository.loadCollections();
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _timestamp(DailyCollection item) {
    return item.collectionTime ?? item.collectionsDate;
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allItems = context.watch<DailyCollectionRepository>().items;
    final totalFarmers = context.watch<FarmerRepository>().farmers.length;
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentRoute = routeName == '/' ? '/dashboard' : routeName;
    final now = DateTime.now();

    final todayItems = allItems.where((item) => _isSameDate(_timestamp(item), now)).toList()
      ..sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));
    final recentItems = [...allItems]
      ..sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));

    final servedFarmers = <String>{};
    var totalKgToday = 0.0;
    for (final item in todayItems) {
      if (item.farmersNumber.trim().isNotEmpty) {
        servedFarmers.add(item.farmersNumber.trim());
      }
      totalKgToday += item.kgCollected ?? 0;
    }

    final topItem = todayItems.isEmpty
        ? null
        : ([...todayItems]..sort((a, b) => (b.kgCollected ?? 0).compareTo(a.kgCollected ?? 0))).first;

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Collections',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/collections'),
          ),
          IconButton(
            tooltip: 'Printer',
            icon: const Icon(Icons.print_outlined),
            onPressed: _selectPrinter,
          ),
        ],
      ),
      drawer: app_drawer.AppDrawer(currentRoute: currentRoute ?? '/dashboard'),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openAddCollection,
        tooltip: 'Add collection',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 72),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const CoffeeBeanLogo(size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today overview',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            todayItems.isEmpty
                                ? 'No collections recorded yet.'
                                : '${todayItems.length} collections • ${servedFarmers.length} farmers served',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onPrimaryContainer.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _refreshDashboard,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Today kg',
                      value: totalKgToday.toStringAsFixed(1),
                      icon: Icons.scale_outlined,
                      color: colors.secondaryContainer,
                      foreground: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'Farmers',
                      value: '${servedFarmers.length}',
                      icon: Icons.people_alt_outlined,
                      color: colors.tertiaryContainer,
                      foreground: colors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'In DB',
                      value: '$totalFarmers',
                      icon: Icons.groups_2_outlined,
                      color: colors.surfaceContainerHighest,
                      foreground: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'Top kg',
                      value: topItem == null
                          ? '0.0'
                          : (topItem.kgCollected ?? 0).toStringAsFixed(1),
                      icon: Icons.emoji_events_outlined,
                      color: colors.primaryContainer,
                      foreground: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openAddCollection,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('New'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/collections'),
                      icon: const Icon(Icons.list_alt_outlined, size: 16),
                      label: const Text('List'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectPrinter,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent collections',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${recentItems.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshDashboard,
                          child: recentItems.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: 140,
                                      child: Center(
                                        child: Text(
                                          'No collections yet.',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: recentItems.length > 4 ? 4 : recentItems.length,
                                  itemBuilder: (context, index) {
                                    final item = recentItems[index];
                                    return _CompactCollectionTile(
                                      item: item,
                                      timestamp: _formatDate(_timestamp(item)),
                                      onPrint: () => _printReceipt(item),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.foreground,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground.withAlpha(220),
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCollectionTile extends StatelessWidget {
  const _CompactCollectionTile({
    required this.item,
    required this.timestamp,
    required this.onPrint,
  });

  final DailyCollection item;
  final String timestamp;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final farmerName = item.farmersName.trim().isEmpty ? item.farmersNumber : item.farmersName;
    final coffeeType = item.coffeTypeName.trim().isEmpty ? item.coffeeType : item.coffeTypeName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: colors.primaryContainer,
            child: Text(
              '${(item.kgCollected ?? 0).toStringAsFixed(0)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            farmerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '$coffeeType • $timestamp',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Print receipt',
            onPressed: onPrint,
            icon: const Icon(Icons.receipt_long_outlined, size: 20),
          ),
        ),
      ),
    );
  }
}
