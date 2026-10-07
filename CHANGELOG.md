# Changelog

## 0.1.0-alpha.2 — 2026-10-07

### Added

- Complete local Abjad archive with Kabir, Saghir, Wasit/Medium, Akbar, Wazee and explicit Persian-equivalence variants.
- Versioned Abjad formulas, letter mappings, source/status metadata and a full letter-by-letter archive screen.
- Full name-analysis reports with all Abjad systems, step-by-step calculation, formula, source, status and disclaimer.
- Expanded birth reports with normalized Jalali/Gregorian dates, Abjad total, digital reduction and transparent formulas.
- Expanded source-backed etymology archive for Cyrus, Xerxes, Ardashir, Bahram and Mehrdad, with disputed claims preserved as disputed.
- Name detail pages now show etymology, source trail and the distinction between language history and traditional analysis.

### Verification

- Flutter Analyze: passed.
- Flutter Test: 25 tests passed.
- Android APK Build: passed.

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

### Release status

- This APK is for testing and preview only; it is not store-ready.
- The final brand and application package have not been decided. The current application ID is the temporary development ID `com.kamand.nameology.dev`.
- A real store-release keystore is not configured; the pre-release workflow uses the repository's current development signing setup.
- Abjad, numerology and compatibility outputs are traditional, interpretive and experimental; they are not scientific or deterministic claims about a person, relationship, destiny or future.

### Verification

- `git diff --check`: passed.
- Flutter Analyze/Test/Build require Flutter SDK and are executed by GitHub Actions.
- CI verifies Flutter Analyze, 22 tests and the Android APK build.
