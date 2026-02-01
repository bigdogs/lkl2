import 'package:flutter/material.dart';

class MenuItemData {
  final String label;
  final VoidCallback onSelected;
  final SingleActivator? shortcut;

  const MenuItemData({
    required this.label,
    required this.onSelected,
    this.shortcut,
  });
}

class MenuGroupData {
  final String label;
  final List<MenuItemData> items;

  const MenuGroupData({required this.label, required this.items});
}

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

  static MenuBar buildMenuBar(List<MenuGroupData> menus) {
    return MenuBar(
      children: menus.map((group) {
        return SubmenuButton(
          menuChildren: group.items.map((item) {
            return MenuItemButton(
              onPressed: item.onSelected,
              shortcut: item.shortcut,
              child: Text(item.label),
            );
          }).toList(),
          child: Text(group.label),
        );
      }).toList(),
    );
  }
}
