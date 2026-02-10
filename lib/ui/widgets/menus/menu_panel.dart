import 'package:flutter/widgets.dart';
import 'package:lkl2/ui/widgets/macos_overlay_container.dart';
import 'package:lkl2/ui/widgets/menus/menu_data.dart';
import 'package:lkl2/ui/widgets/menus/menu_item_row.dart';

class MenuPanel extends StatelessWidget {
  final List<MenuItemData> items;
  final VoidCallback onClose;

  const MenuPanel({super.key, required this.items, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: MacosOverlayContainer(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items
              .map((item) => MenuItemRow(item: item, onClose: onClose))
              .toList(),
        ),
      ),
    );
  }
}
