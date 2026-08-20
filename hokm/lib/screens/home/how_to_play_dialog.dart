import 'package:flutter/material.dart';

import '../../core/app_strings.dart';

/// دیالوگ آموزش کوتاه قوانین حکم.
class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  static const List<String> _rules = [
    'حکم یک بازی ۴ نفره و تیمی است؛ شما و بازیکن روبه‌رویی‌تان یک تیم‌اید.',
    'حاکم پس از دیدن ۵ کارت اولش، خال حکم (قوی‌ترین خال بازی) را اعلام می‌کند.',
    'در هر دور باید به خالِ کارتِ اول بروید؛ اگر ندارید می‌توانید حکم بزنید یا خال دیگری بیندازید.',
    'اگر حکمی در دور باشد بالاترین حکم می‌برد، وگرنه بزرگ‌ترین کارتِ همان خالِ زمینه.',
    'برندهٔ هر دور، دور بعد را شروع می‌کند.',
    'تیمی که ۷ دور را ببرد، دست (راند) را می‌برد و ۱ امتیاز می‌گیرد.',
    'بردن ۷ بر ۰ «کوت» است (۲ امتیاز) و اگر تیمِ غیرحاکم کوت کند «حاکم‌کوت» است (۳ امتیاز).',
    'اولین تیمی که به ۷ امتیاز برسد مسابقه را می‌برد.',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.howToPlay,
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _rules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 7, color: Color(0xFFE4BE6A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _rules[i],
                  style: const TextStyle(fontSize: 13.5, height: 1.75),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('متوجه شدم'),
        ),
      ],
    );
  }
}
