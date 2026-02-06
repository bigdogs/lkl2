import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';

class ValueInputWithSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final String? selectedField;
  final Function(String) onSubmitted;

  const ValueInputWithSuggestions({
    super.key,
    required this.controller,
    required this.selectedField,
    required this.onSubmitted,
  });

  @override
  State<ValueInputWithSuggestions> createState() =>
      _ValueInputWithSuggestionsState();
}

class _ValueInputWithSuggestionsState extends State<ValueInputWithSuggestions> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Suggestion State
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  Timer? _debounce;

  // We need to know if the text change was user input or selection
  bool _isSelecting = false;
  // Flag to track if the user is interacting with the overlay to prevent premature closing
  bool _isInteractingWithOverlay = false;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _scrollController.dispose();
    _focusNode.dispose();
    _removeOverlay();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Use addPostFrameCallback to ensure the widget is ready and to avoid
      // race conditions with the tap event or layout updates.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus && _overlayEntry == null) {
          _onTap();
        }
      });
    } else {
      // Only remove overlay if we're not interacting with it
      if (!_isInteractingWithOverlay) {
        _removeOverlay();
      }
    }
  }

  void _onTap() {
    if (mounted && widget.selectedField != null) {
      if (_overlayEntry == null) {
        // Cancel any pending debounce
        _debounce?.cancel();
        _resetAndFetch();
      }
    }
  }

  void _onTextChanged() {
    if (_isSelecting) return;

    // Debounce search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && widget.selectedField != null && _focusNode.hasFocus) {
        _resetAndFetch();
      } else {
        _removeOverlay();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      _loadMore();
    }
  }

  Future<void> _resetAndFetch() async {
    _offset = 0;
    _suggestions = [];
    _hasMore = true;
    _isLoading = true;

    // Show overlay immediately with loading if needed, or wait for first result
    _showOverlay();

    await _fetchSuggestions();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _overlayEntry?.markNeedsBuild(); // Update loading spinner
    await _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    if (widget.selectedField == null) return;

    try {
      final provider = context.read<LogProvider>();
      final newItems = await provider.getFieldValues(
        widget.selectedField!,
        widget.controller.text,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _suggestions.addAll(newItems);
          _offset += newItems.length;
          _hasMore = newItems.length >= _limit;
          _isLoading = false;
        });
        _overlayEntry?.markNeedsBuild();
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    // Calculate available height below the input, leaving some margin (e.g., 10)
    final availableHeight = screenHeight - offset.dy - size.height - 10;
    // Ensure we have a reasonable minimum height, though usually bottom area is large enough
    final maxHeight = availableHeight > 0 ? availableHeight : 200.0;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300, // Fixed width as requested, or size.width for flexible
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: TapRegion(
            groupId: _layerLink,
            onTapOutside: (_) {
              _removeOverlay();
              FocusScope.of(context).unfocus();
            },
            child: _buildSuggestionList(maxHeight),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionList(double maxHeight) {
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Match background color with ActiveFiltersBar (default state)
    final backgroundColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF0F0F0);

    return Listener(
      onPointerDown: (_) {
        _isInteractingWithOverlay = true;
      },
      onPointerUp: (_) {
        // Delay resetting the flag to allow the onTap event to propagate
        // and complete before the focus change handler runs.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _isInteractingWithOverlay = false;
            // If focus was lost while interacting, and we are done, remove overlay
            if (!_focusNode.hasFocus) {
              _removeOverlay();
            }
          }
        });
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight < 200
              ? maxHeight
              : 200, // Cap at 200 or available space
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ), // Add vertical padding
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MacosColors.separatorColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            if (_suggestions.isEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No suggestions",
                  style: theme.typography.caption1.copyWith(
                    color: MacosColors.secondaryLabelColor.resolveFrom(context),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap:
                      true, // Allow ListView to be smaller than max height
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _suggestions.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: ProgressCircle(radius: 10),
                        ),
                      );
                    }

                    final item = _suggestions[index];
                    return _SuggestionItem(
                      text: item,
                      onTap: () {
                        _isSelecting = true;
                        widget.controller.text = item;
                        _isSelecting = false;
                        _removeOverlay();
                        FocusScope.of(context).unfocus();
                        widget.onSubmitted(item);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _layerLink,
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
        },
        child: MacosTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          placeholder: 'Value',
          onSubmitted: widget.onSubmitted,
          onTap: _onTap,
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionItem({required this.text, required this.onTap});

  @override
  State<_SuggestionItem> createState() => _SuggestionItemState();
}

class _SuggestionItemState extends State<_SuggestionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use macOS style selection color for hover
    final backgroundColor = _isHovered
        ? (isDark ? const Color(0xFF0058D0) : const Color(0xFF006CFF))
        : MacosColors.transparent;

    final textColor = _isHovered
        ? MacosColors.white
        : MacosColors.labelColor.resolveFrom(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.text,
            style: theme.typography.body.copyWith(
              fontSize: 13,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
