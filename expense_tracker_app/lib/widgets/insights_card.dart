import 'package:flutter/material.dart';

class InsightsCard extends StatelessWidget {
  final List<String> insights;

  const InsightsCard({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: insights
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• "),
                      Expanded(child: Text(e)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}