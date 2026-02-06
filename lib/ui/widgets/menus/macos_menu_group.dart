import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/ui/widgets/menus/menu_data.dart';
import 'package:lkl2/ui/widgets/menus/menu_panel.dart';
import 'package:lkl2/ui/widgets/menus/menu_overlay_controller.dart';

class MacosMenuGroup extends StatefulWidget {
  final String label;
  final List<MenuItemData> items;
  final double barHeight;

  const MacosMenuGroup({
    super.key,
    required this.label,
    required this.items,
    required this.barHeight,
  });

  @override
  State<MacosMenuGroup> createState() => _MacosMenuGroupState();
}

class _MacosMenuGroupState extends State<MacosMenuGroup> {
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
    MenuOverlayController.clearIfActive(_closeMenu);
  }

  void _openMenu() {
    if (_overlayEntry != null) {
      return;
    }
    MenuOverlayController.setActive(_closeMenu);
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
                child: MenuPanel(items: widget.items, onClose: _closeMenu),
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
              color:
                  isActive
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
