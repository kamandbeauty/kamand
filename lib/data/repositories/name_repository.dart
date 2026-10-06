import '../../domain/models/name.dart';
import '../../domain/models/source.dart';
import '../database/app_database.dart';

class NameRepository {
  const NameRepository(this.database);

  final AppDatabase database;

  List<Name> search(String query) => database.searchNames(query);
  Name? byId(String id) => database.getName(id);
  List<Source> sources() => database.getSources();
}
