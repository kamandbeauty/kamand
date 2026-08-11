import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../customer/customer_list_screen.dart';
import '../product/product_list_screen.dart';
import '../financial/financial_dashboard_screen.dart';
import '../settings/settings_screen.dart';
import '../invoice/invoice_list_screen.dart';
import '../customize/header_customize_screen.dart';
import '../card/card_list_sheet.dart';
import '../invoice/invoice_preview_screen.dart';
import '../../providers/bank_card_provider.dart';
import '../../core/utils/replace_on_type_field.dart';

// ──────────────────────────────────────────────────────────────
// Home — فاکتور ساز روبی — چیدمان دقیقاً مطابق اسکرین‌شات فیدا
// اما با هویت روبی (نارنجی #F97316، لوگو روبی، بدون کپی رنگ/لوگو فیدا)
// ──────────────────────────────────────────────────────────────
const _orange = AppTheme.RubyPrimary;
const _orangeLight = AppTheme.RubyPrimaryContainer;
const _bg = AppTheme.bgLight; // #FFFBEB
const _cardGray = Color(0xFFF1F5F9); // خاکستری کارت های فرم (عکس)
const _cardGrayBorder = Color(0xFFE2E8F0);
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate600 = Color(0xFF475569);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);
const _slate900 = Color(0xFF0F172A);

class DashboardScreen extends ConsumerStatefulWidget {
  /// اگر مقدار داشته باشد، فرم هوم همان فاکتور را برای ویرایش باز می‌کند
  final InvoiceModel? editInvoice;
  const DashboardScreen({super.key, this.editInvoice});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // کنترلرهای پایدار — جلوگیری از پرش فوکوس هنگام تایپ
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;

  // Form state — متصل به دیتابیس واقعی (§29)
  String? _editId;
  String _customerName = '';
  String _customerPhone = '';
  String _invoiceNumber = '۱';
  String _dateLabel = '';
  List<InvoiceItemModel> _items = [];
  bool _hasShipping = false;
  bool _hasDiscount = false;
  bool _discountIsPercent = false; // false= مبلغ (آبی), true= درصد
  bool _hasDeposit = false;
  bool _hasPrevDebt = false;
  String _invoiceType = 'proforma'; // proforma / purchase / sale
  String _paymentType = 'cash'; // cash / non_cash
  String _notes = '';
  double _discountAmount = 0;
  double _shippingFee = 0;
  double _depositAmount = 0;
  double _prevDebtAmount = 0;
  int? _selectedRow;
  /// با هر بار load ویرایش افزایش می‌یابد تا فیلدهای جدول دوباره ساخته شوند
  int _formGen = 0;

  bool get _isEditing => _editId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _dateLabel = _todayLabel();
    // یک ردیف پیش‌فرض مثل عکس (۱ عدد)
    _items = [
      InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ویرایش مستقیم از constructor
      if (widget.editInvoice != null) {
        _loadInvoiceForEdit(widget.editInvoice!);
        return;
      }
      // ویرایش از provider (از صفحه پیش‌نمایش / لیست)
      final req = ref.read(invoiceEditRequestProvider);
      if (req != null) {
        ref.read(invoiceEditRequestProvider.notifier).state = null;
        _loadInvoiceForEdit(req);
        return;
      }
      final settings = ref.read(settingsProvider);
      if (settings.startingInvoiceNum > 0) {
        setState(() => _invoiceNumber =
            PersianNumberFormatter.toPersian(settings.startingInvoiceNum.toString()));
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncTextControllers() {
    if (_nameCtrl.text != _customerName) {
      _nameCtrl.value = TextEditingValue(
        text: _customerName,
        selection: TextSelection.collapsed(offset: _customerName.length),
      );
    }
    if (_phoneCtrl.text != _customerPhone) {
      _phoneCtrl.value = TextEditingValue(
        text: _customerPhone,
        selection: TextSelection.collapsed(offset: _customerPhone.length),
      );
    }
    if (_notesCtrl.text != _notes) {
      _notesCtrl.value = TextEditingValue(
        text: _notes,
        selection: TextSelection.collapsed(offset: _notes.length),
      );
    }
  }

  /// پر کردن فرم هوم با داده فاکتور برای ویرایش (همان UI داشبورد)
  void _loadInvoiceForEdit(InvoiceModel e) {
    setState(() {
      _editId = e.id;
      _customerName = e.customerName == 'مشتری عمومی' ? '' : e.customerName;
      _customerPhone = e.customerPhone;
      _invoiceNumber = PersianNumberFormatter.toPersian(e.number);
      _dateLabel = e.date.isNotEmpty ? PersianNumberFormatter.toPersian(e.date) : _todayLabel();
      _items = e.items.isEmpty
          ? [InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0)]
          : e.items
              .map(
                (it) => InvoiceItemModel(
                  id: it.id,
                  title: it.title,
                  quantity: it.quantity,
                  unit: it.unit,
                  unitPrice: it.unitPrice,
                  totalPrice: it.totalPrice,
                ),
              )
              .toList();
      _invoiceType = e.type;
      _paymentType = e.paymentType;
      _hasDiscount = e.discountAmount > 0;
      _discountAmount = e.discountPercent > 0 ? e.discountPercent : e.discountAmount;
      _discountIsPercent = e.discountPercent > 0;
      _hasShipping = e.shippingFee > 0;
      _shippingFee = e.shippingFee;
      _hasDeposit = e.deposit > 0;
      _depositAmount = e.deposit;
      _hasPrevDebt = e.previousDebt > 0;
      _prevDebtAmount = e.previousDebt;
      _notes = e.notes;
      _selectedRow = null;
      _formGen++;
      _syncTextControllers();
    });
  }

  void _resetFormForNew({String? nextNumberFa}) {
    setState(() {
      _editId = null;
      _customerName = '';
      _customerPhone = '';
      if (nextNumberFa != null) _invoiceNumber = nextNumberFa;
      _dateLabel = _todayLabel();
      _items = [
        InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0),
      ];
      _hasShipping = false;
      _hasDiscount = false;
      _hasDeposit = false;
      _hasPrevDebt = false;
      _discountAmount = 0;
      _shippingFee = 0;
      _depositAmount = 0;
      _prevDebtAmount = 0;
      _notes = '';
      _selectedRow = null;
      _invoiceType = 'proforma';
      _paymentType = 'cash';
      _formGen++;
      _syncTextControllers();
    });
  }

