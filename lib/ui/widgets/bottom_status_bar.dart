import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';

/// Xcode-style bottom status bar.
///
/// Layout:  [ left status / progress ]  ──spacer──  [ item counts ]
///
/// The right-hand item counts are **always** visible:
///   • "12,345 items" when no filter is active
///   • "42 of 12,345" when a filter/search is active
class BottomStatusBar extends StatelessWidget {
  const BottomStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF282828) : const Color(0xFFF5F5F5);
    final labelColor = MacosColors.labelColor.resolveFrom(context);
    final secondaryColor = MacosColors.secondaryLabelColor.resolveFrom(context);
    final captionStyle = theme.typography.caption1.copyWith(fontSize: 11);

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: MacosColors.separatorColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Left: loading progress / search spinner / error ──
          _buildLeftStatus(context, provider, captionStyle, labelColor),

          // Error (clickable, truncated)
          if (provider.searchError != null) ...[
            const SizedBox(width: 6),
            MacosIcon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 12,
              color: MacosColors.systemRedColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: GestureDetector(
                onTap: () => _showErrorDialog(context, provider.searchError!),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    provider.searchError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: captionStyle.copyWith(
                      color: MacosColors.systemRedColor,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),

          // ── Right: item counts (always visible) ──
          _buildItemCounts(provider, captionStyle, labelColor, secondaryColor),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left status
  // ---------------------------------------------------------------------------

  Widget _buildLeftStatus(
    BuildContext context,
    LogProvider provider,
    TextStyle style,
    Color labelColor,
  ) {
    if (provider.isFileLoading) {
      return _buildLoadingIndicator(context, provider, style, labelColor);
    }
    if (provider.isSearching) {
      return const SizedBox(
        height: 14,
        width: 14,
        child: ProgressCircle(value: null),
      );
    }
    // Truncation badge
    if (provider.truncated) {
      return Text(
        'Tail-loaded',
        style: style.copyWith(
          color: MacosColors.secondaryLabelColor.resolveFrom(context),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    LogProvider provider,
    TextStyle style,
    Color labelColor,
  ) {
    final progress = provider.loadProgress ?? 0;
    final pct = (progress * 100).toInt();
    final phaseLabel = provider.loadPhase == 'indexing'
        ? 'Indexing'
        : 'Loading';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 80, child: ProgressBar(value: progress * 100)),
        const SizedBox(width: 8),
        Text('$phaseLabel $pct%', style: style.copyWith(color: labelColor)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Right item counts – always visible
  // ---------------------------------------------------------------------------

  Widget _buildItemCounts(
    LogProvider provider,
    TextStyle style,
    Color labelColor,
    Color secondaryColor,
  ) {
    final hasFilter =
        provider.filters.isNotEmpty || provider.lastSearchQuery.isNotEmpty;

    // During loading, totalCount hasn't been finalised yet —
    // use loadedCount as the running total.
    final total = provider.isFileLoading
        ? provider.loadedCount
        : provider.totalCount;

    if (!hasFilter) {
      // Simple: "12,345 items"
      return Text(
        '${_formatCount(total)} items',
        style: style.copyWith(color: secondaryColor),
      );
    }

    // Filtered: "42 of 12,345"
    final matched = provider.searchResults.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _formatCount(matched),
            style: style.copyWith(color: labelColor),
          ),
          TextSpan(
            text: ' of ${_formatCount(total)}',
            style: style.copyWith(color: secondaryColor),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Format large numbers with comma separators (e.g. 1,234,567).
  static String _formatCount(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
