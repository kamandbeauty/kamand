import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/theme/app_theme.dart';

import '../data/analytics/analytics_service.dart';
import '../data/database/app_database.dart';
import '../data/notifications/notification_scheduler.dart';
import '../data/premium/billing_gateway.dart';
import '../data/repositories/horoscope_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/settings/settings_service.dart';
import '../domain/compatibility/compatibility_engine.dart';
import '../domain/entitlement/entitlement.dart';
import '../domain/horoscope/horoscope_engine.dart';
import '../domain/profile/profile.dart';
import '../domain/zodiac/zodiac_calculator.dart';
import '../domain/zodiac/zodiac_repository.dart';

/// Composition root: every service is constructed once (in `main`) and
/// provided synchronously to the widget tree — fast startup, easy to
/// override in tests.
class AppServices {
  AppServices({
    required this.db,
    required this.settingsService,
    required this.zodiacRepository,
    required this.profileRepository,
    required this.horoscopeRepository,
    required this.notificationScheduler,
    required this.analytics,
    required this.entitlementService,
  });

  final AppDatabase db;
  final SettingsService settingsService;
  final ZodiacRepository zodiacRepository;

  late final ZodiacCalculator zodiacCalculator = ZodiacCalculator(zodiacRepository);
  late final HoroscopeEngine horoscopeEngine = HoroscopeEngine(zodiacRepository);
  late final CompatibilityEngine compatibilityEngine =
      CompatibilityEngine(zodiacRepository);

  final ProfileRepository profileRepository;
  final HoroscopeRepository horoscopeRepository;
  final NotificationScheduler notificationScheduler;
  final AnalyticsService analytics;
  final EntitlementService entitlementService;

  /// Production bootstrap.
  static Future<AppServices> create() async {
    final db = await AppDatabase.openDefault();
    return forDatabase(db, const AndroidNotificationScheduler());
  }

  /// Test bootstrap (in-memory database, no platform channels).
  static AppServices forTest({
    AppDatabase? db,
    SettingsService? settings,
    NotificationScheduler? scheduler,
    AnalyticsService? analytics,
    RewardedAdGateway? rewardedAds,
  }) {
    return forDatabase(
      db ?? AppDatabase.open(null),
      scheduler ?? const NoopNotificationScheduler(),
      settings: settings,
      analytics: analytics,
      rewardedAds: rewardedAds,
    );
  }

  static AppServices forDatabase(
    AppDatabase db,
    NotificationScheduler scheduler, {
    SettingsService? settings,
    AnalyticsService? analytics,
    RewardedAdGateway? rewardedAds,
  }) {
    final zodiacRepository = const LocalZodiacRepository();
    final settingsService =
        settings ?? _InMemorySettingsService();
    return AppServices(
      db: db,
      settingsService: settingsService,
      zodiacRepository: zodiacRepository,
      profileRepository: LocalProfileRepository(db),
      horoscopeRepository: LocalHoroscopeRepository(
        db,
        HoroscopeEngine(zodiacRepository),
        zodiacRepository,
      ),
      notificationScheduler: scheduler,
      analytics: analytics ?? LocalAnalyticsService(),
      entitlementService: EntitlementService(
        settingsService,
        const UnavailableBillingGateway(),
        rewardedAds ?? const DemoRewardedAdGateway(),
      ),
    );
  }
}

/// In-memory settings used by tests (SharedPreferences-free).
class _InMemorySettingsService implements SettingsService {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  Future<void> clear() async => _settings = const AppSettings();
}

/// Overridden in `main` / tests with a real instance.
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final zodiacRepositoryProvider = Provider<ZodiacRepository>(
  (ref) => ref.watch(servicesProvider).zodiacRepository,
);

final zodiacCalculatorProvider = Provider<ZodiacCalculator>(
  (ref) => ref.watch(servicesProvider).zodiacCalculator,
);

final horoscopeEngineProvider = Provider<HoroscopeEngine>(
  (ref) => ref.watch(servicesProvider).horoscopeEngine,
);

final compatibilityEngineProvider = Provider<CompatibilityEngine>(
  (ref) => ref.watch(servicesProvider).compatibilityEngine,
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ref.watch(servicesProvider).profileRepository,
);

final horoscopeRepositoryProvider = Provider<HoroscopeRepository>(
  (ref) => ref.watch(servicesProvider).horoscopeRepository,
);

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => ref.watch(servicesProvider).notificationScheduler,
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => ref.watch(servicesProvider).analytics,
);

// ── Settings ──────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(
    this._service,
    this._scheduler,
    this._analytics,
  ) : super(const AppSettings()) {
    _load();
  }

  final SettingsService _service;
  final NotificationScheduler _scheduler;
  final AnalyticsService _analytics;

  Future<void> _load() async {
    try {
      state = await _service.load();
    } catch (_) {
      state = const AppSettings();
    }
  }

  Future<void> _persist() => _service.save(state);

  Future<void> setOnboardingCompleted() async {
    state = state.copyWith(onboardingCompleted: true);
    await _persist();
  }

  Future<bool> enableNotifications(int hour, int minute) async {
    await _scheduler.initialize();
    final granted = await _scheduler.requestPermission();
    if (granted) {
      await _scheduler.scheduleDaily(hour, minute);
      state = state.copyWith(
        notificationsEnabled: true,
        notificationHour: hour,
        notificationMinute: minute,
      );
    } else {
      state = state.copyWith(notificationsEnabled: false);
    }
    await _persist();
    _analytics.logEvent(AnalyticsEvent.settingsChanged.id);
    return granted;
  }

  Future<void> disableNotifications() async {
    await _scheduler.cancel();
    state = state.copyWith(notificationsEnabled: false);
    await _persist();
  }

  Future<void> setNotificationTime(int hour, int minute) async {
    if (state.notificationsEnabled) {
      await _scheduler.scheduleDaily(hour, minute);
    }
    state = state.copyWith(notificationHour: hour, notificationMinute: minute);
    await _persist();
  }

  Future<void> setThemeMode(ThemeModeSetting mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  /// Picks the dark palette («تمِ آسمان») used whenever the effective
  /// mode is dark. Light mode always renders «پرتوِ سپیده».
  Future<void> setThemeSkin(AppThemeSkin skin) async {
    state = state.copyWith(themeSkin: skin);
    await _persist();
  }

  Future<void> resetAll() async {
    await _scheduler.cancel();
    await _service.clear();
    state = const AppSettings();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final s = ref.watch(servicesProvider);
  return SettingsNotifier(s.settingsService, s.notificationScheduler, s.analytics);
});

