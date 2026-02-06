import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';

class BottomStatusBar extends StatelessWidget {
  const BottomStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Status Bar Background Color
    final backgroundColor = isDark
        ? const Color(0xFF282828) // Darker gray for dark mode
        : const Color(0xFFF5F5F5); // Light gray for light mode

    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: MacosColors.separatorColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Results Count
          if (provider.isSearching)
            const SizedBox(
              height: 14,
              width: 14,
              child: ProgressCircle(value: null), // Indeterminate spinner
            )
          else
            Text(
              _getStatusText(provider),
              style: theme.typography.caption1.copyWith(
                fontSize: 11,
                color: MacosColors.labelColor.resolveFrom(context),
              ),
            ),

          const SizedBox(width: 12),

          // Right: Error Message (if any)
          if (provider.searchError != null) ...[
            MacosIcon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 12,
              color: MacosColors.systemRedColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: GestureDetector(
                onTap: () => _showErrorDialog(context, provider.searchError!),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    provider.searchError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption1.copyWith(
                      fontSize: 11,
                      color: MacosColors.systemRedColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusText(LogProvider provider) {
    if (provider.filters.isEmpty && provider.lastSearchQuery.isEmpty) {
      return "";
    }

    final count = provider.searchResults.length;
    if (count == 0) {
      return "No results found";
    } else {
      return "$count results found";
    }
  }

  void _showErrorDialog(BuildContext context, String error) {
    showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const MacosIcon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: MacosColors.systemRedColor,
          size: 48,
        ),
        title: const Text("Search Error"),
        message: Text(error),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("OK"),
        ),
      ),
    );
  }
}
