import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    final disputed = status == 'disputed';
    final color = verified ? Colors.green.shade700 : disputed ? Colors.orange.shade800 : Colors.blueGrey.shade700;
    final text = verified ? 'بررسی‌شده' : disputed ? 'اختلاف منابع' : 'نیازمند بررسی';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
