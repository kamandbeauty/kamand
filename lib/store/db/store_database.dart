import 'package:sqlite3/sqlite3.dart';

/// دیتابیس هستهٔ حسابداری فروشگاه — نسخهٔ ۲
///
/// این دیتابیس «حقیقت مالی» برنامه است و جدا از ذخیره‌سازی اسناد فاکتور
/// (که در همان لایهٔ قبلی باقی می‌ماند) عمل می‌کند. همهٔ جداول پولی INTEGER
/// و به تومان هستند. مهاجرت‌ها فقط افزاینده (non-destructive) هستند.
class StoreDatabase {
  static const int schemaVersion = 5;

  final Database db;
  StoreDatabase(this.db) {
    _migrate();
  }

  /// بازکردن دیتابیس روی مسیر فایل
  factory StoreDatabase.open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON;');
    return StoreDatabase(db);
  }

  /// دیتابیس درون‌حافظه‌ای برای تست‌ها
  factory StoreDatabase.inMemory() {
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON;');
    return StoreDatabase(db);
  }

  int get userVersion => db.select('PRAGMA user_version').first['user_version'] as int;

  bool _inTxn = false;

  /// اجرای یک عملیات به‌صورت اتمیک. فراخوانی تودرتو به تراکنش بیرونی می‌پیوندد
  /// تا «همه یا هیچ» بودن جهش‌های مالی/موجودی تضمین شود (قانون طلایی ۵).
  void txn(void Function() body) {
    if (_inTxn) {
      body();
      return;
    }
    db.execute('BEGIN');
    _inTxn = true;
    try {
      body();
      db.execute('COMMIT');
      _inTxn = false;
    } catch (_) {
      _inTxn = false;
      try {
        db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  void _migrate() {
    final current = userVersion;
    if (current >= schemaVersion) return;
    // مهاجرت‌ها فقط جدول/ستون جدید اضافه می‌کنند؛ هیچ DROP/ALTER مخربی انجام نمی‌شود.
    if (current < 1) _v1();
    if (current < 2) _v2();
    if (current < 3) _v3();
    if (current < 4) _v4();
    if (current < 5) _v5();
    db.execute('PRAGMA user_version = $schemaVersion;');
  }

  void _v1() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS financial_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        opening_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS ledger_events (
        id TEXT PRIMARY KEY,
        event_date TEXT NOT NULL,
        event_type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        direction INTEGER NOT NULL DEFAULT 0,
        account_id TEXT,
        customer_id TEXT,
        supplier_id TEXT,
        invoice_id TEXT,
        purchase_id TEXT,
        payment_id TEXT,
        refund_id TEXT,
        installment_id TEXT,
        installment_no INTEGER,
        provider_id TEXT,
        expense_id TEXT,
        transfer_id TEXT,
        reference TEXT DEFAULT '',
        reversal_of TEXT,
        description TEXT DEFAULT '',
        customer_delta INTEGER NOT NULL DEFAULT 0,
        supplier_delta INTEGER NOT NULL DEFAULT 0,
        idempotency_key TEXT UNIQUE,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_date ON ledger_events(event_date);');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_customer ON ledger_events(customer_id);');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_type ON ledger_events(event_type);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS product_stock (
        product_id TEXT PRIMARY KEY,
        current_qty REAL NOT NULL DEFAULT 0,
        min_qty REAL NOT NULL DEFAULT 0,
        avg_cost INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost INTEGER NOT NULL DEFAULT 0,
        ref_type TEXT DEFAULT '',
        ref_id TEXT DEFAULT '',
        note TEXT DEFAULT '',
        movement_date TEXT NOT NULL,
        idempotency_key TEXT UNIQUE,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_mov_product ON stock_movements(product_id);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mobile TEXT DEFAULT '',
        company TEXT DEFAULT '',
        address TEXT DEFAULT '',
        economic_id TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        number TEXT DEFAULT '',
        purchase_date TEXT NOT NULL,
        subtotal INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        shipping INTEGER NOT NULL DEFAULT 0,
        other_costs INTEGER NOT NULL DEFAULT 0,
        tax INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0,
        paid INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT DEFAULT '',
        reversed_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT DEFAULT '',
        title TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT DEFAULT 'عدد',
        unit_price INTEGER NOT NULL DEFAULT 0,
        total_price INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_returns (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        return_date TEXT NOT NULL,
        total INTEGER NOT NULL DEFAULT 0,
        reduce_payable INTEGER NOT NULL DEFAULT 0,
        notes TEXT DEFAULT '',
        reversed_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_return_items (
        id TEXT PRIMARY KEY,
        return_id TEXT NOT NULL,
        purchase_item_id TEXT NOT NULL,
        product_id TEXT DEFAULT '',
        title TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price INTEGER NOT NULL DEFAULT 0,
        total_price INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        purchase_id TEXT,
        amount INTEGER NOT NULL,
        payment_date TEXT NOT NULL,
        account_id TEXT,
        method TEXT DEFAULT 'cash',
        reference TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        reversed_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        expense_date TEXT NOT NULL,
        description TEXT DEFAULT '',
        supplier_id TEXT,
        account_id TEXT,
        reference TEXT DEFAULT '',
        attachment_path TEXT DEFAULT '',
        is_recurring INTEGER NOT NULL DEFAULT 0,
        voided_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS installment_providers (
        id TEXT PRIMARY KEY,
        key TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        provider_type TEXT NOT NULL DEFAULT 'custom',
        commission_bps INTEGER NOT NULL DEFAULT 0,
        commission_fixed INTEGER NOT NULL DEFAULT 0,
        commission_vat_bps INTEGER NOT NULL DEFAULT 0,
        other_deductions INTEGER NOT NULL DEFAULT 0,
        settlement_delay_days INTEGER NOT NULL DEFAULT 0,
        default_installment_count INTEGER NOT NULL DEFAULT 4,
        settlement_frequency TEXT NOT NULL DEFAULT 'per_sale',
        customer_payment_model TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        contract_ref TEXT DEFAULT '',
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS installment_sales (
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        invoice_number TEXT DEFAULT '',
        customer_id TEXT NOT NULL,
        customer_name TEXT DEFAULT '',
        provider_id TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        gross INTEGER NOT NULL DEFAULT 0,
        down_payment INTEGER NOT NULL DEFAULT 0,
        financed INTEGER NOT NULL DEFAULT 0,
        commission INTEGER NOT NULL DEFAULT 0,
        commission_vat INTEGER NOT NULL DEFAULT 0,
        other_deductions INTEGER NOT NULL DEFAULT 0,
        net_settlement INTEGER NOT NULL DEFAULT 0,
        expected_settlement_date TEXT,
        installment_count INTEGER NOT NULL DEFAULT 1,
        first_due_date TEXT NOT NULL,
        frequency_days INTEGER NOT NULL DEFAULT 30,
        status TEXT NOT NULL DEFAULT 'CREATED',
        notes TEXT DEFAULT '',
        cancelled_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS installments (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        number INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        paid_date TEXT,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        payment_ref TEXT DEFAULT '',
        account_id TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_installments_due ON installments(due_date);');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_installments_sale ON installments(sale_id);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS provider_settlements (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        settle_date TEXT NOT NULL,
        account_id TEXT,
        reference TEXT DEFAULT '',
        reversed_at TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS customer_credit_limits (
        customer_id TEXT PRIMARY KEY,
        credit_limit INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS daily_closings (
        id TEXT PRIMARY KEY,
        closing_date TEXT NOT NULL UNIQUE,
        expected_cash INTEGER NOT NULL DEFAULT 0,
        actual_cash INTEGER NOT NULL DEFAULT 0,
        expected_bank INTEGER NOT NULL DEFAULT 0,
        actual_bank INTEGER NOT NULL DEFAULT 0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT DEFAULT '',
        detail TEXT DEFAULT '',
        log_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    _seedExpenseCategories();
    _seedDefaultProviders();
    _seedDefaultAccount();
  }

  void _v2() {
    // نسخهٔ ۲: جداول تضمین یکتایی شمارهٔ فاکتورهای فعال و اسناد فروش آینه‌شده
    db.execute('''
      CREATE TABLE IF NOT EXISTS sales_documents (
        id TEXT PRIMARY KEY,
        source_id TEXT UNIQUE NOT NULL,
        number TEXT NOT NULL,
        customer_id TEXT DEFAULT '',
        customer_name TEXT DEFAULT '',
        doc_type TEXT NOT NULL DEFAULT 'sale',
        doc_date TEXT NOT NULL,
        revenue INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0,
        paid INTEGER NOT NULL DEFAULT 0,
        remaining INTEGER NOT NULL DEFAULT 0,
        shipping_charge INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        cost INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        ledger_version INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_docs_number ON sales_documents(number);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT DEFAULT '',
        title TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT DEFAULT 'عدد',
        unit_price INTEGER NOT NULL DEFAULT 0,
        total_price INTEGER NOT NULL DEFAULT 0,
        unit_cost INTEGER NOT NULL DEFAULT 0,
        doc_date TEXT NOT NULL,
        ledger_version INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_date ON sale_items(doc_date);');
  }

  /// نسخهٔ ۳ — برنامهٔ تسویهٔ چندقسطی درگاه → فروشگاه + درگاه تارا + پیکربندی الگوی تسویه
  void _v3() {
    // زمان‌بندی تسویهٔ هر درگاه (ترب‌پی: پنجرهٔ ۱–۵ ماه‌های بعد، تارا: ۳۰/۶۰ روز، باسلام: درصد اول + بقیه)
    db.execute('''
      CREATE TABLE IF NOT EXISTS settlement_schedule (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        number INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        expected_date TEXT NOT NULL,
        received_amount INTEGER NOT NULL DEFAULT 0,
        received_date TEXT,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL
      );
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_settlement_schedule_date ON settlement_schedule(expected_date);');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_settlement_schedule_provider ON settlement_schedule(provider_id);');
    // ستون‌های پیکربندی الگوی تسویهٔ درگاه‌ها (افزاینده)
    db.execute(
        "ALTER TABLE installment_providers ADD COLUMN schedule_type TEXT NOT NULL DEFAULT 'monthly_window';");
    db.execute(
        'ALTER TABLE installment_providers ADD COLUMN settlement_day INTEGER NOT NULL DEFAULT 3;');
    db.execute(
        'ALTER TABLE installment_providers ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 30;');
    db.execute(
        'ALTER TABLE installment_providers ADD COLUMN first_percent_bps INTEGER NOT NULL DEFAULT 0;');
    db.execute(
        'ALTER TABLE installment_providers ADD COLUMN subsequent_count INTEGER NOT NULL DEFAULT 0;');
    // پیوند ثبت تسویه با قسط مربوطه
    db.execute(
        'ALTER TABLE provider_settlements ADD COLUMN schedule_id TEXT;');

    // درگاه تارا: ۲ قسط با فاصلهٔ ۳۰ روزه (۳۰/۶۰ روز بعد)، تسهیم مساوی
    db.execute(
      "INSERT OR IGNORE INTO installment_providers "
      "(id, key, name, provider_type, default_installment_count, created_at, schedule_type, interval_days) "
      "VALUES ('prov-tara', 'tara', 'تارا', 'tara', 2, ?, 'fixed_interval', 30)",
      [DateTime.now().toIso8601String()],
    );
    // پیش‌فرض‌های الگوی تسویهٔ درگاه‌های موجود (فقط وقتی مقدار پیش‌فرض است)
    db.execute(
        "UPDATE installment_providers SET schedule_type = 'monthly_window', settlement_day = 3 "
        "WHERE key IN ('torob_pay','snapp_pay','digipay')");
    db.execute(
        "UPDATE installment_providers SET schedule_type = 'basalam', settlement_day = 3, "
        "first_percent_bps = 5000, subsequent_count = 4, settlement_delay_days = 10 "
        "WHERE key = 'basalam' AND first_percent_bps = 0");
    // ترب‌پی: پیش‌فرض ۴ قسط تسویه
    db.execute(
        "UPDATE installment_providers SET default_installment_count = 4 WHERE key = 'torob_pay'");
  }

  /// نسخهٔ ۴ — چک‌ها در دریافت/پرداخت + جدول cheques
  void _v4() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS cheques (
        id TEXT PRIMARY KEY,
        direction TEXT NOT NULL,              -- received | issued
        amount INTEGER NOT NULL,
        cheque_number TEXT NOT NULL,
        sayadi_number TEXT DEFAULT '',
        holder_name TEXT DEFAULT '',
        bank_name TEXT DEFAULT '',
        due_date TEXT NOT NULL,
        counterparty_id TEXT DEFAULT '',
        counterparty_name TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'HELD',  -- HELD | CLEARED | BOUNCED | PASSED_ON | CANCELLED
        cleared_date TEXT,
        cleared_account_id TEXT,
        notes TEXT DEFAULT '',
        ledger_event_id TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_cheques_due ON cheques(due_date);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_cheques_status ON cheques(status);');
  }

  /// نسخهٔ ۵ — سفارشات (ارسال‌نشده / ارسال‌شده)
  void _v5() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        number TEXT DEFAULT '',
        customer_id TEXT DEFAULT '',
        customer_name TEXT NOT NULL,
        customer_phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        order_date TEXT NOT NULL,
        items_json TEXT NOT NULL DEFAULT '[]',
        subtotal INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        shipping INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',  -- PENDING | SHIPPED | CANCELLED
        sent_date TEXT,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);');
  }

  void _seedExpenseCategories() {
    final rows = db.select('SELECT COUNT(*) AS c FROM expense_categories').first;
    if ((rows['c'] as int) > 0) return;
    const defaults = [
      ['PACKAGING', 'بسته‌بندی', 1],
      ['SHIPPING', 'حمل و ارسال', 2],
      ['PURCHASE', 'خرید کالا', 3],
      ['RENT', 'اجاره', 4],
      ['SALARY', 'دستمزد و حقوق', 5],
      ['UTILITIES', 'آب و برق و تلفن', 6],
      ['OTHER', 'سایر', 99],
    ];
    for (final e in defaults) {
      db.execute(
        'INSERT OR IGNORE INTO expense_categories (key, title, is_system, sort) VALUES (?, ?, ?, ?)',
        // e = [key, title, sort] — همهٔ دسته‌های پیش‌فرض سیستمی هستند (is_system=1)
        [e[0], e[1], 1, e[2]],
      );
    }
  }

  /// سیستم‌های اقساطی پیش‌فرض — فقط به‌عنوان پیکربندی خاموش/نرخ‌صفر ساخته می‌شوند.
  /// طبق §21 تا §25: هیچ نرخ کارمزد واقعی hard-code نمی‌شود؛ فروشنده باید نرخ
  /// قرارداد خودش را در UI تنظیم کند.
  void _seedDefaultProviders() {
    final rows =
        db.select('SELECT COUNT(*) AS c FROM installment_providers').first;
    if ((rows['c'] as int) > 0) return;
    final now = DateTime.now().toIso8601String();
    const providers = [
      ['snapp_pay', 'اسنپ‌پی', 'snapp_pay'],
      ['torob_pay', 'ترب‌پی', 'torob_pay'],
      ['digipay', 'دیجی‌پی', 'digipay'],
      ['basalam', 'باسلام', 'basalam'],
      ['store_direct', 'اقساط مستقیم فروشگاه', 'store'],
    ];
    for (final p in providers) {
      db.execute(
        'INSERT OR IGNORE INTO installment_providers '
        '(id, key, name, provider_type, default_installment_count, created_at) '
        "VALUES (?, ?, ?, ?, ?, ?)",
        [
          'prov-${p[0]}',
          p[0],
          p[1],
          p[2],
          p[0] == 'store_direct' ? 2 : 4,
          now,
        ],
      );
    }
  }

  void _seedDefaultAccount() {
    final rows =
        db.select("SELECT COUNT(*) AS c FROM financial_accounts WHERE type = 'cash'")
            .first;
    if ((rows['c'] as int) > 0) return;
    db.execute(
      'INSERT INTO financial_accounts (id, name, type, opening_balance, is_active, created_at) '
      "VALUES ('acc-cash', 'صندوق فروشگاه', 'cash', 0, 1, ?)",
      [DateTime.now().toIso8601String()],
    );
  }

  void close() => db.dispose();
}
