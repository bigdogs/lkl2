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
      _removeOverlay();
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
            child: _buildSuggestionList(),
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

  Widget _buildSuggestionList() {
    final theme = MacosTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Match background color with ActiveFiltersBar (default state)
    final backgroundColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF0F0F0);

    return Container(
      height: 200, // Max height
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
            Expanded(
              child: ListView.builder(
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
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _isSelecting = true;
                        widget.controller.text = item;
                        _isSelecting = false;
                        _removeOverlay();
                        FocusScope.of(context).unfocus();
                        widget.onSubmitted(item);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        // Removed borders between items as requested
                        child: Text(
                          item,
                          style: theme.typography.body.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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
