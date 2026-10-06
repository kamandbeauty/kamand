import '../../domain/models/name.dart';
import '../../domain/models/source.dart';
import '../../domain/repositories/name_repository.dart';
import '../database/app_database.dart';

class NameRepository implements NameRepositoryContract {
  const NameRepository(this.database);

  final AppDatabase database;

  @override
  List<Name> search(String query) => database.searchNames(query);

  @override
  Name? byId(String id) => database.getName(id);

  @override
  List<Source> sources() => database.getSources();
}
