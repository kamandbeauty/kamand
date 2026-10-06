# Changelog

## 0.1.0-alpha.1 — 2026-10-07

### Added

- Nameology MVP with Persian RTL navigation and local SQLite storage.
- Sourced name knowledge base, Source Registry and Source Claims.
- FTS5 search and Persian Smart Search filters.
- Database-backed Abjad Mapping with unknown-letter protection.
- Database-backed Numerology Rule with explicit `unverified` status.
- Jalali/Gregorian date conversion and validation.
- Birth Analysis with Formula, Rule, status and disclaimer display.
- Local profiles with validated birth calendar metadata.
- Name and local-profile comparison using the versioned written-form Rule.
- Offline privacy settings and local-only profile storage.
- Android quality workflow and tag-based GitHub Release workflow.

### Safety and content policy

- No deterministic claims about personality, destiny, relationships or future are generated.
- No numeric Interpretation is seeded without a reviewed source.
- Unverified and disputed data remain visibly labeled.
- The Android application ID is temporary development identity: `com.kamand.nameology.dev`.

### Verification

- `git diff --check`: passed.
- Flutter Analyze/Test/Build require Flutter SDK and are executed by GitHub Actions.
- APK release signing is not configured for store distribution; the pre-release workflow uses the repository's current development signing setup.
