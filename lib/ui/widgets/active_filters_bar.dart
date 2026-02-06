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
        runSpacing: 8,
        children: filters.map((filter) {
          return _FilterChip(
            field: filter.field,
            value: filter.value,
            onDeleted: () => provider.removeFilter(filter),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String field;
  final String value;
  final VoidCallback onDeleted;

  const _FilterChip({
    required this.field,
    required this.value,
    required this.onDeleted,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);

    // Determine colors
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = _isHovered
        ? (isDark ? const Color(0xFF505050) : const Color(0xFFE5E5E5))
        : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0));

    final borderColor = _isHovered
        ? MacosColors.systemGrayColor.withValues(alpha: 0.5)
        : MacosColors.separatorColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Field Name
            Text(
              "${widget.field}:",
              style: theme.typography.caption1.copyWith(
                color: MacosColors.secondaryLabelColor.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            // Value
            Text(
              widget.value,
              style: theme.typography.caption1.copyWith(
                color: MacosColors.labelColor.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 8),
            // Delete Action
            GestureDetector(
              onTap: widget.onDeleted,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: MacosIcon(
                  CupertinoIcons.xmark,
                  size: 13,
                  color: _isHovered
                      ? MacosColors.labelColor.resolveFrom(context)
                      : MacosColors.tertiaryLabelColor.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
