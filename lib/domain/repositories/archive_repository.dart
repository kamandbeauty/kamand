import '../models/archive_entry.dart';

abstract interface class ArchiveRepositoryContract {
  List<ArchiveEntry> all();
}
