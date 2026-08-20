import 'engine_events.dart';

/// شنوندهٔ رویدادهای موتور — لایهٔ Controller/Animation این را پیاده می‌کند.
abstract class GameEventListener {
  void onGameEvent(GameEvent event);
}
