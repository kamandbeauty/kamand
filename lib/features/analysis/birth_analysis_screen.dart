import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/date_engine.dart';
import '../../core/normalization/persian_normalizer.dart';
import '../../domain/models/numerology_result.dart';

class BirthAnalysisScreen extends ConsumerStatefulWidget {
  const BirthAnalysisScreen({super.key});

  @override
  ConsumerState<BirthAnalysisScreen> createState() => _BirthAnalysisScreenState();
}

class _BirthAnalysisScreenState extends ConsumerState<BirthAnalysisScreen> {
  final nameController = TextEditingController();
  final dateController = TextEditingController();
  CalendarKind calendar = CalendarKind.jalali;
  String? error;
  int? nameNumber;
  int? birthNumber;
  int? lifePath;
  CalendarDate? normalizedDate;
  NumerologyResult? numerology;
  bool isAnalyzing = false;

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
      birthNumber = null;
      lifePath = null;
      normalizedDate = null;
      numerology = null;
    });
    await Future<void>.delayed(Duration.zero);
    final name = nameController.text.trim();
    final rawDate = PersianNormalizer.toLatinDigits(dateController.text.trim()).replaceAll('/', '-');
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(rawDate);
    if (name.isEmpty || match == null) {
      setState(() {
        isAnalyzing = false;
        error = 'نام و تاریخ را با قالب YYYY-MM-DD وارد کنید.';
      });
      return;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    try {
      final date = CalendarDate(year: year, month: month, day: day, calendar: calendar);
      if (!DateEngine.isValid(date)) throw const FormatException('تاریخ نامعتبر است.');
      final gregorian = calendar == CalendarKind.jalali ? DateEngine.jalaliToGregorian(date) : DateTime(year, month, day);
      final jalali = DateEngine.gregorianToJalali(gregorian);
      final abjad = ref.read(abjadEngineProvider).calculate(name);
      if (!abjad.isComplete) throw const FormatException('حرف ناشناخته در نام وجود دارد.');
      final nameNumerology = ref.read(numerologyEngineProvider).fromAbjadTotal(abjad.total, inputComplete: true);
      if (!nameNumerology.isAvailable) throw FormatException(nameNumerology.description);
      setState(() {
        normalizedDate = calendar == CalendarKind.jalali ? date : jalali;
        nameNumber = nameNumerology.value;
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
      appBar: AppBar(title: const Text('نام و تاریخ تولد')),
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
            _ResultGrid(nameNumber: nameNumber!, birthNumber: birthNumber!, lifePath: lifePath!),
            const SizedBox(height: 14),
            Card(color: const Color(0xFFF6EDDC), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('فرمول و وضعیت', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Rule: ${numerology!.ruleKey} · نسخه: ${numerology!.ruleVersion}'), Text('وضعیت: ${numerology!.status} · منبع: ${numerology!.sourceTitle}'), const SizedBox(height: 5), Text('محاسبه: ${numerology!.calculation}'), const SizedBox(height: 8), Text('فرمول تاریخ: کاهش رقمی ${normalizedDate!.iso}'), const SizedBox(height: 8), Text(numerology!.disclaimer, style: const TextStyle(height: 1.7, fontWeight: FontWeight.w700))]))),
          ],
        ],
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.nameNumber, required this.birthNumber, required this.lifePath});

  final int nameNumber;
  final int birthNumber;
  final int lifePath;

  @override
  Widget build(BuildContext context) {
    return Row(children: [_NumberCard(title: 'عدد نام', value: nameNumber), const SizedBox(width: 10), _NumberCard(title: 'عدد تولد', value: birthNumber), const SizedBox(width: 10), _NumberCard(title: 'مسیر زندگی', value: lifePath)]);
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
