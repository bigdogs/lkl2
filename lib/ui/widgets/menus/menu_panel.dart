import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/ui/widgets/menus/menu_data.dart';
import 'package:lkl2/ui/widgets/menus/menu_item_row.dart';

class MenuPanel extends StatelessWidget {
  final List<MenuItemData> items;
  final VoidCallback onClose;

  const MenuPanel({super.key, required this.items, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
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
          children:
              items
                  .map((item) => MenuItemRow(item: item, onClose: onClose))
                  .toList(),
        ),
      ),
    );
  }
}
