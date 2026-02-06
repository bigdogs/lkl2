import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_list.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';
import 'package:lkl2/ui/widgets/active_filters_bar.dart';

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
    final theme = MacosTheme.of(context);

    return Column(
      children: [
        // Control Panel
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MacosColors.systemBlueColor.withValues(alpha: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Combined Filter & Search Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Field Selector
                  SizedBox(
                    width: 140,
                    child: _isLoadingFields
                        ? const Center(child: ProgressCircle())
                        : MacosPopupButton<String>(
                            value: _selectedField,
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedField = newValue;
                              });
                            },
                            items: _fields.map<MacosPopupMenuItem<String>>((
                              String value,
                            ) {
                              return MacosPopupMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Mode Selector
                  SizedBox(
                    width: 120,
                    child: MacosPopupButton<FilterMode>(
                      value: _selectedMode,
                      onChanged: (FilterMode? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedMode = newValue;
                          });
                        }
                      },
                      items: FilterMode.values
                          .map<MacosPopupMenuItem<FilterMode>>((
                            FilterMode value,
                          ) {
                            return MacosPopupMenuItem<FilterMode>(
                              value: value,
                              child: Text(value.label),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Value Input
                  Expanded(
                    flex: 2,
                    child: MacosTextField(
                      controller: _valueController,
                      placeholder: 'Value',
                      onSubmitted: (_) => _addFilter(provider),
                    ),
                  ),
                  const SizedBox(width: 4),
                  MacosIconButton(
                    icon: const MacosIcon(
                      CupertinoIcons.plus_circle,
                      color: MacosColors.systemBlueColor,
                    ),
                    onPressed: () => _addFilter(provider),
                  ),

                  // Divider
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: MacosColors.separatorColor,
                  ),
                  const SizedBox(width: 12),

                  // Search Input
                  Expanded(
                    flex: 3,
                    child: MacosSearchField(
                      controller: _searchController,
                      placeholder: 'Search logs (Full Text)...',
                      onChanged: (value) => provider.search(value),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Actions
                  MacosIconButton(
                    icon: const MacosIcon(
                      CupertinoIcons.refresh,
                      color: MacosColors.systemBlueColor,
                    ),
                    onPressed: () {
                      provider.applyFilters();
                      provider.search(_searchController.text);
                    },
                  ),
                  const SizedBox(width: 4),
                  MacosIconButton(
                    icon: const MacosIcon(
                      CupertinoIcons.delete,
                      color: MacosColors.systemRedColor,
                    ),
                    onPressed: () {
                      provider.clearFilters();
                      _searchController.clear();
                      provider.search("");
                    },
                  ),
                ],
              ),

              // Row 2: Active Filters (Chips)
              const ActiveFiltersBar(),
            ],
          ),
        ),

        // Search/Filter Error
        if (provider.searchError != null)
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: MacosColors.systemRedColor.withValues(alpha: 0.1),
            child: Text(
              "Error: ${provider.searchError}",
              style: const TextStyle(color: MacosColors.systemRedColor),
            ),
          ),

        // Results List
        if (provider.filters.isNotEmpty || provider.lastSearchQuery.isNotEmpty)
          Expanded(
            child: provider.isSearching
                ? const Center(child: ProgressCircle())
                : LogList(logs: provider.searchResults),
          )
        else
          const Spacer(),

        // Footer Status
        if (provider.searchResults.isEmpty &&
            (provider.filters.isNotEmpty ||
                provider.lastSearchQuery.isNotEmpty))
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "No logs found matching criteria",
              style: TextStyle(color: theme.typography.body.color),
            ),
          ),
      ],
    );
  }
}
