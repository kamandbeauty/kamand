import '../models/name.dart';
import '../models/source.dart';
import '../models/source_claim.dart';

abstract interface class NameRepositoryContract {
  List<Name> search(String query);
  Name? byId(String id);
  List<Source> sources();
}
