import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_repository.dart';
import 'brand_logo.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreRepository>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<StoreRepository>().items;

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Items'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<StoreRepository>().loadItems();
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No items found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
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
                    title: Text('${item.no} • ${item.description}'),
                    subtitle: Text(
                      '${item.baseUnitOfMeasure} • Inventory ${(item.inventory ?? 0).toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      (item.unitPrice ?? 0).toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
