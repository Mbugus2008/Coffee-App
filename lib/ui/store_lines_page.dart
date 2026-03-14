import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'add_store_line_page.dart';
import 'brand_logo.dart';

class StoreLinesPage extends StatefulWidget {
  const StoreLinesPage({super.key, required this.header});

  final StoreHeader header;

  @override
  State<StoreLinesPage> createState() => _StoreLinesPageState();
}

class _StoreLinesPageState extends State<StoreLinesPage> {
  List<Store> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lines = await context.read<StoreRepository>().loadStoreLines(
      widget.header.entry,
    );
    if (!mounted) return;
    setState(() {
      _lines = lines;
      _loading = false;
    });
  }

  Future<void> _openAddLine() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddStoreLinePage(
          entry: widget.header.entry,
          client: widget.header.client,
          factory: widget.header.factory,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      await _load();
    }
  }

  String _fmt(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BrandedAppBarTitle('Store: ${widget.header.entry}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
          ? const Center(child: Text('No store lines yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final line = _lines[index];
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
                    title: Text(line.item),
                    subtitle: Text(
                      '${line.variant} • Qty ${(line.quantity ?? 0).toStringAsFixed(2)} • ${_fmt(line.date)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Line Total'),
                        Text(
                          (line.lineTotal ?? 0).toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddLine,
        tooltip: 'Add store line',
        child: const Icon(Icons.playlist_add_outlined),
      ),
    );
  }
}
