import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import '../../core/date/app_date.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/profile/profile.dart';
import '../../domain/zodiac/zodiac_calculator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/birth_date_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/star_field.dart';
import '../shell/main_shell.dart';

/// 7-step onboarding (product spec §6):
/// welcome → name → birth date → birth time → birth city → result →
/// daily notification opt-in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onboardingAlreadySeen = false});

  final bool onboardingAlreadySeen;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _totalSteps = 7;

  int _step = 0;
  final _nameController = TextEditingController();

  int _birthYear = AppDate.maxBirthYear - 25;
  int _birthMonth = 1;
  int _birthDay = 1;
  int? _birthMinutes; // null = unknown
  String? _city;
  String? _dateError;

  bool _notified = false;
  ZodiacCalculation? _result;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canNext {
    switch (_step) {
      case 0:
      case 1:
      case 3:
      case 4:
      case 5:
      case 6:
        return true;
      case 2:
        return _dateError == null;
      default:
        return false;
    }
  }

  Future<void> _next() async {
    if (_step == 2) {
      if (!AppDate.isValid(_birthYear, _birthMonth, _birthDay)) {
        setState(() => _dateError = 'تاریخ معتبر نیست؛ دوباره بررسی کن.');
        return;
      }
      final calc = ref.read(zodiacCalculatorProvider).calculate(
            AppDate.fromYMD(_birthYear, _birthMonth, _birthDay),
          );
      if (calc == null) {
        setState(() => _dateError = 'تاریخ تولد قابل پردازش نیست.');
        return;
      }
      setState(() {
        _dateError = null;
        _result = calc;
      });
    }

    if (_step == 6) {
      await _finish();
      return;
    }

    setState(() => _step = (_step + 1).clamp(0, _totalSteps - 1));
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    final result = _result;
    if (result == null) return;

    final analytics = ref.read(analyticsProvider);
    final profileNotifier = ref.read(primaryProfileProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final profileId = generateId();
    final error = await profileNotifier.save(
      Profile(
        id: profileId,
        name: _nameController.text.trim().isEmpty
            ? 'مسافرِ آسمان'
            : _nameController.text.trim(),
        birthDate:
            '$_birthYear-${_two(_birthMonth)}-${_two(_birthDay)}',
        birthTime:
            _birthMinutes == null ? null : minutesToTimeString(_birthMinutes!),
        birthTimeKnown: _birthMinutes != null,
        birthCity: _city,
        zodiacId: result.sign.id,
        isPrimary: true,
        createdAt: utcNowIso(),
        updatedAt: utcNowIso(),
      ),
    );

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    await settingsNotifier.setOnboardingCompleted();
    analytics.logEvent(AnalyticsEvent.onboardingCompleted.id);
    // Keep the partner store in sync with the active profile.
    await ref.read(partnerProvider.notifier).loadFor(profileId);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _enableNotifications() async {
    final settings = ref.read(settingsProvider);
    final granted =
        await ref.read(settingsProvider.notifier).enableNotifications(
              settings.notificationHour,
              settings.notificationMinute,
            );
    setState(() => _notified = true);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اجازهٔ اعلان داده نشد؛ هر وقت خواستی از تنظیمات فعالش کن.'),
        ),
      );
    }
    await _next();
  }

  String get _nextLabel {
    switch (_step) {
      case 0:
        return 'شروع کنیم';
      case 5:
        return 'ادامه';
      case 6:
        return 'ورود به طالع بین';
      default:
        return 'ادامه';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      body: StarField(
        enabled: !reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              // Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_forward, size: 22),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / _totalSteps,
                          minHeight: 5,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${PersianNumbers.toPersianNum(_step + 1)} از ${PersianNumbers.toPersianNum(_totalSteps)}',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  child: Padding(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: _buildStep(),
                  ),
                ),
              ),

              // Footer actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _canNext ? _next : null,
                        child: Text(_nextLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return const _WelcomeStep();
      case 1:
        return _NameStep(controller: _nameController);
      case 2:
        return _BirthDateStep(
          year: _birthYear,
          month: _birthMonth,
          day: _birthDay,
          errorText: _dateError,
          onChanged: (y, m, d) => setState(() {
            _birthYear = y;
            _birthMonth = m;
            _birthDay = d;
          }),
        );
      case 3:
        return _BirthTimeStep(
          selected: _birthMinutes,
          onChanged: (m) => setState(() => _birthMinutes = m),
        );
      case 4:
        return _CityStep(
          selected: _city,
          onChanged: (c) => setState(() => _city = c),
        );
      case 5:
        return _ResultStep(calculation: _result);
      case 6:
        return _NotificationStep(
          onAllow: _enableNotifications,
          onSkip: _next,
          done: _notified,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

// ── Steps ─────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontFamily: 'Vazirmatn',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Celestial hero backdrop with a scrim so text stays readable.
        Positioned.fill(
          child: Image.asset(
            'assets/images/hero_night_sky.jpg',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation<double>(0.55),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppTheme.violet,
                    AppTheme.gold,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.violet.withValues(alpha: 0.35),
                    blurRadius: 46,
                  ),
                ],
              ),
              child: const Icon(
                Icons.nightlight_round,
                size: 62,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 34),
          const _StepTitle(
            'خوش آمدی',
            'طالع شخصی خودت را هر روز بر اساس ماه تولدت ببین.',
          ),
          const SizedBox(height: 26),
          GlassCard(
            child: Column(
              children: [
                _featureRow(context, Icons.today, 'طالع روزانه، هفتگی و ماهانه'),
                const SizedBox(height: 12),
                _featureRow(context, Icons.favorite_border, 'سازگاری عاطفی با ۱۲ برج'),
                const SizedBox(height: 12),
                _featureRow(context, Icons.auto_awesome, 'رنگ شانس، عدد شانس و پیام روز'),
                const SizedBox(height: 12),
                _featureRow(context, Icons.lock_outline, 'همه‌چیز آفلاین و روی گوشی خودت'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'این محتوا جنبهٔ سرگرمی و تفسیری دارد.',
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
          ),
        ),
      ],
    );
  }

  Widget _featureRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.violet.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.violet),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          const _StepTitle('اسمت چیه؟', 'نام یا نام مستعار — اختیاری است.'),
          const SizedBox(height: 26),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: 'مثلاً: ستاره',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'اگر دوست نداری اسمی بگویی، بعداً «مسافر آسمان» صدایت می‌کنیم.',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.5),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthDateStep extends StatelessWidget {
  const _BirthDateStep({
    required this.year,
    required this.month,
    required this.day,
    required this.onChanged,
    this.errorText,
  });

  final int year;
  final int month;
  final int day;
  final void Function(int, int, int) onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          const _StepTitle(
            'تاریخ تولدت',
            'برج تولدت را از روی تاریخ اصلی محاسبه می‌کنیم.',
          ),
          const SizedBox(height: 26),
          BirthDateField(
            year: year,
            month: month,
            day: day,
            onChanged: onChanged,
            errorText: errorText,
          ),
        ],
      ),
    );
  }
}

