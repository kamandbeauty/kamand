import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/jafr_result.dart';
import '../shared/status_badge.dart';

class JafrScreen extends ConsumerStatefulWidget {
  const JafrScreen({super.key});

  @override
  ConsumerState<JafrScreen> createState() => _JafrScreenState();
}

class _JafrScreenState extends ConsumerState<JafrScreen> {
  final controller = TextEditingController();
  JafrResult? result;
  bool submitted = false;
  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> calculate() async {
    if (loading) return;
    final input = controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        result = null;
        submitted = true;
      });
      return;
    }
    setState(() => loading = true);
    await Future<void>.delayed(Duration.zero);
    final calculated = ref.read(jafrEngineProvider).calculate(input);
    if (!mounted) return;
    setState(() {
      result = calculated;
      submitted = true;
      loading = false;
    });
  }

  void useSample(String value) {
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
    calculate();
  }

  void copyResult() {
    final current = result;
    if (current == null || !current.isAvailable) return;
    Clipboard.setData(ClipboardData(text: 'نام: ${controller.text.trim()}\nعدد حروف جفر: ${current.total}\nکاهش رقمی مشتق‌شده: ${current.reducedValue}\nمنبع: ${current.sourceTitle}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('گزارش جفر کپی شد')));
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    return Scaffold(
      appBar: AppBar(title: const Text('آزمایشگاه جفر')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _JafrHero(onGuideTap: () => _showGuide(context)),
          const SizedBox(height: 16),
          const Text('نام یا عبارت را وارد کن', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('محاسبه بر پایه جمع ارزش حروف در نگاشت استاندارد ابجد انجام می‌شود.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => calculate(),
            decoration: const InputDecoration(labelText: 'ورودی جفر', hintText: 'مثلاً محمد یا علی', prefixIcon: Icon(Icons.auto_awesome_outlined)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _SampleChip(label: 'محمد', onTap: () => useSample('محمد')),
            _SampleChip(label: 'علی', onTap: () => useSample('علی')),
            _SampleChip(label: 'فاطمه', onTap: () => useSample('فاطمه')),
          ]),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'ساخت گزارش جفر',
            child: FilledButton.icon(onPressed: loading ? null : calculate, icon: const Icon(Icons.calculate_outlined), label: Text(loading ? 'در حال محاسبه…' : 'ساخت گزارش جفر')),
          ),
          if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (submitted && controller.text.trim().isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('برای محاسبه، یک نام یا عبارت وارد کن.', style: TextStyle(color: Colors.redAccent))),
          if (current != null) ...[
            const SizedBox(height: 18),
            _JafrResultPanel(result: current, input: controller.text.trim(), onCopy: copyResult),
          ],
          const SizedBox(height: 18),
          const _JafrMethodCard(),
          const SizedBox(height: 12),
          _JafrGuideCard(onTap: () => _showGuide(context)),
        ],
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _JafrGuideSheet(),
    );
  }
}

class _JafrHero extends StatelessWidget {
  const _JafrHero({required this.onGuideTap});

  final VoidCallback onGuideTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF2A1D3B), Color(0xFF704681)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Stack(children: [
        Positioned(top: -42, left: -18, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withAlpha(18), shape: BoxShape.circle))),
        Positioned(bottom: -70, right: 22, child: Container(width: 190, height: 190, decoration: BoxDecoration(color: Colors.white.withAlpha(14), shape: BoxShape.circle))),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 27)),
              const SizedBox(width: 12),
              const Text('جَفْر', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
            ]),
            const Spacer(),
            const Text('علم حروف،\nبا محاسبه شفاف', style: TextStyle(color: Colors.white, fontSize: 22, height: 1.2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            GestureDetector(onTap: onGuideTap, child: const Text('راهنمای روش  ←', style: TextStyle(color: Color(0xFFF5D99C), fontWeight: FontWeight.w800))),
          ]),
        ),
      ]),
    );
  }
}

class _SampleChip extends StatelessWidget {
  const _SampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(avatar: const Icon(Icons.flash_on_outlined, size: 16), label: Text(label), onPressed: onTap);
  }
}

class _JafrResultPanel extends StatelessWidget {
  const _JafrResultPanel({required this.result, required this.input, required this.onCopy});

