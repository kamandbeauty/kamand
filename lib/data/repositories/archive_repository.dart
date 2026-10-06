import '../../domain/models/archive_entry.dart';
import '../database/app_database.dart';

class ArchiveRepository {
  const ArchiveRepository(this.database);

  final AppDatabase database;

  List<ArchiveEntry> all() => database.getArchiveEntries();
}
