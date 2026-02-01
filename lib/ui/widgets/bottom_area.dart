import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_list.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';

class BottomArea extends StatefulWidget {
  const BottomArea({super.key});

  @override
  State<BottomArea> createState() => _BottomAreaState();
}

class _BottomAreaState extends State<BottomArea> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedField;
  FilterMode _selectedMode = FilterMode.contains;

  List<String> _fields = [];
  bool _isLoadingFields = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final engine = await LogRenderEngine.shared;
    if (mounted) {
      setState(() {
        _fields = engine.config.fields;
        if (_fields.isNotEmpty) {
          _selectedField = _fields.first;
        }
        _isLoadingFields = false;
      });
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addFilter(LogProvider provider) {
    if (_valueController.text.isEmpty || _selectedField == null) return;

    provider.addFilter(
      FilterCondition(
        field: _selectedField!,
        mode: _selectedMode,
        value: _valueController.text,
      ),
    );
    _valueController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Control Panel
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
            color: colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Combined Filter & Search Row
              Row(
                children: [
                  // Field Selector
                  SizedBox(
                    width: 140,
                    child: _isLoadingFields
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedField,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Field',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            items: _fields
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedField = v!),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Mode Selector
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<FilterMode>(
                      value: _selectedMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Mode',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      items: FilterMode.values
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedMode = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Value Input
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        hintText: 'Filter value...',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _addFilter(provider),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    onPressed: () => _addFilter(provider),
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: "Add Filter Condition",
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),

                  // Divider
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(width: 12),

                  // Search Input
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search logs (Full Text)...",
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (value) => provider.search(value),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Actions
                  IconButton.outlined(
                    onPressed: () {
                      provider.clearFilters();
                      _searchController.clear();
                      provider.search("");
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: "Reset",
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: () {
                      provider.applyFilters();
                      // Also apply current search text if changed but not submitted
                      if (_searchController.text != provider.lastSearchQuery) {
                        provider.search(_searchController.text);
                      }
                    },
                    icon: const Icon(Icons.filter_list, size: 18),
                    tooltip: "Filter",
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              // Row 2: Active Filters (Chips)
              if (provider.filters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: provider.filters.map((filter) {
                      return InputChip(
                        label: Text(
                          "${filter.field} ${filter.mode == FilterMode.equals ? '=' : 'contains'} '${filter.value}'",
                        ),
                        onDeleted: () => provider.removeFilter(filter),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        backgroundColor: colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        // Search/Filter Error
        if (provider.searchError != null)
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: colorScheme.errorContainer,
            child: Text(
              "Error: ${provider.searchError}",
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),

        // Results List
        Expanded(
          child: provider.isSearching
              ? const Center(child: CircularProgressIndicator())
              : LogList(logs: provider.searchResults),
        ),

        // Footer Status
        if (provider.searchResults.isEmpty &&
            !provider.isSearching &&
            provider.searchError == null)
          Container(
            padding: const EdgeInsets.all(4),
            width: double.infinity,
            color: colorScheme.surfaceContainer,
            child: const Text("0 match found", style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
