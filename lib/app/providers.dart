import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/seed_data.dart';
import '../data/repositories/archive_repository.dart';
import '../data/repositories/name_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../domain/engines/abjad_engine.dart';
import '../domain/engines/compatibility_engine.dart';
import '../domain/engines/name_search_engine.dart';
import '../domain/engines/numerology_engine.dart';
import '../domain/engines/smart_search_engine.dart';
import '../domain/models/archive_entry.dart';
import '../domain/models/name.dart';
import '../domain/models/privacy_settings.dart';
import '../domain/models/profile.dart';
import '../domain/models/source.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main');
});

final nameRepositoryProvider = Provider<NameRepository>((ref) {
  return NameRepository(ref.watch(databaseProvider));
});

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository(ref.watch(databaseProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});

final nameQueryProvider = StateProvider<String>((ref) => '');

final allNamesProvider = Provider<List<Name>>((ref) {
  return ref.watch(nameRepositoryProvider).search('');
});

final namesProvider = Provider<List<Name>>((ref) {
  return ref.watch(nameRepositoryProvider).search(ref.watch(nameQueryProvider));
});

final sourcesProvider = Provider<List<Source>>((ref) {
  return ref.watch(nameRepositoryProvider).sources();
});

final archiveEntriesProvider = Provider<List<ArchiveEntry>>((ref) {
  return ref.watch(archiveRepositoryProvider).all();
});

final abjadEngineProvider = Provider<AbjadEngine>((ref) {
  return const AbjadEngine(
    mapping: abjadKabirLetters,
    sourceNote: 'نگاشت Phase 1 آزمایشی است و پیش از انتشار باید به Source Claim دانشگاهی/تاریخی متصل شود.',
  );
});

final numerologyEngineProvider = Provider<NumerologyEngine>((ref) => const NumerologyEngine());
final compatibilityEngineProvider = Provider<CompatibilityEngine>((ref) => const CompatibilityEngine());
final nameSearchEngineProvider = Provider<NameSearchEngine>((ref) => const NameSearchEngine());
final smartSearchEngineProvider = Provider<SmartSearchEngine>((ref) => const SmartSearchEngine());

final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<Profile>>((ref) {
  return ProfilesNotifier(ref.watch(profileRepositoryProvider));
});

final privacySettingsProvider = StateNotifierProvider<PrivacySettingsNotifier, PrivacySettings>((ref) {
  return PrivacySettingsNotifier(ref.watch(databaseProvider));
});

class PrivacySettingsNotifier extends StateNotifier<PrivacySettings> {
  PrivacySettingsNotifier(this.database) : super(_read(database));

  final AppDatabase database;

  static PrivacySettings _read(AppDatabase database) {
    final values = database.getPrivacySettings();
    return PrivacySettings(
      analyticsEnabled: values['analytics_enabled'] ?? PrivacySettings.defaults.analyticsEnabled,
      personalizedAdsEnabled: values['personalized_ads_enabled'] ?? PrivacySettings.defaults.personalizedAdsEnabled,
      contentUpdatesEnabled: values['content_updates_enabled'] ?? PrivacySettings.defaults.contentUpdatesEnabled,
    );
  }

  void setAnalyticsEnabled(bool value) {
    database.setPrivacySetting('analytics_enabled', value);
    state = state.copyWith(analyticsEnabled: value);
  }

  void setPersonalizedAdsEnabled(bool value) {
    database.setPrivacySetting('personalized_ads_enabled', value);
    state = state.copyWith(personalizedAdsEnabled: value);
  }

  void setContentUpdatesEnabled(bool value) {
    database.setPrivacySetting('content_updates_enabled', value);
    state = state.copyWith(contentUpdatesEnabled: value);
  }
}

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  ProfilesNotifier(this.repository) : super(repository.all());

  final ProfileRepository repository;

  void save(Profile profile) {
    repository.save(profile);
    state = repository.all();
  }

  void delete(String id) {
    repository.delete(id);
    state = repository.all();
  }
}
