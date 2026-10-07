import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified' || status == 'supported';
    final disputed = status == 'disputed';
    final derived = status == 'derived' || status == 'proposed';
    final catalogued = status == 'catalogued';
    final color = verified
        ? Colors.green.shade700
        : disputed
            ? Colors.orange.shade800
            : derived
                ? Colors.indigo.shade700
                : catalogued
                    ? Colors.teal.shade700
                    : Colors.blueGrey.shade700;
    final text = verified
        ? 'پشتیبانی‌شده'
        : disputed
            ? 'اختلاف منابع'
            : derived
                ? 'مشتق‌شده'
                : catalogued
                    ? 'ثبت‌شده'
                    : status == 'unknown'
                        ? 'نامشخص'
                        : 'نیازمند بررسی';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
