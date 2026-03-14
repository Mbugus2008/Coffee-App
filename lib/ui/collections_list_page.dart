import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/daily_collection_repository.dart';
import 'add_collection_page.dart';
import 'brand_logo.dart';

class CollectionsListPage extends StatefulWidget {
  const CollectionsListPage({super.key});

  @override
  State<CollectionsListPage> createState() => _CollectionsListPageState();
}

class _CollectionsListPageState extends State<CollectionsListPage> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DailyCollectionRepository>().loadCollections();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<DailyCollectionRepository>().items;
    final query = _filter.trim().toLowerCase();

    final filteredItems = items.where((item) {
      if (query.isEmpty) return true;
      return item.farmersName.toLowerCase().contains(query) ||
          item.farmersNumber.toLowerCase().contains(query) ||
          item.coffeeType.toLowerCase().contains(query) ||
          item.collectionNumber.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Collections'),
        leadingWidth: 96,
        leading: Builder(
          builder: (context) {
            return Row(
              children: [
                IconButton(
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
              ],
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                labelText: 'Filter collections',
                hintText: 'Farmer no, name, coffee type or collection no',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear filter',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _filterController.clear();
                          setState(() {
                            _filter = '';
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                      child: Text('No collections found for this filter.'),
                    )
                  : ListView.separated(
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
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
                            trailing: Column(
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
                          ),
                        );
                      },
                    ),
            ),
          ],
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
