import '../../domain/models/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../database/app_database.dart';

class ProfileRepository implements ProfileRepositoryContract {
  const ProfileRepository(this.database);

  final AppDatabase database;

  @override
  List<Profile> all() => database.getProfiles();

  @override
  void save(Profile profile) => database.saveProfile(profile);

  @override
  void delete(String id) => database.deleteProfile(id);
}
