import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

/// A reusable container that replicates the macOS-style "frosted glass" overlay
/// appearance used by [MacosPopupButton]'s dropdown menu.
///
/// Applies a semi-transparent background with backdrop blur, a subtle border,
/// and a shadow — matching the styling from `MacosOverlayFilter` in macos_ui.
class MacosOverlayContainer extends StatelessWidget {
  final Widget child;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry padding;

  const MacosOverlayContainer({
    super.key,
    required this.child,
    this.constraints,
    this.padding = const EdgeInsets.all(4),
  });

  static const _kBorderRadius = BorderRadius.all(Radius.circular(5.0));

  @override
  Widget build(BuildContext context) {
    final brightness = MacosTheme.brightnessOf(context);
    final isDark = brightness == Brightness.dark;

    // Match MacosOverlayFilter: base color applied at 25% alpha over blur
    final bgColor = isDark
        ? const Color.fromRGBO(30, 30, 30, 1).withValues(alpha: 0.25)
        : const Color.fromRGBO(242, 242, 247, 1).withValues(alpha: 0.25);

    final borderColor = isDark
        ? CupertinoColors.systemGrey3.darkColor
        : CupertinoColors.systemGrey3.color;

    final shadowColor =
        (isDark ? CupertinoColors.black : CupertinoColors.systemGrey.color)
            .withValues(alpha: 0.25);

    return Container(
      constraints: constraints,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: _kBorderRadius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 4),
            spreadRadius: 4.0,
            blurRadius: 8.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _kBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