  String _todayLabel() {
    final jalali = JalaliHelper.getTodayJalali(); // 1405/05/20
    // نمایش مثل عکس: دوشنبه ۱۹ مرداد ۱۴۰۵
    // Hilal: فعلاً همان تاریخ عددی فارسی را نمایش میدهیم + روز هفته تقریبی
    final parts = jalali.split('/');
    if (parts.length == 3) {
      final months = ['', 'فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
      final m = int.tryParse(parts[1]) ?? 1;
      final d = PersianNumberFormatter.toPersian(parts[2]);
      final y = PersianNumberFormatter.toPersian(parts[0]);
      return '$d ${months[m]} $y';
    }
    return PersianNumberFormatter.toPersian(jalali);
  }

  double get _itemsTotal => _items.fold(0, (s, e) => s + e.totalPrice);

  /// مبلغ تخفیف واقعی (درصد یا مبلغ ثابت)
  double get _resolvedDiscount {
    if (!_hasDiscount) return 0;
    if (_discountIsPercent) {
      return (_itemsTotal * (_discountAmount.clamp(0, 100)) / 100);
    }
    return _discountAmount < 0 ? 0 : _discountAmount;
  }

  double get _shippingVal => _hasShipping ? _shippingFee : 0;
  double get _prevDebtVal => _hasPrevDebt ? _prevDebtAmount : 0;
  double get _depositVal => _hasDeposit ? _depositAmount : 0;

  /// جمع قبل از بیعانه = اقلام − تخفیف + ارسال + بدهی قبلی
  double get _grossTotal {
    final t = _itemsTotal - _resolvedDiscount + _shippingVal + _prevDebtVal;
    return t < 0 ? 0 : t;
  }

  /// مبلغ قابل پرداخت نهایی (بیعانه کم می‌شود)
  double get _finalTotal {
    final t = _grossTotal - _depositVal;
    return t < 0 ? 0 : t;
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        quantity: 1,
        unit: 'عدد',
        unitPrice: 0,
        totalPrice: 0,
      ));
      _selectedRow = _items.length - 1;
    });
  }

  void _removeRow(int idx) {
    setState(() {
      _items.removeAt(idx);
      if (_items.isEmpty) {
        _items.add(InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0));
      }
      if (_selectedRow == idx) {
        _selectedRow = null;
      } else if (_selectedRow != null && _selectedRow! > idx) {
        _selectedRow = _selectedRow! - 1;
      }
    });
  }

  void _updateItem(int idx, {String? title, double? qty, String? unit, double? price}) {
    final old = _items[idx];
    final newQty = qty ?? old.quantity;
    final newPrice = price ?? old.unitPrice;
    setState(() {
      _items[idx] = InvoiceItemModel(
        id: old.id,
        title: title ?? old.title,
        quantity: newQty,
        unit: unit ?? old.unit,
        unitPrice: newPrice,
        totalPrice: newQty * newPrice,
      );
    });
  }

  void _saveInvoice() {
    final cleanItems = _items
        .where((e) => e.title.trim().isNotEmpty || e.unitPrice > 0 || e.totalPrice > 0)
        .toList();
    if (cleanItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک قلم کالا با عنوان یا قیمت اضافه کنید')),
      );
      return;
    }
    if (_finalTotal <= 0 && cleanItems.every((e) => e.unitPrice <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قیمت اقلام را وارد کنید')),
      );
      return;
    }

    final selectedCard = ref.read(selectedBankCardProvider);
    final biz = ref.read(businessProvider);
    final card = selectedCard?.cardNumber ??
        (biz.bankCards.isNotEmpty ? biz.bankCards.first : '');

    String numEn = _faToEn(_invoiceNumber);
    final jalaliEn = JalaliHelper.getTodayJalali();
    // اگر در حالت ویرایش تاریخ قبلی را نگه داریم
    final dateToStore = _isEditing && _dateLabel.isNotEmpty
        ? _faToEn(_dateLabel.replaceAll('-', '/'))
        : jalaliEn;
    final jalaliFa = PersianNumberFormatter.toPersian(dateToStore);

    InvoiceModel? existing;
    if (_editId != null) {
      for (final i in ref.read(invoiceListProvider)) {
        if (i.id == _editId) {
          existing = i;
          break;
        }
      }
    }

    // totalAmount = مبلغ قابل پرداخت نهایی (بعد از کسر بیعانه)
    // paidAmount: نقدی = کل؛ غیرنقدی = بیعانه (که از total کم شده)
    final depositAmt = _depositVal;
    final payable = _finalTotal;
    final finalRemaining = _paymentType == 'cash' ? 0.0 : payable;
    final finalPaid = _paymentType == 'cash' ? payable : depositAmt;

    final inv = InvoiceModel(
      id: _editId ?? 'inv-${DateTime.now().millisecondsSinceEpoch}',
      number: numEn,
      customerId: existing?.customerId ?? 'c-${DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerName.trim().isEmpty ? 'مشتری عمومی' : _customerName.trim(),
      customerPhone: _customerPhone.trim(),
      type: _invoiceType == 'sale'
          ? 'sale'
          : (_invoiceType == 'purchase' ? 'purchase' : 'proforma'),
      paymentType: _paymentType,
      status: _invoiceType == 'proforma'
          ? 'proforma'
          : (finalRemaining <= 0 ? 'paid' : (finalPaid > 0 ? 'partial' : 'unpaid')),
      date: jalaliFa,
      items: cleanItems,
      subtotal: _itemsTotal,
      discountPercent: _discountIsPercent ? _discountAmount : 0,
      discountAmount: _resolvedDiscount,
      shippingFee: _shippingVal,
      previousDebt: _prevDebtVal,
      deposit: depositAmt,
      totalAmount: payable,
      paidAmount: finalPaid.toDouble(),
      remainingAmount: finalRemaining.toDouble(),
      notes: _notes,
      cardNumber: card.isNotEmpty ? card : (existing?.cardNumber ?? ''),
      createdAt: existing?.createdAt ?? jalaliFa,
    );

    ref.read(invoiceListProvider.notifier).saveInvoice(inv);

    // آماده‌سازی فرم برای فاکتور بعدی
    final nextNum = (int.tryParse(numEn) ?? 1004) + 1;
    _resetFormForNew(
      nextNumberFa: PersianNumberFormatter.toPersian(nextNum.toString()),
    );

    // باز کردن صفحه نمایش فاکتور + اشتراک
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(invoice: inv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final business = ref.watch(businessProvider);
    final shopName = business.shopName.isNotEmpty ? business.shopName : 'فاکتور ساز روبی';

    // گوش دادن به درخواست ویرایش از صفحات دیگر
    ref.listen<InvoiceModel?>(invoiceEditRequestProvider, (prev, next) {
      if (next != null) {
        ref.read(invoiceEditRequestProvider.notifier).state = null;
        _loadInvoiceForEdit(next);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: dark ? _slate900 : Colors.white,
      drawer: _buildDrawer(),
      // هدر: در حالت ویرایش عنوان «ویرایش فاکتور» + دکمه انصراف
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: dark ? _slate800 : (_isEditing ? _orange : Colors.white),
          elevation: 0,
          centerTitle: true,
          leadingWidth: 48,
          leading: _isEditing
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    final settings = ref.read(settingsProvider);
                    _resetFormForNew(
                      nextNumberFa: PersianNumberFormatter.toPersian(
                        settings.startingInvoiceNum.toString(),
                      ),
                    );
                  },
                  tooltip: 'انصراف از ویرایش',
                )
              : InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 22),
                      ),
                    ),
                  ),
                ),
          title: Text(
            _isEditing
                ? 'ویرایش فاکتور #${PersianNumberFormatter.toPersian(_invoiceNumber)}'
                : shopName,
            style: TextStyle(
              color: _isEditing || dark ? Colors.white : _slate800,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          actions: [
            if (_isEditing)
              TextButton(
                onPressed: _saveInvoice,
                child: const Text(
                  'ذخیره',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              )
            else
              IconButton(
                icon: Icon(Icons.menu, color: dark ? Colors.white : _slate700),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: dark ? _slate700 : _cardGrayBorder),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          key: ValueKey('form-$_formGen'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) تنظیمات فاکتور / سربرگ
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HeaderCustomizeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'تنظیمات فاکتور',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2) کارت اطلاعات مشتری — کنترلر پایدار (بدون پرش فوکوس)
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  _stableCustomerField(
                    label: 'نام مشتری:',
                    controller: _nameCtrl,
                    hint: 'مثلاً: رضا محمدی',
                    dark: dark,
                    keyboardType: TextInputType.name,
                    onChanged: (v) => _customerName = v,
                  ),
                  const SizedBox(height: 10),
                  _stableCustomerField(
                    label: 'شماره همراه مشتری:',
                    controller: _phoneCtrl,
                    hint: '۰۹۱۲…',
                    dark: dark,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => _customerPhone = v,
                  ),
                  const SizedBox(height: 10),
                  Divider(color: dark ? _slate700 : _cardGrayBorder, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'شماره فاکتور:',
                              style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              PersianNumberFormatter.toPersian(_invoiceNumber),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : _slate800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                'تاریخ: $_dateLabel',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dark ? Colors.white : _slate800,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3) جدول اقلام
            Container(
              decoration: BoxDecoration(
                color: dark? _slate800: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark? _slate700: _cardGrayBorder),
              ),
              child: Column(
                children: [
                  // هدر جدول — ترتیب RTL: عنوان | مقدار | واحد | قیمت واحد | قیمت کل
                  Container(
                    decoration: BoxDecoration(
                      color: dark? _slate700.withValues(alpha: 0.4): const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: dark? _slate700: _cardGrayBorder)),
                    ),
                    child: Row(
                      children: [
                        // عنوان پهن‌تر برای نام محصول
                        _tableHeader('عنوان', flex: 5, dark: dark),
                        _tableHeader('مقدار', flex: 1, dark: dark),
                        _tableHeader('واحد', flex: 1, dark: dark),
                        _tableHeader('قیمت واحد', flex: 2, dark: dark),
                        _tableHeader('قیمت کل', flex: 2, dark: dark, isLast: true),
                      ],
                    ),
                  ),
                  // ردیف‌ها — شماره ردیف غیرقابل ادیت + ضربدر حذف با کلیک
                  ...List.generate(_items.length, (idx) {
                    final it = _items[idx];
                    final isSelected = _selectedRow == idx;
                    final rowNum = PersianNumberFormatter.toPersian((idx + 1).toString());
                    return InkWell(
                      onTap: () => setState(() => _selectedRow = idx),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? _orange.withValues(alpha: 0.06) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: dark? _slate700: _cardGrayBorder)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // عنوان + شماره ردیف — فضای بیشتر برای نام محصول
                              _tableCell(
                                flex: 5,
                                dark: dark,
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Row(
                                    children: [
                                      if (isSelected)
                                        InkWell(
                                          onTap: () => _removeRow(idx),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4),
                                            child: Icon(Icons.close, size: 18, color: _slate500),
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 8),
                                      Text(
                                        rowNum,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: dark ? _slate400 : _slate500,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller: TextEditingController(text: it.title)
                                            ..selection = TextSelection.collapsed(offset: it.title.length),
                                          onChanged: (v) => _updateItem(idx, title: v),
                                          onTap: () => setState(() => _selectedRow = idx),
                                          textDirection: TextDirection.rtl,
                                          textAlign: TextAlign.right,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: 'نام کالا / خدمت',
                                            hintTextDirection: TextDirection.rtl,
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: dark ? _slate400 : _slate400,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                                            isDense: true,
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: dark ? Colors.white : _slate800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _tableCell(
                                flex: 1,
                                dark: dark,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedRow = idx),
                                  child: ReplaceOnTypeNumberField(
                                    key: ValueKey('qty-${it.id}-$_formGen'),
                                    value: it.quantity,
                                    onChanged: (q) {
                                      setState(() => _selectedRow = idx);
                                      _updateItem(idx, qty: q <= 0 ? 0 : q);
                                    },
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: dark ? Colors.white : _slate800,
                                    ),
                                  ),
                                ),
                              ),
                              _tableCell(
                                flex: 1,
                                dark: dark,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedRow = idx);
                                    showDialog(
                                      context: context,
                                      builder: (c) => SimpleDialog(
                                        title: const Text('انتخاب واحد'),
                                        children: ['عدد', 'بسته', 'کیلو', 'متر', 'ساعت', 'دستگاه']
                                            .map(
                                              (u) => SimpleDialogOption(
                                                child: Text(u),
                                                onPressed: () {
                                                  Navigator.pop(c);
                                                  _updateItem(idx, unit: u);
                                                },
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      it.unit,
                                      style: TextStyle(fontSize: 11, color: dark ? Colors.white : _slate700),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              _tableCell(
                                flex: 2,
                                dark: dark,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedRow = idx),
                                  child: ReplaceOnTypeNumberField(
                                    key: ValueKey('price-${it.id}-$_formGen'),
                                    value: it.unitPrice,
                                    emptyDisplay: '\u0000',
                                    onChanged: (p) {
                                      setState(() => _selectedRow = idx);
                                      _updateItem(idx, price: p);
                                    },
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: dark ? Colors.white : _slate800,
                                    ),
                                  ),
                                ),
                              ),
                              _tableCell(
                                flex: 2,
                                dark: dark,
                                isLast: true,
                                child: Center(
                                  child: Text(
                                    it.totalPrice == 0
                                        ? '۰'
                                        : PersianNumberFormatter.formatCurrency(it.totalPrice)
                                            .replaceAll(' تومان', ''),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: dark ? Colors.white : _slate800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // دکمه ایجاد + کاتالوگ
                  Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final products = ref.read(productListProvider);
                            if (products.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('کاتالوگ خالی است')),
                              );
                              return;
                            }
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'انتخاب از کاتالوگ',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    ...products.map(
                                      (p) => ListTile(
                                        title: Text(p.name, textAlign: TextAlign.right),
                                        subtitle: Text(
                                          PersianNumberFormatter.formatCurrency(p.sellPrice),
                                          textAlign: TextAlign.right,
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          setState(() {
                                            final emptyIdx = _items.indexWhere(
                                              (e) => e.title.trim().isEmpty && e.unitPrice == 0,
                                            );
                                            final row = InvoiceItemModel(
                                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                                              title: p.name,
                                              quantity: 1,
                                              unit: p.unit,
                                              unitPrice: p.sellPrice,
                                              totalPrice: p.sellPrice,
                                            );
                                            if (emptyIdx >= 0) {
                                              _items[emptyIdx] = row;
                                              _selectedRow = emptyIdx;
                                            } else {
                                              _items.add(row);
                                              _selectedRow = _items.length - 1;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.teal),
                          label: const Text(
                            'کاتالوگ',
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        InkWell(
                          onTap: _addItem,
                          child: Row(
                            children: [
                              Text('ایجاد', style: TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.add, color: _orange, size: 16),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // جمع آیتم‌ها — برچسب راست، مبلغ چپ (RTL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'جمع آیتم‌ها',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : _slate700,
                    ),
                  ),
                  Text(
                    PersianNumberFormatter.formatCurrency(_itemsTotal),
                    style: TextStyle(fontSize: 12, color: dark ? _slate400 : _slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4) کارت هزینه ارسال / تخفیف / بیعانه / بدهی قبلی
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: _checkRow(label: 'هزینه ارسال:', value: _hasShipping, onChanged: (v)=> setState(()=> _hasShipping=v!), dark: dark, trailing: _hasShipping? SizedBox(width: 80, child: TextField(keyboardType: TextInputType.number, onChanged: (v)=> setState(()=> _shippingFee= double.tryParse(_faToEn(v))??0), decoration: InputDecoration(hintText: '۰', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: dark? _slate800: Colors.white), style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800))): null)),
                    const SizedBox(width: 8),
                    Expanded(child: _checkRow(label: 'تخفیف:', value: _hasDiscount, onChanged: (v)=> setState(()=> _hasDiscount=v!), dark: dark, trailing: null)),
                  ]),
                  if (_hasDiscount) Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      InkWell(onTap: ()=> setState(()=> _discountIsPercent=true), child: Text('درصد', style: TextStyle(fontSize: 12, color: _discountIsPercent? _orange: _slate400, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      InkWell(onTap: ()=> setState(()=> _discountIsPercent=false), child: Text('مبلغ', style: TextStyle(fontSize: 12, color: !_discountIsPercent? _orange: _slate400, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      SizedBox(width: 90, child: TextField(keyboardType: TextInputType.number, onChanged: (v)=> setState(()=> _discountAmount= double.tryParse(_faToEn(v))??0), decoration: InputDecoration(hintText: '۰', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: dark? _slate800: Colors.white), style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: dark? _slate700: _cardGrayBorder, height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _checkRow(label: 'بیعانه:', value: _hasDeposit, onChanged: (v)=> setState(()=> _hasDeposit=v!), dark: dark, trailing: _hasDeposit? SizedBox(width: 80, child: TextField(keyboardType: TextInputType.number, onChanged: (v)=> setState(()=> _depositAmount= double.tryParse(_faToEn(v))??0), decoration: InputDecoration(hintText: '۰', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: dark? _slate800: Colors.white), style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800))): null)),
                    const SizedBox(width: 8),
                    Expanded(child: _checkRow(label: 'بدهی قبلی:', value: _hasPrevDebt, onChanged: (v)=> setState(()=> _hasPrevDebt=v!), dark: dark, trailing: _hasPrevDebt? SizedBox(width: 80, child: TextField(keyboardType: TextInputType.number, onChanged: (v)=> setState(()=> _prevDebtAmount= double.tryParse(_faToEn(v))??0), decoration: InputDecoration(hintText: '۰', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: dark? _slate800: Colors.white), style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800))): null)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 5) کارت نوع فاکتور / نوع پرداخت
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('نوع فاکتور', style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate600, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _radio(label: 'پیش فاکتور', value: 'proforma', group: _invoiceType, onChanged: (v)=> setState(()=> _invoiceType=v!), dark: dark),
                      const SizedBox(width: 8),
                      _radio(label: 'فاکتور خرید', value: 'purchase', group: _invoiceType, onChanged: (v)=> setState(()=> _invoiceType=v!), dark: dark),
                      const SizedBox(width: 8),
                      _radio(label: 'فاکتور فروش', value: 'sale', group: _invoiceType, onChanged: (v)=> setState(()=> _invoiceType=v!), dark: dark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(color: dark? _slate700: _cardGrayBorder, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('نوع پرداخت', style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate600, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _radio(label: 'نقدی', value: 'cash', group: _paymentType, onChanged: (v)=> setState(()=> _paymentType=v!), dark: dark),
                      const SizedBox(width: 8),
                      _radio(label: 'غیر نقدی', value: 'non_cash', group: _paymentType, onChanged: (v)=> setState(()=> _paymentType=v!), dark: dark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6) خلاصه مبالغ — تخفیف/ارسال/بدهی/بیعانه + قابل پرداخت
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  _sumRow('جمع اقلام', _itemsTotal, dark: dark),
                  if (_hasDiscount && _resolvedDiscount > 0)
                    _sumRow('تخفیف', -_resolvedDiscount, dark: dark, color: const Color(0xFF059669)),
                  if (_hasShipping && _shippingVal > 0)
                    _sumRow('هزینه ارسال', _shippingVal, dark: dark),
                  if (_hasPrevDebt && _prevDebtVal > 0)
                    _sumRow('بدهی قبلی', _prevDebtVal, dark: dark, color: const Color(0xFFE11D48)),
                  if (_hasDeposit && _depositVal > 0)
                    _sumRow('بیعانه', -_depositVal, dark: dark, color: const Color(0xFF0284C7)),
                  Divider(color: dark ? _slate700 : _cardGrayBorder, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مبلغ قابل پرداخت',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : _slate800,
                        ),
                      ),
                      Text(
                        PersianNumberFormatter.formatCurrency(_finalTotal),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : _orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // تیک نمایش مهر و امضا روی فاکتور
            _grayCard(
              dark: dark,
              child: Builder(builder: (ctx) {
                final st = ref.watch(settingsProvider);
                final biz = ref.watch(businessProvider);
                return Column(
                  children: [
                    _checkRow(
                      label: 'نمایش مهر روی فاکتور',
                      value: st.showStamp,
                      dark: dark,
                      onChanged: (v) {
                        ref.read(settingsProvider.notifier).updateSettings(
                              st.copyWith(showStamp: v ?? false),
                            );
                      },
                      trailing: biz.stampPath.isEmpty
                          ? TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HeaderCustomizeScreen()),
                                );
                              },
                              child: const Text('افزودن', style: TextStyle(fontSize: 11, color: _orange)),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Divider(color: dark ? _slate700 : _cardGrayBorder, height: 1),
                    const SizedBox(height: 8),
                    _checkRow(
                      label: 'نمایش امضا روی فاکتور',
                      value: st.showSignature,
                      dark: dark,
                      onChanged: (v) {
                        ref.read(settingsProvider.notifier).updateSettings(
                              st.copyWith(showSignature: v ?? false),
                            );
                      },
                      trailing: biz.signaturePath.isEmpty
                          ? TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HeaderCustomizeScreen()),
                                );
                              },
                              child: const Text('افزودن', style: TextStyle(fontSize: 11, color: _orange)),
                            )
                          : null,
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),

            // 7) توضیحات
            _grayCard(
              dark: dark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _notesCtrl,
                onChanged: (v) => _notes = v,
                maxLines: 3,
                minLines: 1,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'توضیحات',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(color: _slate400, fontSize: 12),
                ),
                style: TextStyle(fontSize: 12, color: dark ? Colors.white : _slate800),
              ),
            ),
            const SizedBox(height: 10),

            // 8) کارت بانکی — افزودن یا نمایش انتخاب‌شده (با انیمیشن)
            Builder(builder: (ctx){
              final selected = ref.watch(selectedBankCardProvider);
              if (selected == null) {
                return InkWell(
                  onTap: ()=> showCardListSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: _grayCard(
                    dark: dark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(children: [
                      Icon(Icons.chevron_left, color: _slate400, size: 20),
                      const Spacer(),
                      Text('افزودن شماره کارت', style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                );
              }
              // نمایش کارت انتخاب‌شده — لوگو درشت، نام/بانک راست، شماره LTR راست‌چین
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dark ? _slate800 : _cardGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // لوگو بدون بک‌گراند سفید
                        Builder(builder: (ctx) {
                          final asset = bankLogoAsset(selected.bankName);
                          if (asset.isNotEmpty) {
                            return SizedBox(
                              width: 48,
                              height: 48,
                              child: Image.asset(
                                asset,
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            );
                          }
                          final label = selected.bankName.replaceAll('بانک ', '');
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: bankColor(selected.bankName),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label.isNotEmpty ? label.substring(0, 1) : 'ب',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.bankName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? _slate400 : _slate500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selected.persianName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: dark ? Colors.white : Colors.black,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // شماره کارت — LTR راست‌چین
                    Align(
                      alignment: Alignment.centerRight,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          PersianNumberFormatter.toPersian(
                            selected.formattedCard.replaceAll(' ', ' - '),
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.8,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    if (selected.sheba.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            PersianNumberFormatter.toPersian(selected.spacedSheba),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.4,
                              color: dark ? _slate400 : _slate500,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => showCardListSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_left, size: 18, color: _slate400),
                              const SizedBox(width: 4),
                              const Text(
                                'تغییر شماره کارت',
                                style: TextStyle(
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),

            // 9) ذخیره و اشتراک‌گذاری / ذخیره تغییرات
            InkWell(
              onTap: _saveInvoice,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _isEditing
                      ? _orange
                      : (dark ? _slate800 : _cardGray),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEditing
                        ? _orange
                        : (dark ? _slate700 : _cardGrayBorder),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isEditing ? Icons.check : Icons.share,
                      color: _isEditing ? Colors.white : _slate600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'ذخیره تغییرات' : 'ذخیره و اشتراک گذاری فاکتور',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _isEditing
                            ? Colors.white
                            : (dark ? Colors.white : _slate800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // Bottom tabs مثل عکس
      bottomNavigationBar: _bottomTabs(dark),
    );
  }

  // ── Helpers ──
  Widget _grayCard({required bool dark, required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark? _slate800: _cardGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark? _slate700: Colors.transparent),
      ),
      child: child,
    );
  }

  /// فیلد پایدار با کنترلر — فوکوس هنگام تایپ از دست نمی‌رود
  Widget _stableCustomerField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool dark,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    final isPhone = keyboardType == TextInputType.phone;
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: dark ? _slate700 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: dark ? _slate600 : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: dark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintTextDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: dark ? _slate400.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : _slate800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String t, {int flex = 1, required bool dark, bool isLast = false}) {
    final isTitle = t == 'عنوان';
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: isTitle ? 8 : 0),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(left: BorderSide(color: dark ? _slate700 : _cardGrayBorder)),
        ),
        child: Text(
          t,
          textAlign: isTitle ? TextAlign.right : TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: dark ? _slate400 : _slate600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _tableCell({
    required Widget child,
    required bool dark,
    int flex = 1,
    bool isLast = false,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(left: BorderSide(color: dark ? _slate700 : _cardGrayBorder)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _checkRow({required String label, required bool value, required Function(bool?) onChanged, required bool dark, Widget? trailing}) {
    return Row(children: [
      SizedBox(
        width: 22, height: 22,
        child: Checkbox(value: value, onChanged: onChanged, activeColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), side: BorderSide(color: dark? _slate500: _slate400)),
      ),
      const SizedBox(width: 4),
      Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: dark? _slate400: _slate500))),
      if (trailing!=null) trailing,
    ]);
  }

  Widget _sumRow(String label, double amount, {required bool dark, Color? color}) {
    final c = color ?? (dark ? Colors.white70 : _slate700);
    final isNeg = amount < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
          Text(
            '${isNeg ? '− ' : ''}${PersianNumberFormatter.formatCurrency(amount.abs())}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
          ),
        ],
      ),
    );
  }

  Widget _radio({required String label, required String value, required String group, required Function(String?) onChanged, required bool dark}) {
    final selected = value==group;
    return InkWell(
      onTap: ()=> onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: selected? _orange: (dark? _slate400: _slate500), fontWeight: selected? FontWeight.w800: FontWeight.w500)),
        const SizedBox(width: 4),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected? _orange: _slate400, width: 2), color: selected? _orange: Colors.transparent),
          child: selected? const Center(child: Icon(Icons.circle, size: 10, color: Colors.white)): null,
        ),
      ]),
    );
  }

  Widget _bottomTabs(bool dark) {
    final invoices = ref.watch(invoiceListProvider);
    final tabLabel = _invoiceType=='proforma'? 'پیش فاکتور': (_invoiceType=='purchase'? 'فاکتور خرید':'فاکتور فروش');
    return Container(
      height: 48,
      decoration: BoxDecoration(color: dark? _slate800: Colors.white, border: Border(top: BorderSide(color: dark? _slate700: _cardGrayBorder))),
      child: Row(children: [
        // + سمت چپ
        InkWell(onTap: _addItem, child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(border: Border(left: BorderSide(color: dark? _slate700: _cardGrayBorder))), child: const Icon(Icons.add, color: _orange, size: 22))),
        // وسط خالی
        const Expanded(child: SizedBox()),
        // تب فعال
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: dark? _slate700: _cardGray, border: Border(left: BorderSide(color: dark? _slate700: _cardGrayBorder), right: BorderSide(color: dark? _slate700: _cardGrayBorder))),
          child: Row(children: [
            Text('$tabLabel ${PersianNumberFormatter.toPersian(invoices.length+1)}', style: TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_up, color: _orange, size: 18),
          ]),
        ),
        // منو راست
        InkWell(onTap: ()=> _scaffoldKey.currentState?.openDrawer(), child: Container(width: 48, height: 48, alignment: Alignment.center, child: Icon(Icons.menu, color: dark? Colors.white: _slate700))),
      ]),
    );
  }

  Widget _buildDrawer() {
    final user = ref.watch(userProvider);
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        UserAccountsDrawerHeader(
          accountName: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          accountEmail: Text('${user.country} - ${user.city}'),
          currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Text(user.name.isNotEmpty? user.name[0]: 'ر', style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 24))),
          decoration: const BoxDecoration(color: _orange),
        ),
        ListTile(leading: const Icon(Icons.add_circle_outline, color: _orange), title: const Text('ثبت فاکتور جدید', style: TextStyle(fontWeight: FontWeight.w800)), onTap: ()=> Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.receipt_long, color: _orange), title: const Text('لیست فاکتورها', style: TextStyle(fontWeight: FontWeight.w800)), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const InvoiceListScreen()));}),
        const Divider(),
        ListTile(leading: const Icon(Icons.people), title: const Text('مشتریان'), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const CustomerListScreen()));}),
        ListTile(leading: const Icon(Icons.inventory_2), title: const Text('محصولات'), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const ProductListScreen()));}),
        ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('گزارش مالی'), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const FinancialDashboardScreen()));}),
        ListTile(leading: const Icon(Icons.settings), title: const Text('تنظیمات'), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const SettingsScreen()));}),
      ]),
    );
  }

  String _faToEn(String s){
    const fa=['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    const en=['0','1','2','3','4','5','6','7','8','9'];
    var r=s;
    for(int i=0;i<10;i++) r=r.replaceAll(fa[i], en[i]);
    return r;
  }
}
