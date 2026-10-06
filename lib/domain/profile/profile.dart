
/// User profile — collected once during onboarding, stored locally.
///
/// Only birth data + optional display name. Nothing else is collected
/// (privacy by design, see product spec §35).
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.birthTimeKnown,
    required this.zodiacId,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.birthTime,
    this.birthCity,
  });

  final String id;

  /// Display name or alias — optional.
  final String name;

  /// Canonical Jalali date "1370-05-12".
  final String birthDate;

  /// "08:30" — null when unknown.
  final String? birthTime;
  final bool birthTimeKnown;
  final String? birthCity;

  final String zodiacId;
  final bool isPrimary;

  /// ISO-ish timestamps (UTC).
  final String createdAt;
  final String updatedAt;

  Profile copyWith({
    String? name,
    String? birthDate,
    String? birthTime,
    bool? birthTimeKnown,
    String? birthCity,
    String? zodiacId,
    String? updatedAt,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        birthTime: birthTime ?? this.birthTime,
        birthTimeKnown: birthTimeKnown ?? this.birthTimeKnown,
        birthCity: birthCity ?? this.birthCity,
        zodiacId: zodiacId ?? this.zodiacId,
        isPrimary: isPrimary,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// "۱۳۷۰/۰۵/۱۲" for display.
  String get birthDateDisplay {
    final parts = birthDate.split('-');
    if (parts.length != 3) return birthDate;
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }
}

/// Romantic partner (single active partner in v1).
class Partner {
  const Partner({
    required this.id,
    required this.profileId,
    required this.name,
    required this.birthDate,
    required this.zodiacId,
    required this.createdAt,
    this.birthTime,
    this.birthCity,
  });

  final String id;

  /// Owning profile id (Profile 1—N Partner).
  final String profileId;
  final String name;
  final String birthDate; // Jalali canonical
  final String? birthTime;
  final String? birthCity;
  final String zodiacId;
  final String createdAt;
}

/// Birth-chart-ready birth data (future premium feature — domain model kept
/// ready per product spec §46; not rendered in v1).
class BirthData {
  const BirthData({
    required this.birthDateKey,
    this.birthTime,
    this.cityName,
  });

  final String birthDateKey;
  final String? birthTime;
  final String? cityName;
}
