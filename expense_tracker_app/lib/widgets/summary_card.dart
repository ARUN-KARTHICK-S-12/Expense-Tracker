import 'package:flutter/material.dart';

import 'hideable_amount.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    this.subtitle,
    this.hideable = false,
  });

  final String title;
  final String amount;
  final Color color;
  final String? subtitle;
  final bool hideable;

  @override
  Widget build(BuildContext context) {
    final amountStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        );

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (hideable)
              HideableAmount(amount: amount, style: amountStyle)
            else
              Text(amount, style: amountStyle),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
