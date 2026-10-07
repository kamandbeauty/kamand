# Changelog

## 0.1.0-alpha.4 — 2026-10-07

### Added

- Schema 9 provenance fields for sourced pronunciation records.
- Integrity audit for orphan relations, missing sources, invalid subjects and normalized duplicates.
- Imported 8,816 name forms and source gender labels from the MIT-licensed `nabidam/persian-names` dataset at commit `68f5cb39a25c19ecaf6f60f3181aea200f8206f`.
- Dataset imports keep meaning, etymology, transliteration and pronunciation as Unknown until independently sourced.
- Upstream MIT license and attribution are preserved in `third_party/persian_names`.

### Verification

- Dataset provenance and duplicate normalization are recorded in SQLite Source Claims.
- Flutter Analyze, 26 tests and Android APK Build pass in CI.

## 0.1.0-alpha.3 — 2026-10-07

### Added

- Schema 8 source registry with license, coverage, access date and editorial review status.
- Expanded source bank with Iranica Parthian/Sasanian/Anahid records, Wiktionary, Wikidata, Dehkhoda, Oxford and auxiliary references.
- Knowledge content pack `knowledge-3` with 120+ traceable Persian/Iranian names, meanings, Latin variants, language/culture metadata and independent pending Claims. (Superseded by `knowledge-4` dataset expansion.)
- Source catalog overview with name, meaning and source coverage metrics.
- Community-sourced meanings remain `unverified`/`pending`; no community list is presented as a verified etymological authority.

### Verification

- Database migration and content seed tests updated for Schema 8/9 and `knowledge-3`/`knowledge-4`.
- Flutter Analyze/Test/Android Build run in CI after push.

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
