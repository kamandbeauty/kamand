import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/date_engine.dart';
import '../../domain/models/abjad_result.dart';
import '../../domain/models/numerology_result.dart';
import '../../domain/models/profile.dart';

class BirthAnalysisScreen extends ConsumerStatefulWidget {
  const BirthAnalysisScreen({super.key, this.profile});

  final Profile? profile;

  @override
  ConsumerState<BirthAnalysisScreen> createState() => _BirthAnalysisScreenState();
}

class _BirthAnalysisScreenState extends ConsumerState<BirthAnalysisScreen> {
  final nameController = TextEditingController();
  final dateController = TextEditingController();
  CalendarKind calendar = CalendarKind.jalali;
  String? error;
  int? nameNumber;
  int? nameAbjadTotal;
  int? birthNumber;
  int? lifePath;
  CalendarDate? normalizedDate;
  DateTime? gregorianDate;
  AbjadResult? nameAbjad;
  NumerologyResult? numerology;
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    if (profile != null) {
      nameController.text = profile.name;
      dateController.text = profile.birthDate;
      calendar = profile.birthCalendar == CalendarKind.gregorian.name ? CalendarKind.gregorian : CalendarKind.jalali;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();
    super.dispose();
  }

  Future<void> analyze() async {
    if (isAnalyzing) return;
    setState(() {
      isAnalyzing = true;
      error = null;
      nameNumber = null;
      nameAbjadTotal = null;
      birthNumber = null;
      lifePath = null;
      normalizedDate = null;
      gregorianDate = null;
      nameAbjad = null;
      numerology = null;
    });
    await Future<void>.delayed(Duration.zero);
    final name = nameController.text.trim();
    final date = DateEngine.parse(dateController.text, calendar);
    if (name.isEmpty || date == null) {
      setState(() {
        isAnalyzing = false;
        error = 'نام و تاریخ را با قالب YYYY-MM-DD وارد کنید.';
      });
      return;
    }

    try {
      final gregorian = calendar == CalendarKind.jalali ? DateEngine.jalaliToGregorian(date) : DateTime(date.year, date.month, date.day);
      final jalali = DateEngine.gregorianToJalali(gregorian);
      final abjad = ref.read(abjadEngineProvider).calculate(name);
      if (!abjad.isComplete) throw const FormatException('حرف ناشناخته در نام وجود دارد.');
      final nameNumerology = ref.read(numerologyEngineProvider).fromAbjadTotal(abjad.total, inputComplete: true);
      if (!nameNumerology.isAvailable) throw FormatException(nameNumerology.description);
      setState(() {
        normalizedDate = calendar == CalendarKind.jalali ? date : jalali;
        gregorianDate = gregorian;
        nameNumber = nameNumerology.value;
        nameAbjadTotal = abjad.total;
        nameAbjad = abjad;
        birthNumber = DateEngine.birthNumber(normalizedDate!);
        lifePath = DateEngine.lifePath(birthDate: normalizedDate!);
        numerology = nameNumerology;
        isAnalyzing = false;
      });
    } catch (exception) {
      setState(() {
        isAnalyzing = false;
        error = exception is FormatException ? exception.message : 'تحلیل انجام نشد؛ ورودی را بررسی کنید.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.profile == null ? 'نام و تاریخ تولد' : 'تحلیل ${widget.profile!.title}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text('تحلیل سنتی نام و تولد', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('تاریخ‌ها فقط برای محاسبه همین دستگاه استفاده می‌شوند و نتیجه علمی درباره شخصیت یا آینده نیست.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 20),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          SegmentedButton<CalendarKind>(segments: const [ButtonSegment(value: CalendarKind.jalali, label: Text('شمسی'), icon: Icon(Icons.calendar_month_outlined)), ButtonSegment(value: CalendarKind.gregorian, label: Text('میلادی'), icon: Icon(Icons.event_outlined))], selected: {calendar}, onSelectionChanged: (selection) => setState(() => calendar = selection.first)),
          const SizedBox(height: 12),
          TextField(controller: dateController, keyboardType: TextInputType.datetime, decoration: InputDecoration(labelText: calendar == CalendarKind.jalali ? 'تاریخ شمسی' : 'تاریخ میلادی', hintText: calendar == CalendarKind.jalali ? '1403-01-01' : '2024-03-20', prefixIcon: const Icon(Icons.date_range_outlined))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 9), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: isAnalyzing ? null : analyze, icon: const Icon(Icons.auto_awesome), label: Text(isAnalyzing ? 'در حال محاسبه…' : 'تحلیل کن')),
          if (isAnalyzing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (normalizedDate == null && error == null && !isAnalyzing) const Padding(padding: EdgeInsets.only(top: 24), child: Card(child: Padding(padding: EdgeInsets.all(17), child: Text('برای شروع، نام و تاریخ را وارد کنید. نتیجه فقط به‌عنوان تحلیل سنتی نمایش داده می‌شود.', style: TextStyle(color: Colors.blueGrey, height: 1.6))))),
          if (normalizedDate != null) ...[
            const SizedBox(height: 22),
            _ResultGrid(nameNumber: nameNumber!, nameAbjadTotal: nameAbjadTotal!, birthNumber: birthNumber!, lifePath: lifePath!),
            const SizedBox(height: 14),
            _BirthDetailsCard(nameAbjad: nameAbjad!, normalizedDate: normalizedDate!, gregorianDate: gregorianDate!, numerology: numerology!),
            const SizedBox(height: 14),
            Card(color: const Color(0xFFF6EDDC), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('فرمول و وضعیت', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Rule: ${numerology!.ruleKey} · نسخه: ${numerology!.ruleVersion}'), Text('وضعیت: ${numerology!.status} · منبع: ${numerology!.sourceTitle}'), const SizedBox(height: 5), Text('محاسبه: ${numerology!.calculation}'), const SizedBox(height: 8), Text('فرمول تاریخ: کاهش رقمی ${normalizedDate!.iso}'), const SizedBox(height: 8), Text(numerology!.disclaimer, style: const TextStyle(height: 1.7, fontWeight: FontWeight.w700))]))),
          ],
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.nameNumber, required this.nameAbjadTotal, required this.birthNumber, required this.lifePath});

  final int nameNumber;
  final int nameAbjadTotal;
  final int birthNumber;
  final int lifePath;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _NumberCard(title: 'مجموع ابجد نام', value: nameAbjadTotal),
        _NumberCard(title: 'کاهش رقمی نام', value: nameNumber),
        _NumberCard(title: 'عدد تولد', value: birthNumber),
        _NumberCard(title: 'مسیر زندگی', value: lifePath),
      ],
    );
  }
}

class _BirthDetailsCard extends StatelessWidget {
  const _BirthDetailsCard({required this.nameAbjad, required this.normalizedDate, required this.gregorianDate, required this.numerology});

  final AbjadResult nameAbjad;
  final CalendarDate normalizedDate;
  final DateTime gregorianDate;
  final NumerologyResult numerology;

  @override
  Widget build(BuildContext context) {
    final gregorianIso = gregorianDate.toIso8601String().split('T').first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('جزئیات و فرمول گزارش', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('تاریخ شمسی نرمال‌شده: ${normalizedDate.iso}'),
          Text('معادل میلادی: $gregorianIso'),
          const SizedBox(height: 8),
          Text('ابجد نام: ${nameAbjad.steps.map((step) => '${step.letter}=${step.value ?? '؟'}').join(' + ')}', style: const TextStyle(height: 1.6)),
          Text('مجموع نام: ${nameAbjad.total} · ${numerology.calculation}'),
          const SizedBox(height: 8),
          const Text('عدد تولد و مسیر زندگی با کاهش رقمی نویسه‌های تاریخ محاسبه شده‌اند؛ این‌ها توصیف علمی شخصیت یا پیش‌بینی آینده نیستند.', style: TextStyle(color: Colors.blueGrey, height: 1.6, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.title, required this.value});

  final String title;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)), const SizedBox(height: 8), Text('$value', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.w900))])));
  }
}
