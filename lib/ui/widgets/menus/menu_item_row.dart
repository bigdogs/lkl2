import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/ui/widgets/menus/menu_data.dart';

class MenuItemRow extends StatefulWidget {
  final MenuItemData item;
  final VoidCallback onClose;

  const MenuItemRow({super.key, required this.item, required this.onClose});

  @override
  State<MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<MenuItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final shortcutLabel = _formatShortcut(widget.item.shortcut);

    final backgroundColor =
        _isHovered ? MacosColors.systemBlueColor : MacosColors.transparent;

    final textColor =
        _isHovered
            ? MacosColors.white
            : MacosColors.labelColor.resolveFrom(context);

    final shortcutColor =
        _isHovered
            ? MacosColors.white.withOpacity(0.9)
            : MacosColors.secondaryLabelColor.resolveFrom(context);

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.item.onSelected();
          widget.onClose();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.item.label,
                style: theme.typography.body.copyWith(color: textColor),
              ),
              if (shortcutLabel != null) ...[
                const SizedBox(width: 16),
                Text(
                  shortcutLabel,
                  style: theme.typography.caption1.copyWith(
                    color: shortcutColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _formatShortcut(SingleActivator? shortcut) {
    if (shortcut == null) {
      return null;
    }
    final parts = <String>[];
    if (shortcut.meta) {
      parts.add('⌘');
    }
    if (shortcut.control) {
      parts.add('⌃');
    }
    if (shortcut.alt) {
      parts.add('⌥');
    }
    if (shortcut.shift) {
      parts.add('⇧');
    }
    final keyLabel =
        shortcut.trigger.keyLabel.isNotEmpty
            ? shortcut.trigger.keyLabel
            : shortcut.trigger.debugName ?? '';
    if (keyLabel.isEmpty) {
      return parts.isEmpty ? null : parts.join();
    }
    parts.add(keyLabel.toUpperCase());
    return parts.join();
  }
}
