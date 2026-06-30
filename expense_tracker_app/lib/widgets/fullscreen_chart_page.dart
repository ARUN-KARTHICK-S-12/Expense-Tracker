import 'package:flutter/material.dart';

/// A reusable fullscreen page for any chart widget.
/// 
/// Uses LayoutBuilder so the child always receives a finite, concrete size —
/// never an infinite height constraint (which breaks fl_chart and most
/// custom painters).
class FullscreenChartPage extends StatelessWidget {
  const FullscreenChartPage({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // constraints.maxWidth / maxHeight are always finite here
          // because Scaffold's body is bounded by the screen.
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: constraints.maxWidth,
              // subtract top+bottom padding (2 × 16 = 32)
              height: constraints.maxHeight - 32,
              child: child,
            ),
          );
        },
      ),
    );
  }
}