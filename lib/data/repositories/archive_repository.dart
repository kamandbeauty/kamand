import '../../domain/models/archive_entry.dart';
import '../../domain/repositories/archive_repository.dart';
import '../database/app_database.dart';

class ArchiveRepository implements ArchiveRepositoryContract {
  const ArchiveRepository(this.database);

  final AppDatabase database;

  @override
  List<ArchiveEntry> all() => database.getArchiveEntries();
}
