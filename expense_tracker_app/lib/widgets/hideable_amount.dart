import 'package:flutter/material.dart';

/// Displays a monetary amount hidden by default with a toggle to show/hide.
class HideableAmount extends StatefulWidget {
  const HideableAmount({
    super.key,
    required this.amount,
    this.style,
    this.hiddenPlaceholder = '••••••',
    this.iconSize = 20,
    this.compact = false,
    this.stacked = false,
  });

  final String amount;
  final TextStyle? style;
  final String hiddenPlaceholder;
  final double iconSize;
  final bool compact;

  /// When true (and [compact] is true), the toggle icon is placed in its
  /// own row above the amount instead of inline beside it. Use this on
  /// narrow containers (e.g. half-width dashboard cards) where an inline
  /// icon leaves too little horizontal room for the amount to be legible.
  final bool stacked;

  @override
  State<HideableAmount> createState() => _HideableAmountState();
}

class _HideableAmountState extends State<HideableAmount> {
  bool _visible = false;

  void _toggle() => setState(() => _visible = !_visible);

  Widget _buildIcon() {
    return IconButton(
      icon: Icon(
        _visible ? Icons.visibility : Icons.visibility_off,
        size: widget.iconSize,
      ),
      tooltip: _visible ? 'Hide amount' : 'Show amount',
      onPressed: _toggle,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ??
        Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            );

    if (widget.compact && widget.stacked) {
      // Icon gets its own row so the amount below can use the full
      // available width instead of sharing it with a 32px icon button.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _buildIcon(),
          ),
          Text(
            _visible ? widget.amount : widget.hiddenPlaceholder,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      );
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _visible ? widget.amount : widget.hiddenPlaceholder,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildIcon(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _visible ? widget.amount : widget.hiddenPlaceholder,
            style: textStyle,
          ),
        ),
        IconButton(
          icon: Icon(
            _visible ? Icons.visibility : Icons.visibility_off,
            size: widget.iconSize,
          ),
          tooltip: _visible ? 'Hide amount' : 'Show amount',
          onPressed: _toggle,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}