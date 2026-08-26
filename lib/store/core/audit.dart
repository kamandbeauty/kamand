import '../db/store_database.dart';

/// لاگ حسابرسی — هر عملیات مهم ثبت و هرگز فیزیکی حذف نمی‌شود (§40)
class AuditLog {
  final StoreDatabase store;
  AuditLog(this.store);

  void log(String action, String entity, String entityId, [String detail = '']) {
    store.db.execute(
      'INSERT INTO audit_log (id, action, entity, entity_id, detail, log_date, created_at) '
      'VALUES (?,?,?,?,?,?,?)',
      [
        'au-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
        action,
        entity,
        entityId,
        detail,
        _today(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  List<Map<String, Object?>> recent({int limit = 200}) => store.db.select(
      'SELECT * FROM audit_log ORDER BY created_at DESC LIMIT ?', [limit]);

  String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static int _seq = 0;
}
