import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_list.dart';

class BottomArea extends StatelessWidget {
  const BottomArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "SQL Filter (e.g. eventName='Error')",
                    prefixIcon: Icon(Icons.filter_list),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) => provider.setFilter(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search logs (Full Text)...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) => provider.search(value),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // Results
        if (provider.searchError != null)
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              "Search Error: ${provider.searchError}",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: provider.isSearching
              ? const Center(child: CircularProgressIndicator())
              : LogList(logs: provider.searchResults),
        ),
        if (provider.searchResults.isEmpty &&
            !provider.isSearching &&
            provider.searchError == null)
          Container(
            padding: const EdgeInsets.all(4),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: const Text("0 match found", style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
