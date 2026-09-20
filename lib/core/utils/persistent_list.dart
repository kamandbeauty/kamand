import 'package:flutter_riverpod/flutter_riverpod.dart';

/// تابع تغییر یک لیست پایدار. خروجی، لیست تازه است و ورودی نباید تغییر کند.
typedef ListMutation<T> = List<T> Function(List<T> current);

/// پایه‌ی مشترک نگه‌دارنده‌های لیستی که روی حافظه‌ی دستگاه ذخیره می‌شوند.
///
/// چرا این کلاس لازم شد؟ در نسخه‌ی ۱.۰.۷ هر نوتیفایر هم به‌صورت «خوش‌بینانه»
/// روی وضعیت جاری تغییر می‌داد و هم پس از پایان خواندن اولیه
/// (`_hydrated.then(...)`) همان تغییر را دوباره اعمال و ذخیره می‌کرد. برای
/// کاربرانی که از نسخه‌ی قدیمی به‌روزرسانی می‌کنند این دو ایراد جدی داشت:
///
///   ۱) تغییرهای تجمعی مثل `balance = balance + delta` دو بار حساب می‌شدند؛
///      یعنی پرداخت‌ها دو برابر و مانده‌حساب‌ها اشتباه می‌شدند.
///   ۲) نوشتن روی دیسک پیش از پایان خواندن اولیه می‌توانست داده‌ی
///      ذخیره‌شده‌ی کاربر را با یک لیست ناقص بازنویسی کند (از دست رفتن
///      فاکتورها/مشتری‌ها فقط با باز کردن نسخه‌ی جدید).
///
/// تضمین‌های این کلاس:
///   • تغییرهای کاربر پیش از پایان خواندن اولیه گم نمی‌شوند، چون در صف
///     می‌مانند و دقیقاً یک بار روی داده‌ی ذخیره‌شده اجرا و ذخیره می‌شوند.
///   • هر تغییر فقط یک بار به حساب می‌آید (بدون اعمال دوباره).
///   • نوشتن‌ها سری و به ترتیب انجام می‌شوند؛ هیچ snapshot قدیمی روی
///     snapshot تازه نمی‌نشیند و آخرین تغییر همیشه برنده است.
///   • خطای خواندن یا نوشتن، برنامه را از کار نمی‌اندازد و داده‌ی موجود
///     را پاک نمی‌کند.
abstract class PersistentListNotifier<T> extends StateNotifier<List<T>> {
  PersistentListNotifier() : super(const []) {
    _ready = _hydrate();
  }

  late final Future<void> _ready;
  final List<ListMutation<T>> _pending = <ListMutation<T>>[];
  Future<void> _writeChain = Future<void>.value();
  bool _hydrated = false;
  bool _disposed = false;

  /// داده‌های ذخیره‌شده را از حافظه‌ی دستگاه می‌خواند.
  Future<List<T>> readFromStorage();

  /// کل لیست را روی حافظه‌ی دستگاه می‌نویسد.
  Future<void> writeToStorage(List<T> items);

  /// پایان خواندن اولیه. صفحه‌هایی که باید مطمئن باشند داده رسیده است
  /// این متد را `await` می‌کنند.
  Future<void> ensureLoaded() => _ready;

  /// آیا داده‌ی ذخیره‌شده خوانده شده است؟
  bool get isHydrated => _hydrated;

  /// پایان یافتن همه‌ی نوشتن‌های در صف (مناسب برای تست و پشتیبان‌گیری).
  Future<void> flushWrites() => _writeChain;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _hydrate() async {
    List<T> loaded;
    try {
      loaded = await readFromStorage();
    } catch (_) {
      // اگر خواندن شکست خورد، لیست خالی آغاز می‌شود اما هیچ چیز پاک نمی‌شود.
      loaded = <T>[];
    }

    final pending = List<ListMutation<T>>.from(_pending);
    _pending.clear();
    for (final mutation in pending) {
      try {
        loaded = mutation(loaded);
      } catch (_) {
        // تغییر نامعتبر نباید کل بارگذاری را خراب کند.
      }
    }

    _hydrated = true;
    if (_disposed) return;
    state = loaded;
    if (pending.isNotEmpty) {
      // تغییرهایی که پیش از رسیدن داده‌ی ذخیره‌شده انجام شده‌اند، همان‌جا
      // روی داده‌ی نهایی اعمال و ذخیره می‌شوند تا گم نشوند.
      await _writeDirect(loaded);
    }
  }

  Future<void> _writeDirect(List<T> snapshot) async {
    try {
      await writeToStorage(snapshot);
    } catch (_) {}
  }

  Future<void> _enqueueWrite(List<T> snapshot) {
    final next = _writeChain.then((_) async {
      if (_disposed) return;
      await _writeDirect(snapshot);
    });
    _writeChain = next;
    return next;
  }

  /// تغییر روی لیست. دقیقاً یک بار اعمال و ذخیره می‌شود.
  void mutate(ListMutation<T> mutation) {
    if (_disposed) return;
    if (_hydrated) {
      final next = mutation(state);
      state = next;
      _enqueueWrite(next);
      return;
    }
    // پیش از پایان خواندن اولیه: برای واکنش فوری رابط کاربری روی وضعیت فعلی
    // اعمال می‌شود و در صف می‌ماند تا روی داده‌ی ذخیره‌شده هم اجرا شود.
    _pending.add(mutation);
    state = mutation(state);
  }

  /// نسخه‌ی انتظارپذیر [mutate]؛ تا پایان ذخیره‌سازی صبر می‌کند.
  Future<void> mutateAsync(ListMutation<T> mutation) async {
    await _ready;
    mutate(mutation);
    await _writeChain;
  }

  /// جایگزینی کامل داده، مثلاً بازگردانی پشتیبان.
  Future<void> replaceAll(List<T> items) async {
    await _ready;
    if (_disposed) return;
    state = items;
    await _enqueueWrite(items);
  }
}