// ── Entitlement ───────────────────────────────────────────────────────

class EntitlementNotifier extends StateNotifier<Entitlement> {
  EntitlementNotifier(this._service) : super(const Entitlement.none()) {
    _load();
  }

  final EntitlementService _service;

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<bool> purchase(PremiumPlan plan) async {
    state = await _service.attemptPurchase(plan);
    return state.hasPremium;
  }

  /// Redeems a campaign promo code; true when it granted premium.
  Future<bool> redeemPromo(String code) async {
    final before = state.hasPremium;
    state = await _service.redeemPromoCode(code);
    return state.hasPremium && !before;
  }

  Future<void> earnRewardedUnlock(String dayKey) async {
    state = await _service.earnRewardedUnlock(dayKey);
  }

  Future<void> earnRewardedMonthlyUnlock(String monthKey) async {
    state = await _service.earnRewardedMonthlyUnlock(monthKey);
  }

  Future<void> reset() async {
    await _service.reset();
    state = const Entitlement.none();
  }
}

final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, Entitlement>((ref) {
  return EntitlementNotifier(ref.watch(servicesProvider).entitlementService);
});

// ── Profile ───────────────────────────────────────────────────────────

class PrimaryProfileState {
  const PrimaryProfileState({this.profile, this.ready = false, this.error});

  final Profile? profile;
  final bool ready;
  final Object? error;

  bool get hasProfile => profile != null;
}

class PrimaryProfileNotifier extends StateNotifier<PrimaryProfileState> {
  PrimaryProfileNotifier(this._repository, this._calculator)
      : super(const PrimaryProfileState()) {
    _load();
  }

  final ProfileRepository _repository;
  final ZodiacCalculator _calculator;

  Future<void> _load() async {
    try {
      final profile = await _repository.primaryProfile();
      state = PrimaryProfileState(profile: profile, ready: true);
    } catch (e) {
      state = PrimaryProfileState(ready: true, error: e);
    }
  }

  /// Validates + persists a profile; returns a Persian error or null.
  Future<String?> save(Profile profile) async {
    final parsed = parseJalaliDateKey(profile.birthDate);
    if (parsed == null) {
      return 'تاریخ تولد معتبر نیست.';
    }
    final calc =
        _calculator.calculate(Jalali(parsed.year, parsed.month, parsed.day));
    if (calc == null) {
      return 'تاریخ تولد قابل پردازش نیست.';
    }
    try {
      final fixed = profile.zodiacId == calc.sign.id
          ? profile
          : profile.copyWith(zodiacId: calc.sign.id);
      await _repository.saveProfile(fixed);
      await _load();
      return null;
    } catch (_) {
      return 'ذخیرهٔ اطلاعات با خطا مواجه شد. دوباره تلاش کن.';
    }
  }

  Future<void> reload() => _load();

  Future<void> wipe() async {
    await _repository.wipeAll();
    await _load();
  }
}

final primaryProfileProvider =
    StateNotifierProvider<PrimaryProfileNotifier, PrimaryProfileState>((ref) {
  final s = ref.watch(servicesProvider);
  return PrimaryProfileNotifier(s.profileRepository, s.zodiacCalculator);
});

// ── Partner ───────────────────────────────────────────────────────────

class PartnerState {
  const PartnerState({this.partner, this.ready = false});

  final Partner? partner;
  final bool ready;
}

class PartnerNotifier extends StateNotifier<PartnerState> {
  PartnerNotifier(this._repository) : super(const PartnerState());

  final ProfileRepository _repository;
  String? _profileId;

  Future<void> loadFor(String profileId) async {
    _profileId = profileId;
    try {
      final partner = await _repository.partnerForProfile(profileId);
      state = PartnerState(partner: partner, ready: true);
    } catch (_) {
      state = const PartnerState(ready: true);
    }
  }

  Future<String?> save(Partner partner) async {
    if (parseJalaliDateKey(partner.birthDate) == null) {
      return 'تاریخ تولد معتبر نیست.';
    }
    try {
      await _repository.savePartner(partner);
      if (_profileId != null) await loadFor(_profileId!);
      return null;
    } catch (_) {
      return 'ذخیرهٔ اطلاعات با خطا مواجه شد. دوباره تلاش کن.';
    }
  }

  Future<void> remove() async {
    final current = state.partner;
    if (current != null) {
      await _repository.deletePartner(current.id);
    }
    if (_profileId != null) await loadFor(_profileId!);
  }
}

final partnerProvider =
    StateNotifierProvider<PartnerNotifier, PartnerState>((ref) {
  return PartnerNotifier(ref.watch(servicesProvider).profileRepository);
});