  final JafrResult result;
  final String input;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    if (!result.isAvailable) {
      return Card(
        color: const Color(0xFFFFF1ED),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.info_outline, color: Colors.deepOrange), const SizedBox(width: 8), const Expanded(child: Text('نتیجه قابل محاسبه نیست', style: TextStyle(fontWeight: FontWeight.w900))), StatusBadge(status: result.status)]),
            const SizedBox(height: 9),
            Text(result.description, style: const TextStyle(height: 1.7)),
            if (result.unknownLetters.isNotEmpty) ...[const SizedBox(height: 8), Text('حروف ناشناخته: ${result.unknownLetters.join('، ')}', style: const TextStyle(fontWeight: FontWeight.w800))],
          ]),
        ),
      );
    }
    return Card(
      color: const Color(0xFFF2EAF7),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('گزارش: $input', style: const TextStyle(fontWeight: FontWeight.w900))), IconButton(onPressed: onCopy, tooltip: 'کپی گزارش', icon: const Icon(Icons.copy_outlined))]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Metric(label: 'عدد حروف', value: '${result.total}', color: const Color(0xFF6A3D7A))),
            const SizedBox(width: 10),
            Expanded(child: _Metric(label: 'کاهش مشتق‌شده', value: '${result.reducedValue}', color: const Color(0xFF176B67))),
          ]),
          const SizedBox(height: 14),
          Text(result.calculation, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('منبع: ${result.sourceTitle} · Rule: ${result.ruleKey} · نسخه ${result.ruleVersion}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(label: '$label: $value', child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)), const SizedBox(height: 5), Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900))])));
  }
}

class _JafrMethodCard extends StatelessWidget {
  const _JafrMethodCard();

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('روش محاسبه', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      const Text('جفر در این نسخه از ارزش عددی ۲۸ حرف استاندارد ابجد استفاده می‌کند. عدد حروف مقدار اصلی است؛ کاهش رقمی فقط یک نمایش مشتق‌شده است.', style: TextStyle(height: 1.7)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8F4EC), borderRadius: BorderRadius.circular(14)), child: const Text('پ، چ، ژ و گ در ابجد استاندارد مقدار ندارند و حدس زده نمی‌شوند.', style: TextStyle(fontWeight: FontWeight.w800, height: 1.5))),
    ])));
  }
}

class _JafrGuideCard extends StatelessWidget {
  const _JafrGuideCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF253238),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, color: Color(0xFFF5D99C)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('قبل از تفسیر، روش را بشناس', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('جفر سنتی است؛ این عدد پیش‌بینی شخصیت یا آینده نیست.', style: TextStyle(color: Colors.white70, height: 1.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _JafrGuideSheet extends StatelessWidget {
  const _JafrGuideSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), child: ListView(shrinkWrap: true, children: [
      const Text('راهنمای جفر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      const Text('جفر در سنت علم حروف با ارزش عددی حروف ابجد ارتباط دارد. این برنامه فقط بخش عددی و قابل بازبینی را محاسبه می‌کند.', style: TextStyle(height: 1.8)),
      const SizedBox(height: 12),
      const _GuideRow(icon: Icons.check_circle_outline, title: 'چه چیزی محاسبه می‌شود؟', body: 'جمع ارزش حروف ورودی و یک کاهش رقمی مشتق‌شده برای نمایش.'),
      const _GuideRow(icon: Icons.block_outlined, title: 'چه چیزی محاسبه نمی‌شود؟', body: 'پیش‌گویی، غیب‌گویی، تشخیص شخصیت، تعیین سرنوشت یا پیش‌بینی رابطه.'),
      const _GuideRow(icon: Icons.source_outlined, title: 'منبع', body: 'JAFR و ABJAD در Encyclopaedia Iranica؛ وضعیت Rule در برنامه unverified و تفسیری است.'),
      const _GuideRow(icon: Icons.warning_amber_outlined, title: 'چرا بعضی حروف Unknown هستند؟', body: 'نگاشت استاندارد ابجد برای پ، چ، ژ و گ مقدار مستقل ندارد؛ برنامه مقدار آن‌ها را حدس نمی‌زند.'),
    ])));
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(body, style: const TextStyle(color: Colors.blueGrey, height: 1.6))]))]));
  }
}
