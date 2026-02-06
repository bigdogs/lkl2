import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/ui/widgets/menus/menu_data.dart';
import 'package:lkl2/ui/widgets/menus/macos_menu_group.dart';

export 'package:lkl2/ui/widgets/menus/menu_data.dart';

class AppMenuBuilder {
  static List<PlatformMenu> buildPlatformMenus(List<MenuGroupData> menus) {
    return menus.map((group) {
      return PlatformMenu(
        label: group.label,
        menus: group.items.map((item) {
          return PlatformMenuItem(
            label: item.label,
            shortcut: item.shortcut,
            onSelected: item.onSelected,
          );
        }).toList(),
      );
    }).toList();
  }

  static Widget buildMenuBar(List<MenuGroupData> menus) {
    return MacosMenuBar(menus: menus);
  }
}

class MacosMenuBar extends StatelessWidget {
  final List<MenuGroupData> menus;
  final double height;

  const MacosMenuBar({super.key, required this.menus, this.height = 28});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: theme.canvasColor),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: menus
            .map(
              (group) => MacosMenuGroup(
                label: group.label,
                items: group.items,
                barHeight: height,
              ),
            )
            .toList(),
      ),
    );
  }
}