class _BirthTimeStep extends StatelessWidget {
  const _BirthTimeStep({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          const _StepTitle(
            'ساعت تولدت',
            'برای چارت تولدِ آینده لازم می‌شود — الان اختیاری است.',
          ),
          const SizedBox(height: 26),
          BirthTimeField(selected: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CityStep extends StatelessWidget {
  const _CityStep({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          const _StepTitle(
            'شهر تولدت',
            'بدون هیچ دسترسی به موقعیت — خودت انتخاب می‌کنی. (اختیاری)',
          ),
          const SizedBox(height: 26),
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final city in kIranCities)
                  _SelectTile(
                    label: city,
                    selected: selected == city,
                    onTap: () => onChanged(selected == city ? null : city),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple selectable row (avoids version-sensitive Radio APIs).
class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  const _ResultStep({required this.calculation});

  final ZodiacCalculation? calculation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calc = calculation;
    if (calc == null) {
      return Center(
        child: Text(
          'تاریخ تولد نامعتبر است.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }
    final sign = calc.sign;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'تو یک',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: GlassCard(
              highlight: true,
              accent: AppTheme.gold,
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  ZodiacSymbol(sign.symbol, fontSize: 76),
                  const SizedBox(height: 10),
                  Text(
                    '${sign.nameFa} هستی',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sign.nameEn,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      InfoChip(label: 'عنصر: ${sign.element}'),
                      InfoChip(label: 'سیارهٔ حاکم: ${sign.rulingPlanet}'),
                      InfoChip(
                        label: AppDate.formatMedium(calc.jalaliBirthDate),
                        icon: Icons.cake,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Text(
              sign.description,
              style: TextStyle(
                fontSize: 13,
                height: 2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({
    required this.onAllow,
    required this.onSkip,
    required this.done,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 26),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              size: 42,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 24),
          const _StepTitle(
            'یادآوری روزانه',
            'هر روز صبح طالع امروزت را یادآوری کنیم؟',
          ),
          const SizedBox(height: 30),
          GlassCard(
            child: Column(
              children: [
                Text(
                  '«طالع امروزت آماده است»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '«ببین امروز عشق، کار و شانس چه چیزی برایت دارند.»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: done ? null : onAllow,
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('آره، یادم بیاور'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSkip,
              child: const Text('فعلاً نه'),
            ),
          ),
        ],
      ),
    );
  }
}
