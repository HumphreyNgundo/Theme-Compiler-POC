import 'package:flutter/material.dart';
import '../models/mock_data.dart';

/// A single row in the recent-transactions list.
/// Icon colour and amount colour are driven by status and direction.
class TransactionItem extends StatelessWidget {
  final MockTransaction transaction;
  final Color primaryColor;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = transaction.status == 'failed';
    final isNegative = transaction.isNegative;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TxIcon(
            isFailed: isFailed,
            isNegative: isNegative,
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isNegative ? '-' : '+'} KES ${_fmt(transaction.amount.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isFailed
                      ? Colors.red
                      : isNegative
                          ? Colors.grey.shade700
                          : primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.date,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _TxIcon extends StatelessWidget {
  final bool isFailed;
  final bool isNegative;
  final Color primaryColor;

  const _TxIcon({
    required this.isFailed,
    required this.isNegative,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isFailed
        ? Colors.red.withOpacity(0.1)
        : isNegative
            ? Colors.grey.withOpacity(0.1)
            : primaryColor.withOpacity(0.1);

    final Color fg = isFailed
        ? Colors.red
        : isNegative
            ? Colors.grey.shade600
            : primaryColor;

    final IconData icon = isFailed
        ? Icons.error_outline_rounded
        : isNegative
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}
