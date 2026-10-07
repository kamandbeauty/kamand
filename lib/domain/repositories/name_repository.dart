import '../models/name.dart';
import '../models/name_pronunciation.dart';
import '../models/source.dart';
import '../models/source_claim.dart';

abstract interface class NameRepositoryContract {
  List<Name> search(String query);
  Name? byId(String id);
  List<Source> sources();
  List<SourceClaim> claimsForName(String nameId);
  List<NamePronunciation> pronunciationsForName(String nameId);
}
