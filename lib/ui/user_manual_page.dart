import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'brand_logo.dart';

class UserManualPage extends StatefulWidget {
  const UserManualPage({super.key});

  @override
  State<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  late final Future<String> _manualFuture;

  @override
  void initState() {
    super.initState();
    _manualFuture = rootBundle.loadString('USER_MANUAL.md');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedAppBarTitle('User Manual'),
        actions: [
          IconButton(
            tooltip: 'Back to dashboard',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _manualFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the user manual.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final manual = snapshot.data!;
          final contents = _extractTableOfContents(manual);

          return Column(
            children: [
              if (contents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Table of Contents',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...contents.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(item),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Markdown(
                  data: manual,
                  padding: const EdgeInsets.all(16),
                  selectable: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _extractTableOfContents(String manual) {
    final lines = manual.split('\n');
    final contents = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('## ')) {
        continue;
      }
      if (trimmed == '## Table of Contents') {
        continue;
      }
      contents.add(trimmed.substring(3));
    }
    return contents;
  }
}
