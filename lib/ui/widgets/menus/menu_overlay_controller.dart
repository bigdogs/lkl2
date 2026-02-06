import 'package:flutter/widgets.dart';

class MenuOverlayController {
  static VoidCallback? _closeActiveMenu;

  static void setActive(VoidCallback closeMenu) {
    if (_closeActiveMenu != null && _closeActiveMenu != closeMenu) {
      _closeActiveMenu!.call();
    }
    _closeActiveMenu = closeMenu;
  }

  static void clearIfActive(VoidCallback closeMenu) {
    if (_closeActiveMenu == closeMenu) {
      _closeActiveMenu = null;
    }
  }
}
