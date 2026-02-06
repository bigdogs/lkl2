import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';

class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final filters = provider.filters;

    if (filters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: filters.map((filter) {
          return _FilterChip(
            label:
                "${filter.field} ${filter.mode == FilterMode.equals ? '=' : 'contains'} '${filter.value}'",
            onDeleted: () => provider.removeFilter(filter),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({required this.label, required this.onDeleted});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use a color that stands out slightly but remains subtle
    final backgroundColor = _isHovered
        ? MacosColors.systemGrayColor.withValues(alpha: 0.25)
        : MacosColors.controlColor;

    final borderColor = _isHovered
        ? MacosColors.systemGrayColor.withValues(alpha: 0.5)
        : MacosColors.separatorColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: theme.typography.body.copyWith(
                fontSize: 11, // Smaller font as requested
                color: theme.typography.body.color,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onDeleted,
              child: MacosIcon(
                CupertinoIcons.xmark,
                size: 12, // Smaller icon
                color: _isHovered
                    ? MacosColors.systemRedColor
                    : MacosColors.secondaryLabelColor.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
