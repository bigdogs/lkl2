import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

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
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: const Border(
          bottom: BorderSide(color: MacosColors.separatorColor),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: menus
            .map(
              (group) => _MacosMenuGroup(
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

class _MenuOverlayController {
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

class _MacosMenuGroup extends StatefulWidget {
  final String label;
  final List<MenuItemData> items;
  final double barHeight;

  const _MacosMenuGroup({
    required this.label,
    required this.items,
    required this.barHeight,
  });

  @override
  State<_MacosMenuGroup> createState() => _MacosMenuGroupState();
}

class _MacosMenuGroupState extends State<_MacosMenuGroup> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHovered = false;
  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _MenuOverlayController.clearIfActive(_closeMenu);
  }

  void _openMenu() {
    if (_overlayEntry != null) {
      return;
    }
    _MenuOverlayController.setActive(_closeMenu);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _closeMenu,
                behavior: HitTestBehavior.translucent,
              ),
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                offset: Offset(0, widget.barHeight),
                child: _MenuPanel(items: widget.items, onClose: _closeMenu),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _closeMenu() {
    if (_overlayEntry == null) {
      return;
    }
    _removeOverlay();
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isActive = _isHovered || _isOpen;
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
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
          onTap: _toggleMenu,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? MacosColors.systemBlueColor.withValues(alpha: 0.18)
                  : MacosColors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: theme.typography.body.copyWith(
                color: MacosColors.labelColor.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  final List<MenuItemData> items;
  final VoidCallback onClose;

  const _MenuPanel({required this.items, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosColors.separatorColor),
        boxShadow: const [
          BoxShadow(
            color: MacosColors.systemGrayColor,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => _MenuItemRow(item: item, onClose: onClose))
            .toList(),
      ),
    );
  }
}

class _MenuItemRow extends StatefulWidget {
  final MenuItemData item;
  final VoidCallback onClose;

  const _MenuItemRow({required this.item, required this.onClose});

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final shortcutLabel = _formatShortcut(widget.item.shortcut);
    final textColor = _isHovered
        ? MacosColors.alternateSelectedControlTextColor
        : MacosColors.labelColor.resolveFrom(context);
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: _isHovered
              ? MacosColors.systemBlueColor.withValues(alpha: 0.18)
              : MacosColors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.label,
                  style: theme.typography.body.copyWith(color: textColor),
                ),
              ),
              if (shortcutLabel != null)
                Text(
                  shortcutLabel,
                  style: theme.typography.caption1.copyWith(color: textColor),
                ),
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
    final keyLabel = shortcut.trigger.keyLabel.isNotEmpty
        ? shortcut.trigger.keyLabel
        : shortcut.trigger.debugName ?? '';
    if (keyLabel.isEmpty) {
      return parts.isEmpty ? null : parts.join();
    }
    parts.add(keyLabel.toUpperCase());
    return parts.join();
  }
}
