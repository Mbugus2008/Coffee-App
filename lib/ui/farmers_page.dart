import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_repository.dart';
import '../data/farmer_model.dart';
import '../data/farmer_repository.dart';
import 'add_farmer_page.dart';
import 'brand_logo.dart';
import 'edit_farmer_page.dart';

class FarmersPage extends StatefulWidget {
  const FarmersPage({super.key});

  @override
  State<FarmersPage> createState() => _FarmersPageState();
}

class _FarmersPageState extends State<FarmersPage> {
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
    final farmers = context.watch<FarmerRepository>().farmers;
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

    return Scaffold(
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
      body: farmers.isEmpty
          ? const Center(child: Text('No farmers yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: farmers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final farmer = farmers[index];
                final totalKg = totalKgByFarmer[farmer.no.trim()] ?? 0;
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
                    subtitle: Text(
                      '${farmer.no} • ${farmer.phone} • ${farmer.email}',
                    ),
                    onTap: () => _openEditFarmer(farmer),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total'),
                        Text(
                          '${totalKg.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFarmer,
        tooltip: 'Add farmer',
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}
