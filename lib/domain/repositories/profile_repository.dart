import '../models/profile.dart';

abstract interface class ProfileRepositoryContract {
  List<Profile> all();
  void save(Profile profile);
  void delete(String id);
}
