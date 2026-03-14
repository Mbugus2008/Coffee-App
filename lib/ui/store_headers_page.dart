import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'add_store_header_page.dart';
import 'brand_logo.dart';
import 'store_lines_page.dart';

class StoreHeadersPage extends StatefulWidget {
  const StoreHeadersPage({super.key});

  @override
  State<StoreHeadersPage> createState() => _StoreHeadersPageState();
}

class _StoreHeadersPageState extends State<StoreHeadersPage> {
  double? _toDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

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
    final repository = context.read<StoreRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final clientController = TextEditingController(text: header.client);
    final factoryController = TextEditingController(text: header.factory);
    final totalController = TextEditingController(
      text: (header.total ?? 0).toStringAsFixed(2),
    );
    final commentsController = TextEditingController(text: header.comments);
    final formKey = GlobalKey<FormState>();

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Store Header'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entry: ${header.entry}'),
                  const SizedBox(height: 6),
                  Text('Date: ${_formatDate(header.date)}'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: clientController,
                    decoration: const InputDecoration(labelText: 'Farmer'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter farmer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: factoryController,
                    decoration: const InputDecoration(labelText: 'Factory'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter factory';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Total'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter total';
                      }
                      if (_toDouble(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: commentsController,
                    decoration: const InputDecoration(labelText: 'Comments'),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('close'),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('lines'),
              child: const Text('Open Lines'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                Navigator.of(dialogContext).pop('save');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (action == 'save') {
      final newTotal = _toDouble(totalController.text) ?? header.total;
      final amountPaid = header.amountPaid;
      final updated = header.copyWith(
        client: clientController.text.trim(),
        memberName: clientController.text.trim(),
        factory: factoryController.text.trim(),
        factoryName: factoryController.text.trim(),
        total: newTotal,
        comments: commentsController.text.trim(),
        balance: newTotal == null
            ? header.balance
            : (newTotal - (amountPaid ?? 0)),
      );
      await repository.updateStoreHeader(updated);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Store header updated.')),
      );
      return;
    }

    if (action == 'lines') {
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
