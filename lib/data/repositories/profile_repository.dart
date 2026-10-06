import '../../domain/models/profile.dart';
import '../database/app_database.dart';

class ProfileRepository {
  const ProfileRepository(this.database);

  final AppDatabase database;

  List<Profile> all() => database.getProfiles();
  void save(Profile profile) => database.saveProfile(profile);
  void delete(String id) => database.deleteProfile(id);
}
