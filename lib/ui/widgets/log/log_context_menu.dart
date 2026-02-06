import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

class LogContextMenu extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final bool hasSelection;

  const LogContextMenu({
    super.key,
    required this.onSelected,
    this.hasSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final items = [
      _ContextMenuItemData(
        value: 'copy_selection',
        label: '复制',
        enabled: hasSelection,
      ),
      const _ContextMenuItemData(value: 'detail', label: '详细日志'),
      const _ContextMenuItemData(value: 'copy_line', label: '复制一行'),
      const _ContextMenuItemData(value: 'copy_json', label: '复制JSON'),
    ];

    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 160),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: MacosColors.separatorColor.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: MacosColors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items
              .map(
                (item) =>
                    _ContextMenuItemRow(item: item, onSelected: onSelected),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ContextMenuItemData {
  final String value;
  final String label;
  final bool enabled;

  const _ContextMenuItemData({
    required this.value,
    required this.label,
    this.enabled = true,
  });
}

class _ContextMenuItemRow extends StatefulWidget {
  final _ContextMenuItemData item;
  final ValueChanged<String> onSelected;

  const _ContextMenuItemRow({required this.item, required this.onSelected});

  @override
  State<_ContextMenuItemRow> createState() => _ContextMenuItemRowState();
}

class _ContextMenuItemRowState extends State<_ContextMenuItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDisabled = !widget.item.enabled;

    final backgroundColor = _isHovered && !isDisabled
        ? MacosColors.systemBlueColor
        : MacosColors.transparent;

    final textColor = isDisabled
        ? MacosColors.disabledControlTextColor
        : (_isHovered
              ? MacosColors.white
              : MacosColors.labelColor.resolveFrom(context));

    return MouseRegion(
      onEnter: (_) {
        if (!isDisabled) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (!isDisabled) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDisabled ? null : () => widget.onSelected(widget.item.value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            widget.item.label,
            style: theme.typography.body.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
