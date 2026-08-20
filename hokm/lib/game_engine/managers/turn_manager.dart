import '../state/game_enums.dart';

/// مدیریت چرخهٔ نوبت — بدون وابستگی به UI.
class TurnManager {
  TurnManager({required Seat leader}) : _current = leader;

  Seat _current;

  Seat get current => _current;

  /// نفر بعدی در جهت چرخش نوبت.
  Seat advance() {
    _current = _current.next;
    return _current;
  }

  /// نوبت را به یک جایگاه مشخص می‌دهد (مثلاً برندهٔ دور).
  void setCurrent(Seat seat) => _current = seat;

  Map<String, dynamic> toJson() => {'current': _current.index};

  void restore(int seatIndex) => _current = Seat.fromIndex(seatIndex);
}
