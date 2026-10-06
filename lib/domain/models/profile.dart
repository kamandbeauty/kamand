class Profile {
  const Profile({
    required this.id,
    required this.title,
    required this.name,
    required this.motherName,
    required this.gender,
    required this.birthDate,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String name;
  final String motherName;
  final String gender;
  final String birthDate;
  final String createdAt;

  factory Profile.fromMap(Map<String, Object?> map) {
    return Profile(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'پروفایل',
      name: map['name'] as String? ?? '',
      motherName: map['mother_name'] as String? ?? '',
      gender: map['gender'] as String? ?? 'نامشخص',
      birthDate: map['birth_date'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
