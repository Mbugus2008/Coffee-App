import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_repository.dart';
import '../data/farmer_repository.dart';
import 'brand_logo.dart';

class FarmerCollectionsPage extends StatefulWidget {
  const FarmerCollectionsPage({super.key});

  @override
  State<FarmerCollectionsPage> createState() => _FarmerCollectionsPageState();
}

class _FarmerCollectionsPageState extends State<FarmerCollectionsPage> {
  DateTime _selectedDate = DateTime.now();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DailyCollectionRepository>().loadCollections();
      context.read<FarmerRepository>().loadFarmers();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _query);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter farmers'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Farmer number or name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) return;
    setState(() {
      _query = value.trim();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = DateTime.now();
      _query = '';
    });
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day-$month-$year';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final farmers = context.watch<FarmerRepository>().farmers;
    final collections = context.watch<DailyCollectionRepository>().items;

    final totalsByFarmer = <String, double>{};
    final transactionsByFarmer = <String, int>{};

    for (final item in collections) {
      final timestamp = item.collectionTime ?? item.collectionsDate;
      if (!_isSameDate(timestamp, _selectedDate)) {
        continue;
      }
      final farmerNo = item.farmersNumber.trim();
      if (farmerNo.isEmpty) {
        continue;
      }
      totalsByFarmer[farmerNo] =
          (totalsByFarmer[farmerNo] ?? 0) + (item.kgCollected ?? 0);
      transactionsByFarmer[farmerNo] =
          (transactionsByFarmer[farmerNo] ?? 0) + 1;
    }

    final query = _query.toLowerCase();
    final filteredFarmers = farmers.where((farmer) {
      if (query.isEmpty) return true;
      return farmer.no.toLowerCase().contains(query) ||
          farmer.name.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: BrandedAppBarTitle(
          'Farmer Collections • ${_formatDate(_selectedDate)}',
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/dashboard');
            },
          ),
          IconButton(
            tooltip: 'Filter date',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: 'Filter farmer',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Clear filters',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: filteredFarmers.isEmpty
          ? const Center(child: Text('No farmers found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredFarmers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final farmer = filteredFarmers[index];
                final farmerNo = farmer.no.trim();
                final total = totalsByFarmer[farmerNo] ?? 0;
                final txnCount = transactionsByFarmer[farmerNo] ?? 0;

                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        farmer.name.isNotEmpty
                            ? farmer.name.substring(0, 1).toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(farmer.name),
                    subtitle: Text('${farmer.no} • Txn: $txnCount'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Daily Total'),
                        Text(
                          '${total.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
