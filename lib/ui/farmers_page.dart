import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_repository.dart';
import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import 'add_farmer_page.dart';
import 'back_button_guard.dart';
import 'brand_logo.dart';
import 'edit_farmer_page.dart';

class FarmersPage extends StatefulWidget {
  const FarmersPage({super.key});

  @override
  State<FarmersPage> createState() => _FarmersPageState();
}

class _FarmersPageState extends State<FarmersPage> with BackButtonGuard {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _subtitleFor(Farmer farmer) {
    final parts = <String>[
      farmer.no.trim(),
      farmer.phone.trim(),
      farmer.email.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(' • ');
  }

  bool _matchesSearch(Farmer farmer) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    return farmer.no.toLowerCase().contains(query) ||
        farmer.name.toLowerCase().contains(query) ||
        farmer.phone.toLowerCase().contains(query) ||
        farmer.factory.toLowerCase().contains(query);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FarmerRepository>().refreshFromServer();
    });
  }

  Future<void> _openAddFarmer() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddFarmerPage()));
    if (!mounted) return;
    if (result == true) {
      await context.read<FarmerRepository>().loadFarmers();
    }
  }

  Future<void> _openEditFarmer(Farmer farmer) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditFarmerPage(farmer: farmer)),
    );
    if (!mounted) return;
    if (result == true) {
      await context.read<FarmerRepository>().loadFarmers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmerRepo = context.watch<FarmerRepository>();
    final farmers = farmerRepo.farmers;
    final filteredFarmers = farmers.where(_matchesSearch).toList();
    final collections = context.watch<DailyCollectionRepository>().items;
    final totalKgByFarmer = <String, double>{};
    for (final collection in collections) {
      final farmerNo = collection.farmersNumber.trim();
      if (farmerNo.isEmpty) {
        continue;
      }
      final kg = collection.kgCollected ?? 0;
      totalKgByFarmer[farmerNo] = (totalKgByFarmer[farmerNo] ?? 0) + kg;
    }

    return guard(Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Farmers'),
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
            tooltip: 'Collections',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/collections');
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FarmerRepository>().refreshFromServer();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by no, name, phone, or factory',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
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
          Expanded(
            child: farmers.isEmpty
                ? const Center(child: Text('No farmers yet.'))
                : filteredFarmers.isEmpty
                ? const Center(child: Text('No matching farmers found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFarmers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final farmer = filteredFarmers[index];
                      final totalKg = totalKgByFarmer[farmer.no.trim()] ?? 0;
                      final hasPendingSync = farmer.updated == true;
                      final hasSyncFailure =
                          hasPendingSync &&
                          farmerRepo.isFarmerSyncFailed(farmer.no);
                      final badgeColor = hasSyncFailure
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.tertiaryContainer;
                      final badgeTextColor = hasSyncFailure
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onTertiaryContainer;
                      final badgeLabel = hasSyncFailure
                          ? 'Sync failed'
                          : 'Pending sync';

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
                          title: Row(
                            children: [
                              Expanded(child: Text(farmer.name)),
                              if (hasPendingSync)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: badgeTextColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(_subtitleFor(farmer)),
                          onTap: () => _openEditFarmer(farmer),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total'),
                              Text(
                                '${totalKg.toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFarmer,
        tooltip: 'Add farmer',
        child: const Icon(Icons.person_add_alt_1),
      ),
    ));
  }
}
