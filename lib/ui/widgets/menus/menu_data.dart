import 'package:flutter/widgets.dart';

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
