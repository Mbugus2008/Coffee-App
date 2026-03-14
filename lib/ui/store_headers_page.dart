import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'add_store_header_page.dart';
import 'app_drawer.dart' as app_drawer;
import 'brand_logo.dart';
import 'store_lines_page.dart';

class StoreHeadersPage extends StatefulWidget {
  const StoreHeadersPage({super.key});

  @override
  State<StoreHeadersPage> createState() => _StoreHeadersPageState();
}

class _StoreHeadersPageState extends State<StoreHeadersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreRepository>().loadStoreHeaders();
    });
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

  Future<void> _openStoreLines(StoreHeader header) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoreLinesPage(header: header)));

    if (!mounted) return;
    await context.read<StoreRepository>().loadStoreHeaders();
  }

  Future<void> _openStoreHeaderCard(StoreHeader header) async {
    final shouldOpenLines = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Store Header'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Farmer: ${header.client}'),
              const SizedBox(height: 6),
              Text('Entry: ${header.entry}'),
              const SizedBox(height: 6),
              Text('Date: ${_formatDate(header.date)}'),
              const SizedBox(height: 6),
              Text('Factory: ${header.factory}'),
              const SizedBox(height: 6),
              Text('Total: ${(header.total ?? 0).toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Lines'),
            ),
          ],
        );
      },
    );

    if (shouldOpenLines == true) {
      await _openStoreLines(header);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    final headers = context.watch<StoreRepository>().headers;
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentRoute = routeName == '/' ? '/dashboard' : routeName;

    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('Store Headers'),
        actions: [
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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: headers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final header = headers[index];
                return _StoreHeaderCard(
                  header: header,
                  formatDate: _formatDate,
                  onTap: () => _openStoreHeaderCard(header),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddStoreHeader,
        tooltip: 'Add store header',
        child: const Icon(Icons.add_shopping_cart_outlined),
      ),
    );
  }
}

class _StoreHeaderCard extends StatelessWidget {
  const _StoreHeaderCard({
    required this.header,
    required this.formatDate,
    required this.onTap,
  });

  final StoreHeader header;
  final String Function(DateTime?) formatDate;
  final VoidCallback onTap;

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
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            header.client.isNotEmpty
                ? header.client.substring(0, 1).toUpperCase()
                : '?',
          ),
        ),
        title: Text(header.client),
        subtitle: Text(
          '${header.entry} • ${formatDate(header.date)} • ${header.factory}',
        ),
        onTap: onTap,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Total'),
            Text(
              (header.total ?? 0).toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
