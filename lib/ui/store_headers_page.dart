import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../services/bluetooth_printer_service.dart';
import 'add_store_header_page.dart';
import 'app_drawer.dart' as app_drawer;
import 'back_button_guard.dart';
import 'brand_logo.dart';

class StoreHeadersPage extends StatefulWidget {
  const StoreHeadersPage({super.key});

  @override
  State<StoreHeadersPage> createState() => _StoreHeadersPageState();
}

class _StoreHeadersPageState extends State<StoreHeadersPage> with BackButtonGuard {
  String? _expandedDateKey;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedPaymodeFilter;
  bool _isSyncingToBc = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreRepository>().loadStoreHeaders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime? value) {
    if (value == null) return 'Unknown Date';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$year-$month-$day|$day-$month-$year';
  }

  String _displayDate(String key) {
    final parts = key.split('|');
    if (parts.length < 2) return key;
    return parts[1];
  }

  String _formatAmount(num? value, {int decimalPlaces = 2}) {
    final fixed = (value ?? 0).toStringAsFixed(decimalPlaces);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    if (parts.length == 1) return whole;
    return '$whole.${parts[1]}';
  }

  String _paymodeLabel(int? paymode) {
    if (paymode == 1) return 'Credit';
    if (paymode == 0) return 'Cash';
    return '-';
  }

  List<StoreHeader> _applyFilters(List<StoreHeader> headers) {
    final query = _searchQuery.trim().toLowerCase();

    return headers.where((header) {
      if (_selectedPaymodeFilter != null &&
          header.paymode != _selectedPaymodeFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final farmerNo = header.client.toLowerCase();
      final farmerName = header.memberName.toLowerCase();
      final entry = header.entry.toLowerCase();
      final paymode = _paymodeLabel(header.paymode).toLowerCase();

      return farmerNo.contains(query) ||
          farmerName.contains(query) ||
          entry.contains(query) ||
          paymode.contains(query);
    }).toList();
  }

  List<MapEntry<String, List<StoreHeader>>> _groupByDate(
    List<StoreHeader> headers,
  ) {
    final sorted = [...headers]
      ..sort((a, b) {
        final ad = a.date;
        final bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        final dateCmp = _dateOnly(bd).compareTo(_dateOnly(ad));
        if (dateCmp != 0) return dateCmp;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

    final grouped = <String, List<StoreHeader>>{};
    for (final header in sorted) {
      final key = _dateKey(header.date);
      grouped.putIfAbsent(key, () => <StoreHeader>[]).add(header);
    }

    return grouped.entries.toList();
  }

  Future<void> _openAddStoreHeader() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddStoreHeaderPage()));

    if (!mounted) return;
    if (result == true) {
      await context.read<StoreRepository>().loadStoreHeaders();
    }
  }

  Future<void> _openEditStoreHeader(StoreHeader header) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddStoreHeaderPage(initialHeader: header),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      await context.read<StoreRepository>().loadStoreHeaders();
    }
  }

  Future<void> _reprintStoreReceipt(StoreHeader header) async {
    final repo = context.read<StoreRepository>();
    final lines = await repo.loadStoreLines(header.entry);

    if (!mounted) return;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lines found for this store header.')),
      );
      return;
    }

    try {
      var connected = await BluetoothPrinterService.instance
          .isAttachedPrinterConnected();
      if (!connected) {
        connected = await BluetoothPrinterService.instance
            .connectAttachedPrinter();
      }

      if (!connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attach a printer to reprint the stores receipt.'),
          ),
        );
        return;
      }

      await BluetoothPrinterService.instance.printStoresReceipt(header, lines);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stores receipt reprinted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reprint stores receipt.')),
      );
    }
  }

  Future<void> _syncToBc() async {
    if (_isSyncingToBc) return;

    setState(() {
      _isSyncingToBc = true;
    });

    final result = await context.read<StoreRepository>().syncWithBc();

    if (!mounted) return;
    setState(() {
      _isSyncingToBc = false;
    });

    var message = 'No pending stores to sync.';
    if (result.attempted > 0) {
      message = 'Synced ${result.synced}/${result.attempted} store records.';
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
          title: const Text('Store Sync Errors'),
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

  @override
  Widget build(BuildContext context) {
    final headers = context.watch<StoreRepository>().headers;
    final filteredHeaders = _applyFilters(headers);
    final pendingHeaders =
        filteredHeaders.where((header) => header.posted != true).toList()
          ..sort((a, b) {
            final ad = a.date;
            final bd = b.date;
            if (ad == null && bd == null)
              return (b.id ?? 0).compareTo(a.id ?? 0);
            if (ad == null) return 1;
            if (bd == null) return -1;
            final dateCmp = bd.compareTo(ad);
            if (dateCmp != 0) return dateCmp;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });

    final recentGroups = _groupByDate(
      filteredHeaders.where((header) => header.posted == true).toList(),
    );
    if (_expandedDateKey == null && recentGroups.isNotEmpty) {
      _expandedDateKey = recentGroups.first.key;
    }
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentRoute = routeName == '/' ? '/dashboard' : routeName;

    return guard(Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Store Headers'),
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
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<StoreRepository>().loadStoreHeaders();
            },
          ),
        ],
      ),
      drawer: app_drawer.AppDrawer(currentRoute: currentRoute ?? '/stores'),
      body: headers.isEmpty
          ? const Center(child: Text('No store headers yet.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search headers',
                          hintText: 'Farmer no, name, entry, or paymode',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedPaymodeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by paymode',
                        ),
                        items: const [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All'),
                          ),
                          DropdownMenuItem<int?>(value: 0, child: Text('Cash')),
                          DropdownMenuItem<int?>(
                            value: 1,
                            child: Text('Credit'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymodeFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (filteredHeaders.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No store headers match your filters.'),
                    ),
                  ),
                if (filteredHeaders.isEmpty) const SizedBox(height: 5),
                Text(
                  'Pending Stores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                if (pendingHeaders.isEmpty)
                  const Card(child: ListTile(title: Text('No pending stores.')))
                else
                  ...pendingHeaders.map(
                    (header) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _StoreHeaderCard(
                        header: header,
                        onTap: () => _openEditStoreHeader(header),
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  'Recent Stores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                if (recentGroups.isEmpty)
                  const Card(
                    child: ListTile(title: Text('No recent posted stores.')),
                  )
                else
                  ...recentGroups.map((group) {
                    final groupHeaders = group.value;
                    final totalAmount = groupHeaders.fold<double>(
                      0,
                      (sum, item) => sum + (item.total ?? 0),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ExpansionTile(
                          key: PageStorageKey<String>(
                            'store_date_group_${group.key}',
                          ),
                          initiallyExpanded: _expandedDateKey == group.key,
                          onExpansionChanged: (expanded) {
                            if (!expanded) return;
                            setState(() {
                              _expandedDateKey = group.key;
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _displayDate(group.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _formatAmount(totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            for (final header in groupHeaders)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                                child: _StoreHeaderCard(
                                  header: header,
                                  onTap: null,
                                  onReprint: () => _reprintStoreReceipt(header),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddStoreHeader,
        tooltip: 'Add store header',
        child: const Icon(Icons.add_shopping_cart_outlined),
      ),
    ));
  }
}

class _StoreHeaderCard extends StatelessWidget {
  const _StoreHeaderCard({
    required this.header,
    required this.onTap,
    this.onReprint,
  });

  final StoreHeader header;
  final VoidCallback? onTap;
  final VoidCallback? onReprint;

  String _paymodeLabel(int? paymode) {
    if (paymode == 1) return 'Credit';
    if (paymode == 0) return 'Cash';
    return '-';
  }

  String _formatAmount(num? value, {int decimalPlaces = 2}) {
    final fixed = (value ?? 0).toStringAsFixed(decimalPlaces);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    if (parts.length == 1) return whole;
    return '$whole.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          '${header.client}   ${header.memberName}',
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '${header.itemCount ?? 0}(items)|${_paymodeLabel(header.paymode)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatAmount(header.total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        trailing: onReprint == null
            ? null
            : IconButton(
                tooltip: 'Reprint receipt',
                onPressed: onReprint,
                icon: const Icon(Icons.print_outlined),
              ),
        onTap: onTap,
      ),
    );
  }
}
