import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../providers/app_providers.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../customer/customer_list_screen.dart';
import '../product/product_list_screen.dart';
import '../settings/settings_screen.dart';
import '../invoice/invoice_list_screen.dart';
import '../customize/header_customize_screen.dart';
import '../card/card_list_sheet.dart';
import '../invoice/invoice_preview_screen.dart';
import '../../providers/bank_card_provider.dart';
import '../../core/utils/replace_on_type_field.dart';
import '../../core/utils/thousand_separator_formatter.dart';
import '../../core/utils/prefs_store.dart';
import '../../core/utils/prefs_store.dart';

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

/// پیش‌فاکتور موقت (تب پایین صفحه)
class _DraftTab {
  final String id;
  String title;
  String? editId;
  String customerName;
  String customerPhone;
  String invoiceNumber;
  String dateLabel;
  List<InvoiceItemModel> items;
  bool hasShipping;
  bool hasDiscount;
  bool discountIsPercent;
  bool hasDeposit;
  bool hasPrevDebt;
  String invoiceType;
  String paymentType;
  String notes;
  double discountAmount;
  double shippingFee;
  double depositAmount;
  double prevDebtAmount;

  _DraftTab({
    required this.id,
    required this.title,
    this.editId,
    this.customerName = '',
    this.customerPhone = '',
    this.invoiceNumber = '۱',
    this.dateLabel = '',
    List<InvoiceItemModel>? items,
    this.hasShipping = false,
    this.hasDiscount = false,
    this.discountIsPercent = false,
    this.hasDeposit = false,
    this.hasPrevDebt = false,
    this.invoiceType = 'proforma',
    this.paymentType = 'cash',
    this.notes = '',
    this.discountAmount = 0,
    this.shippingFee = 0,
    this.depositAmount = 0,
    this.prevDebtAmount = 0,
  }) : items = items ??
            [
              InvoiceItemModel(
                id: '1',
                title: '',
                quantity: 1,
                unit: 'عدد',
                unitPrice: 0,
                totalPrice: 0,
              ),
            ];
}

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
  late final TextEditingController _shippingCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _prevDebtCtrl;

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
  int? _typingRow;
  Timer? _suggestionTimer;
  OverlayEntry? _productPopup;
  final Map<int, LayerLink> _productLinks = <int, LayerLink>{};
  /// با هر بار load ویرایش افزایش می‌یابد تا فیلدهای جدول دوباره ساخته شوند
  int _formGen = 0;

  /// تب‌های پیش‌فاکتور موقت (مثل فیدا)
  final List<_DraftTab> _draftTabs = [];
  String _activeTabId = '';
  int _tabSeq = 1;

  static const List<String> _jalaliMonths = <String>[
    '',
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const List<String> _jalaliWeekdays = <String>[
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  bool get _isEditing => _editId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _shippingCtrl = TextEditingController();
    _depositCtrl = TextEditingController();
    _discountCtrl = TextEditingController();
    _prevDebtCtrl = TextEditingController();
    _dateLabel = _todayLabel();
    // یک ردیف پیش‌فرض مثل عکس (۱ عدد)
    _items = [
      InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0),
    ];
    // تب اول
    final first = _DraftTab(
      id: 'tab-1',
      title: 'پیش فاکتور ۱',
      invoiceNumber: _invoiceNumber,
      dateLabel: _dateLabel,
    );
    _draftTabs.add(first);
    _activeTabId = first.id;
    _tabSeq = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreInitialForm();
    });
  }

  Future<void> _restoreInitialForm() async {
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

    // آخرین پیش‌نویس ذخیره‌شده بعد از بستن برنامه دوباره روی خانه باز می‌شود.
    final draft = await PrefsStore.loadDraft();
    if (draft != null && mounted) {
      _loadInvoiceForEdit(draft, asDraft: true);
      return;
    }

    final settings = ref.read(settingsProvider);
    if (settings.startingInvoiceNum > 0 && mounted) {
      setState(() => _invoiceNumber =
          PersianNumberFormatter.toPersian(settings.startingInvoiceNum.toString()));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _shippingCtrl.dispose();
    _depositCtrl.dispose();
    _discountCtrl.dispose();
    _prevDebtCtrl.dispose();
    _suggestionTimer?.cancel();
    _productPopup?.remove();
    _productPopup = null;
    super.dispose();
  }

  String _fmtAmt(double v) {
    if (v <= 0) return '';
    final raw = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return ThousandSeparatorInputFormatter.formatDisplay(raw, allowDecimal: true);
  }

  void _setCtrl(TextEditingController c, String text) {
    if (c.text == text) return;
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncTextControllers() {
    _setCtrl(_nameCtrl, _customerName);
    _setCtrl(_phoneCtrl, _customerPhone);
    _setCtrl(_notesCtrl, _notes);
    _setCtrl(_shippingCtrl, _hasShipping ? _fmtAmt(_shippingFee) : '');
    _setCtrl(_depositCtrl, _hasDeposit ? _fmtAmt(_depositAmount) : '');
    _setCtrl(_discountCtrl, _hasDiscount ? _fmtAmt(_discountAmount) : '');
    _setCtrl(_prevDebtCtrl, _hasPrevDebt ? _fmtAmt(_prevDebtAmount) : '');
  }

  /// پر کردن فرم هوم با داده فاکتور برای ویرایش (همان UI داشبورد)
  void _loadInvoiceForEdit(InvoiceModel e, {bool asDraft = false}) {
    setState(() {
      _editId = asDraft ? null : e.id;
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
    });
    // بعد از rebuild ویجت‌ها، کنترلرها را با مقادیر واقعی پر کن
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTextControllers();
    });
  }


  Future<void> _persistDraft() async {
    if (_editId != null) return;

    final hasItems = _items.any(
      (item) => item.title.trim().isNotEmpty || item.unitPrice > 0 || item.totalPrice > 0,
    );
    final hasExtra = _customerName.trim().isNotEmpty ||
        _customerPhone.trim().isNotEmpty ||
        _notes.trim().isNotEmpty ||
        _hasShipping ||
        _hasDiscount ||
        _hasDeposit ||
        _hasPrevDebt;

    if (!hasItems && !hasExtra) {
      await PrefsStore.clearDraft();
      return;
    }

    final draftDate = _dateLabel.isNotEmpty ? _dateLabel : _todayLabel();
    final draft = InvoiceModel(
      id: 'draft-home',
      number: _faToEn(_invoiceNumber),
      customerId: '',
      customerName: _customerName,
      customerPhone: _customerPhone,
      type: _invoiceType,
      paymentType: _paymentType,
      status: 'draft',
      date: draftDate,
      items: _items
          .map(
            (item) => InvoiceItemModel(
              id: item.id,
              title: item.title,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
            ),
          )
          .toList(),
      subtotal: _itemsTotal,
      discountPercent: _discountIsPercent ? _discountAmount : 0,
      discountAmount: _resolvedDiscount,
      shippingFee: _shippingVal,
      previousDebt: _prevDebtVal,
      deposit: _depositVal,
      totalAmount: _finalTotal,
      paidAmount: 0,
      remainingAmount: _finalTotal,
      notes: _notes,
      cardNumber: '',
      createdAt: draftDate,
    );
    await PrefsStore.saveDraft(draft);
  }

  String _typeLabelOf(String t) {
    switch (t) {
      case 'sale':
        return 'فاکتور فروش';
      case 'purchase':
        return 'فاکتور خرید';
      default:
        return 'پیش فاکتور';
    }
  }

  String _autoTabTitle() {
    final name = _customerName.trim();
    if (name.isNotEmpty) return name;
    // شماره تب از ترتیب
    final idx = _draftTabs.indexWhere((t) => t.id == _activeTabId);
    final n = idx >= 0 ? idx + 1 : _draftTabs.length;
    return '${_typeLabelOf(_invoiceType)} ${PersianNumberFormatter.toPersian(n.toString())}';
  }

  void _snapshotCurrentToActiveTab() {
    final i = _draftTabs.indexWhere((t) => t.id == _activeTabId);
    if (i < 0) return;
    final t = _draftTabs[i];
    t.editId = _editId;
    t.customerName = _customerName;
    t.customerPhone = _customerPhone;
    t.invoiceNumber = _invoiceNumber;
    t.dateLabel = _dateLabel;
    t.items = _items
        .map((e) => InvoiceItemModel(
              id: e.id,
              title: e.title,
              quantity: e.quantity,
              unit: e.unit,
              unitPrice: e.unitPrice,
              totalPrice: e.totalPrice,
            ))
        .toList();
    t.hasShipping = _hasShipping;
    t.hasDiscount = _hasDiscount;
    t.discountIsPercent = _discountIsPercent;
    t.hasDeposit = _hasDeposit;
    t.hasPrevDebt = _hasPrevDebt;
    t.invoiceType = _invoiceType;
    t.paymentType = _paymentType;
    t.notes = _notes;
    t.discountAmount = _discountAmount;
    t.shippingFee = _shippingFee;
    t.depositAmount = _depositAmount;
    t.prevDebtAmount = _prevDebtAmount;
    t.title = _autoTabTitle();
  }

  void _restoreTab(_DraftTab t) {
    _editId = t.editId;
    _customerName = t.customerName;
    _customerPhone = t.customerPhone;
    _invoiceNumber = t.invoiceNumber;
    _dateLabel = t.dateLabel.isNotEmpty ? t.dateLabel : _todayLabel();
    _items = t.items
        .map((e) => InvoiceItemModel(
              id: e.id,
              title: e.title,
              quantity: e.quantity,
              unit: e.unit,
              unitPrice: e.unitPrice,
              totalPrice: e.totalPrice,
            ))
        .toList();
    if (_items.isEmpty) {
      _items = [
        InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0),
      ];
    }
    _hasShipping = t.hasShipping;
    _hasDiscount = t.hasDiscount;
    _discountIsPercent = t.discountIsPercent;
    _hasDeposit = t.hasDeposit;
    _hasPrevDebt = t.hasPrevDebt;
    _invoiceType = t.invoiceType;
    _paymentType = t.paymentType;
    _notes = t.notes;
    _discountAmount = t.discountAmount;
    _shippingFee = t.shippingFee;
    _depositAmount = t.depositAmount;
    _prevDebtAmount = t.prevDebtAmount;
    _selectedRow = null;
    _formGen++;
    _activeTabId = t.id;
  }

  void _switchToTab(String id) {
    if (id == _activeTabId) return;
    _snapshotCurrentToActiveTab();
    _DraftTab? found;
    for (final e in _draftTabs) {
      if (e.id == id) {
        found = e;
        break;
      }
    }
    if (found == null) return;
    final tab = found;
    setState(() {
      _restoreTab(tab);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTextControllers();
    });
  }

  void _addNewDraftTab() {
    _snapshotCurrentToActiveTab();
    final settings = ref.read(settingsProvider);
    // شماره بعدی
    final base = settings.startingInvoiceNum + _draftTabs.length;
    final numFa = PersianNumberFormatter.toPersian(base.toString());
    final tab = _DraftTab(
      id: 'tab-${DateTime.now().millisecondsSinceEpoch}',
      title: 'پیش فاکتور ${PersianNumberFormatter.toPersian(_tabSeq.toString())}',
      invoiceNumber: numFa,
      dateLabel: _todayLabel(),
      invoiceType: 'proforma',
      paymentType: 'cash',
    );
    setState(() {
      _draftTabs.add(tab);
      _tabSeq++;
      _restoreTab(tab);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTextControllers();
    });
  }

  void _closeDraftTab(String id) {
    if (_draftTabs.length <= 1) {
      // ریست همان تب
      _resetFormForNew();
      _snapshotCurrentToActiveTab();
      return;
    }
    final idx = _draftTabs.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final wasActive = id == _activeTabId;
    if (wasActive) {
      // قبل از حذف، سوییچ
      final next = idx > 0 ? _draftTabs[idx - 1] : _draftTabs[idx + 1];
      setState(() {
        _draftTabs.removeAt(idx);
        _restoreTab(next);
      });
    } else {
      setState(() => _draftTabs.removeAt(idx));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTextControllers();
    });
  }

  void _showOpenWindowsSheet() {
    _snapshotCurrentToActiveTab();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Color(ref.read(settingsProvider).accentColor);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? _slate800 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${PersianNumberFormatter.toPersian(_draftTabs.length.toString())} پنجره',
                        style: TextStyle(fontSize: 12, color: dark ? _slate400 : _slate500, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        'پنجره‌های باز',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: dark ? Colors.white : _slate800),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: dark ? Colors.white70 : _slate600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'این فاکتورها موقتی هستند. برای جلوگیری از حذف شدن، آن‌ها را ذخیره کنید.',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: dark ? _slate400 : _slate500, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _draftTabs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final t = _draftTabs[i];
                        final active = t.id == _activeTabId;
                        return Material(
                          color: active
                              ? accent.withValues(alpha: 0.10)
                              : (dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _switchToTab(t.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setModal(() {
                                        _closeDraftTab(t.id);
                                      });
                                      if (_draftTabs.isEmpty) Navigator.pop(ctx);
                                    },
                                    child: Icon(Icons.close, size: 20, color: dark ? _slate400 : _slate500),
                                  ),
                                  const Spacer(),
                                  Text(
                                    t.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: active ? accent : (dark ? Colors.white : _slate800),
                                    ),
                                  ),
                                  if (active) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check_circle, color: accent, size: 22),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addNewDraftTab();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('فاکتور جدید', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  LayerLink _productLink(int row) {
    return _productLinks.putIfAbsent(row, LayerLink.new);
  }

  void _showProductPopup(int row) {
    _productPopup?.remove();
    _productPopup = null;
    final link = _productLink(row);
    final overlay = Overlay.of(context);
    _productPopup = OverlayEntry(
      builder: (_) => CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, 6),
        // Overlay روی صفحهٔ کامل constraint می‌دهد؛ با UnconstrainedBox
        // اندازهٔ پاپ‌آپ را به اندازهٔ واقعی نوشته‌ها برمی‌گردانیم.
        child: UnconstrainedBox(
          alignment: Alignment.topRight,
          child: _productPopupContent(row),
        ),
      ),
    );
    overlay.insert(_productPopup!);
  }

  Widget _productPopupContent(int row) {
    if (row < 0 || row >= _items.length) return const SizedBox.shrink();
    final query = _items[row].title.trim();
    final suggestions = _matchingProducts(query).take(2).toList();
    if (query.length < 2 || (suggestions.isEmpty && query.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Material(
      elevation: 12,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _orange.withValues(alpha: 0.25)),
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...suggestions.map(
                  (product) => InkWell(
                    onTap: () => _selectProductForRow(row, product),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 13, color: _orange),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Text(
                              '${product.name} · ${PersianNumberFormatter.formatCurrency(product.sellPrice)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _addCurrentProductToCatalog(row),
                    icon: const Icon(Icons.playlist_add, size: 13),
                    label: const Text(
                      'ذخیره محصول در کاتالوگ',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _orange,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _markTyping(int row) {
    _suggestionTimer?.cancel();
    if (mounted) {
      setState(() {
        _typingRow = row;
        _selectedRow = row;
      });
    }
    _showProductPopup(row);
    _suggestionTimer = Timer(const Duration(seconds: 4), _hideSuggestions);
  }

  void _hideSuggestions() {
    _suggestionTimer?.cancel();
    _productPopup?.remove();
    _productPopup = null;
    if (mounted) setState(() => _typingRow = null);
  }

  List<ProductModel> _matchingProducts(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const <ProductModel>[];
    return ref
        .read(productListProvider)
        .where((product) => product.name.toLowerCase().contains(normalized))
        .toList();
  }

  void _selectProductForRow(int idx, ProductModel product) {
    if (idx < 0 || idx >= _items.length) return;

    // قبل از بازسازی فرم، خود OverlayEntry را حذف کن تا پاپ‌آپ حتی
    // در صورت تغییر لینک فیلد هم روی صفحه باقی نماند.
    _suggestionTimer?.cancel();
    final popup = _productPopup;
    _productPopup = null;
    popup?.remove();

    if (!mounted) return;
    setState(() {
      _items[idx] = InvoiceItemModel(
        id: _items[idx].id,
        title: product.name,
        quantity: 1,
        unit: product.unit,
        unitPrice: product.sellPrice,
        totalPrice: product.sellPrice,
      );
      _selectedRow = idx;
      _formGen++;
      _typingRow = null;
    });
  }

  void _addCurrentProductToCatalog(int idx) {
    final it = _items[idx];
    final name = it.title.trim();
    if (name.isEmpty) return;
    final products = ref.read(productListProvider);
    final existingIndex = products.indexWhere((p) => p.name.trim() == name);
    if (existingIndex >= 0) {
      final old = products[existingIndex];
      final updated = ProductModel(
        id: old.id,
        code: old.code,
        name: old.name,
        unit: it.unit.isEmpty ? old.unit : it.unit,
        buyPrice: old.buyPrice,
        sellPrice: it.unitPrice > 0 ? it.unitPrice : old.sellPrice,
        stock: old.stock,
        notes: old.notes,
      );
      ref.read(productListProvider.notifier).updateProduct(updated);
      _hideSuggestions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('قیمت آخر «$name» در کاتالوگ به‌روز شد')),
      );
      return;
    }
    final p = ProductModel(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      code: '${100 + products.length + 1}',
      name: name,
      unit: it.unit.isEmpty ? 'عدد' : it.unit,
      buyPrice: 0,
      sellPrice: it.unitPrice,
      stock: 0,
      notes: '',
    );
    ref.read(productListProvider.notifier).addProduct(p);
    _hideSuggestions();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«$name» به کاتالوگ اضافه شد')),
    );
  }

  Future<void> _showCustomerPicker() async {
    final customers = ref.read(customerListProvider);
    final accent = Color(ref.read(settingsProvider).accentColor);
    final selected = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final normalized = query.trim().toLowerCase();
            final filtered = normalized.isEmpty
                ? customers
                : customers.where((customer) {
                    final haystack = '${customer.name} ${customer.mobile} ${customer.phone}'.toLowerCase();
                    return haystack.contains(normalized);
                  }).toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.66,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'انتخاب مشتری',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          onChanged: (value) => setSheetState(() => query = value),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'جست‌وجوی نام یا شماره مشتری',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFFF6F7FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    customers.isEmpty
                                        ? 'هنوز مشتری‌ای ثبت نشده است'
                                        : 'مشتری موردنظر پیدا نشد',
                                    style: const TextStyle(color: _slate500, fontWeight: FontWeight.w700),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, index) {
                                    final customer = filtered[index];
                                    final phone = customer.mobile.isNotEmpty
                                        ? customer.mobile
                                        : customer.phone;
                                    final isSelected = customer.name.trim() == _customerName.trim();
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: accent.withValues(alpha: 0.12),
                                        foregroundColor: accent,
                                        child: Text(
                                          customer.name.isEmpty ? 'م' : customer.name[0],
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      title: Text(
                                        customer.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: phone.isEmpty ? null : Text(phone, textDirection: TextDirection.ltr),
                                      trailing: isSelected
                                          ? Icon(Icons.check_circle, color: accent)
                                          : const Icon(Icons.chevron_left, color: _slate400),
                                      onTap: () => Navigator.pop(sheetContext, customer),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    final phone = selected.mobile.isNotEmpty ? selected.mobile : selected.phone;
    setState(() {
      _customerName = selected.name;
      _customerPhone = phone;
      _setCtrl(_nameCtrl, selected.name);
      _setCtrl(_phoneCtrl, phone);
      final i = _draftTabs.indexWhere((tab) => tab.id == _activeTabId);
      if (i >= 0) _draftTabs[i].title = selected.name;
    });
  }

  Future<void> _editInvoiceDate() async {
    final accent = Color(ref.read(settingsProvider).accentColor);
    final initial = _parseJalaliLabel(_dateLabel) ?? Jalali.now();
    final selected = await showModalBottomSheet<Jalali>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        var visibleMonth = Jalali(initial.year, initial.month, 1);
        var picked = initial;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final firstDay = Jalali(visibleMonth.year, visibleMonth.month, 1);
            final leading = firstDay.weekDay - 1;
            final days = firstDay.monthLength;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'ماه بعد',
                            onPressed: () => setSheetState(
                              () => visibleMonth = visibleMonth.addMonths(1),
                            ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              '${_jalaliMonths[visibleMonth.month]} ${PersianNumberFormatter.toPersian(visibleMonth.year.toString())}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: 'ماه قبل',
                            onPressed: () => setSheetState(
                              () => visibleMonth = visibleMonth.addMonths(-1),
                            ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (final dayName in _jalaliWeekdays)
                            Expanded(
                              child: Text(
                                dayName.substring(0, 1),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _slate500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: leading + days,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (_, index) {
                          if (index < leading) return const SizedBox.shrink();
                          final day = index - leading + 1;
                          final isPicked = picked.year == visibleMonth.year &&
                              picked.month == visibleMonth.month &&
                              picked.day == day;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setSheetState(
                              () => picked = Jalali(visibleMonth.year, visibleMonth.month, day),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isPicked ? accent : const Color(0xFFF6F7FB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                PersianNumberFormatter.toPersian(day.toString()),
                                style: TextStyle(
                                  color: isPicked ? Colors.white : _slate800,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاریخ انتخاب‌شده: ${_formatJalaliDisplay(picked)}',
                              style: const TextStyle(fontSize: 11, color: _slate500),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext, picked),
                            child: const Text('ثبت تاریخ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _dateLabel = _formatJalaliDisplay(selected));
    }
  }

  String _formatJalaliDisplay(Jalali date) {
    return '${PersianNumberFormatter.toPersian(date.day.toString())} ${_jalaliMonths[date.month]} ${PersianNumberFormatter.toPersian(date.year.toString())}';
  }

  Jalali? _parseJalaliLabel(String value) {
    final text = _faToEn(value.trim());
    final numeric = RegExp(r'^(\d{4})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{1,2})').firstMatch(text);
    try {
      if (numeric != null) {
        return Jalali(
          int.parse(numeric.group(1)!),
          int.parse(numeric.group(2)!),
          int.parse(numeric.group(3)!),
        );
      }
      final month = _jalaliMonths.indexWhere((item) => item.isNotEmpty && value.contains(item));
      final words = RegExp(r'^(\d{1,2})\s+.+\s+(\d{4})$').firstMatch(text);
      if (month > 0 && words != null) {
        return Jalali(int.parse(words.group(2)!), month, int.parse(words.group(1)!));
      }
    } catch (_) {
      return null;
    }
    return null;
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
    final cardBank = selectedCard?.bankName ??
        (card.isNotEmpty ? detectBankName(card) : '');
    final cardOwner = selectedCard?.persianName ?? '';

    String numEn = _faToEn(_invoiceNumber);
    final jalaliEn = JalaliHelper.getTodayJalali();
    // تاریخ انتخاب‌شده از تقویم برای فاکتور جدید و ویرایش‌شده یکسان ذخیره شود.
    final pickedDate = _parseJalaliLabel(_dateLabel);
    final dateToStore = pickedDate == null
        ? jalaliEn
        : '${pickedDate.year}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.day.toString().padLeft(2, '0')}';
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
      cardBank: cardBank.isNotEmpty ? cardBank : (existing?.cardBank ?? ''),
      cardOwner: cardOwner.isNotEmpty ? cardOwner : (existing?.cardOwner ?? ''),
      createdAt: existing?.createdAt ?? jalaliFa,
    );

    ref.read(invoiceListProvider.notifier).saveInvoice(inv);
    PrefsStore.clearDraft();

    // آماده‌سازی فرم برای فاکتور بعدی
    final nextNum = (int.tryParse(numEn) ?? 1004) + 1;
    _resetFormForNew(
      nextNumberFa: PersianNumberFormatter.toPersian(nextNum.toString()),
    );

    // به‌روزرسانی تب فعال پس از ذخیره
    _snapshotCurrentToActiveTab();

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
    final settings = ref.watch(settingsProvider);
    final accent = Color(settings.accentColor);
    final shopName = business.shopName.isNotEmpty ? business.shopName : 'فاکتور ساز روبی';

    // گوش دادن به درخواست ویرایش از صفحات دیگر
    ref.listen<InvoiceModel?>(invoiceEditRequestProvider, (prev, next) {
      if (next != null) {
        ref.read(invoiceEditRequestProvider.notifier).state = null;
        _loadInvoiceForEdit(next);
      }
    });

    // هر تغییر فیلد/ردیف در فریم بعدی به‌عنوان پیش‌نویس ذخیره می‌شود.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _persistDraft();
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: dark ? _slate900 : _bg,
      drawer: _buildDrawer(),
      // هدر سفید و خلوت مطابق تصویر مرجع: منو چپ، عنوان وسط، برند راست.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(78),
        child: AppBar(
          backgroundColor: dark ? _slate800 : Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 78,
          systemOverlayStyle: dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          titleSpacing: 0,
          title: SizedBox(
            width: double.infinity,
            height: 78,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _isEditing
                      ? IconButton(
                          icon: Icon(Icons.close, color: dark ? Colors.white : _slate700),
                          onPressed: () {
                            final st = ref.read(settingsProvider);
                            _resetFormForNew(
                              nextNumberFa: PersianNumberFormatter.toPersian(
                                st.startingInvoiceNum.toString(),
                              ),
                            );
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.menu, color: dark ? Colors.white : _slate700, size: 30),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    _isEditing
                        ? 'ویرایش فاکتور #${PersianNumberFormatter.toPersian(_invoiceNumber)}'
                        : shopName,
                    style: TextStyle(
                      color: dark ? Colors.white : _slate800,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _isEditing
                      ? TextButton(
                          onPressed: _saveInvoice,
                          child: Text(
                            'ذخیره',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.asset(
                                  'assets/images/logo.webp',
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.pets,
                                    color: accent,
                                    size: 30,
                                  ),
                                ),
                              ),
                              Text(
                                'روبی',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: dark ? _slate700 : const Color(0xFFF1F3F8)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          key: ValueKey('form-$_formGen'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) نوار نارنجی اصلی دقیقاً با نقش دکمهٔ سریع تصویر مرجع
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HeaderCustomizeScreen()),
              ),
              borderRadius: BorderRadius.circular(34),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.lerp(accent, Colors.white, 0.08) ?? accent,
                      accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.tune_outlined, color: accent, size: 28),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'تنظیمات سریع فاکتور',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2) کارت اطلاعات مشتری — چیدمان دو ردیفی تصویر مرجع
            _grayCard(
              dark: dark,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _customerField(
                    icon: Icons.person_outline,
                    label: 'نام مشتری',
                    hint: 'نام مشتری',
                    controller: _nameCtrl,
                    dark: dark,
                    onChanged: (v) {
                      _customerName = v;
                      final i = _draftTabs.indexWhere((t) => t.id == _activeTabId);
                      if (i >= 0) {
                        final title = v.trim().isNotEmpty ? v.trim() : _autoTabTitle();
                        if (_draftTabs[i].title != title) {
                          setState(() => _draftTabs[i].title = title);
                        }
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _showCustomerPicker,
                      icon: Icon(Icons.people_alt_outlined, color: accent, size: 18),
                      label: Text(
                        'انتخاب مشتری از لیست',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _customerField(
                    icon: Icons.phone_outlined,
                    label: 'شماره مشتری',
                    hint: 'شماره مشتری',
                    controller: _phoneCtrl,
                    dark: dark,
                    isPhone: true,
                    onChanged: (v) => _customerPhone = v,
                  ),
                  const SizedBox(height: 14),
                  Divider(color: dark ? _slate700 : const Color(0xFFE8EBF2), height: 1),
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Expanded(
                          child: _metaInfo(
                            icon: Icons.description_outlined,
                            label: 'شماره فاکتور:',
                            value: PersianNumberFormatter.toPersian(_invoiceNumber),
                            dark: dark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _editInvoiceDate,
                            borderRadius: BorderRadius.circular(12),
                            child: _metaInfo(
                              icon: Icons.calendar_today_outlined,
                              label: 'تاریخ:',
                              value: _dateLabel,
                              dark: dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3) جدول اقلام
            Container(
              decoration: BoxDecoration(
                color: dark ? _slate800 : Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: dark
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF9AA7BD).withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  // هدر جدول — ترتیب RTL مطابق تصویر: عنوان | مقدار | قیمت واحد | قیمت کل
                  Container(
                    decoration: BoxDecoration(
                      color: dark? _slate700.withValues(alpha: 0.4): const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      border: Border(bottom: BorderSide(color: dark? _slate700: _cardGrayBorder)),
                    ),
                    child: Row(
                      children: [
                        // عنوان پهن‌تر برای نام محصول
                        _tableHeader('عنوان', flex: 5, dark: dark),
                        _tableHeader('مقدار', flex: 2, dark: dark),
                        _tableHeader('قیمت واحد', flex: 2, dark: dark),
                        _tableHeader('قیمت کل', flex: 2, dark: dark, isLast: true),
                      ],
                    ),
                  ),
                  // ردیف‌ها — شماره ردیف غیرقابل ادیت + ضربدر حذف با کلیک
                  ...List.generate(_items.length, (idx) {
                    final it = _items[idx];
                    final isSelected = _selectedRow == idx;
                    final rowNumber = PersianNumberFormatter.toPersian((idx + 1).toString());
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '$rowNumber -',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: dark ? _slate400 : _slate600,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: CompositedTransformTarget(
                                                      link: _productLink(idx),
                                                      child: TextField(
                                                        controller: (TextEditingController(text: it.title)
                                                          ..selection = TextSelection.collapsed(
                                                            offset: it.title.length,
                                                          )),
                                                        onChanged: (v) {
                                                          _updateItem(idx, title: v);
                                                          _markTyping(idx);
                                                        },
                                                        onTap: () => _markTyping(idx),
                                                        maxLines: 3,
                                                        minLines: 1,
                                                        textInputAction: TextInputAction.newline,
                                                        textDirection: TextDirection.rtl,
                                                        textAlign: TextAlign.right,
                                                        decoration: const InputDecoration(
                                                          filled: true,
                                                          fillColor: Colors.white,
                                                          border: InputBorder.none,
                                                          hintText: 'نام کالا / خدمت',
                                                          hintTextDirection: TextDirection.rtl,
                                                          contentPadding: EdgeInsets.zero,
                                                          isDense: true,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w800,
                                                          color: _slate800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // ضربدر در ابتدای/سمت چپ ردیف قرار می‌گیرد.
                                        if (isSelected)
                                          InkWell(
                                            onTap: () => _removeRow(idx),
                                            child: const Icon(Icons.close, size: 20, color: _slate500),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _tableCell(
                                flex: 2,
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
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ReplaceOnTypeNumberField(
                                        key: ValueKey('qty-${it.id}-$_formGen'),
                                        value: it.quantity,
                                        useThousandSeparator: false,
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
                                      const SizedBox(height: 3),
                                      Text(
                                        it.unit,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: dark ? _slate400 : _slate500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
                  // دو دکمهٔ پایین جدول، با همان اندازه و فرم تصویر مرجع
                  Container(
                    height: 66,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: dark ? _slate800 : Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          _referencePill(
                            icon: Icons.add,
                            label: 'افزودن ردیف',
                            color: accent,
                            onTap: _addItem,
                          ),
                          const SizedBox(width: 12),
                          _referencePill(
                            icon: Icons.qr_code_scanner,
                            label: 'لیست محصولات',
                            color: Colors.teal,
                            onTap: _showProductCatalog,
                          ),
                          const Spacer(),
                        ],
                      ),
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
                    style: TextStyle(
                      fontSize: 16,
                      color: dark ? Colors.white : _orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4) کارت هزینه ارسال / تخفیف / بیعانه / بدهی قبلی
            // در ویرایش، مقادیر واقعی با کنترلر پایدار نمایش داده می‌شوند
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: _checkAmountRow(
                        label: 'هزینه ارسال:',
                        value: _hasShipping,
                        dark: dark,
                        controller: _shippingCtrl,
                        onChanged: (v) {
                          setState(() {
                            _hasShipping = v;
                            if (!v) {
                              _shippingFee = 0;
                              _shippingCtrl.clear();
                            } else if (_shippingCtrl.text.isEmpty && _shippingFee > 0) {
                              _setCtrl(_shippingCtrl, _fmtAmt(_shippingFee));
                            }
                          });
                        },
                        onAmount: (n) => setState(() => _shippingFee = n),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _checkAmountRow(
                        label: 'تخفیف:',
                        value: _hasDiscount,
                        dark: dark,
                        controller: _discountCtrl,
                        onChanged: (v) {
                          setState(() {
                            _hasDiscount = v;
                            if (!v) {
                              _discountAmount = 0;
                              _discountCtrl.clear();
                            } else if (_discountCtrl.text.isEmpty && _discountAmount > 0) {
                              _setCtrl(_discountCtrl, _fmtAmt(_discountAmount));
                            }
                          });
                        },
                        onAmount: (n) => setState(() => _discountAmount = n),
                      ),
                    ),
                  ]),
                  if (_hasDiscount)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _discountIsPercent = true),
                            child: Text('درصد', style: TextStyle(fontSize: 12, color: _discountIsPercent ? _orange : _slate400, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => setState(() => _discountIsPercent = false),
                            child: Text('مبلغ', style: TextStyle(fontSize: 12, color: !_discountIsPercent ? _orange : _slate400, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Divider(color: dark ? _slate700 : _cardGrayBorder, height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _checkAmountRow(
                        label: 'بیعانه:',
                        value: _hasDeposit,
                        dark: dark,
                        controller: _depositCtrl,
                        onChanged: (v) {
                          setState(() {
                            _hasDeposit = v;
                            if (!v) {
                              _depositAmount = 0;
                              _depositCtrl.clear();
                            } else if (_depositCtrl.text.isEmpty && _depositAmount > 0) {
                              _setCtrl(_depositCtrl, _fmtAmt(_depositAmount));
                            }
                          });
                        },
                        onAmount: (n) => setState(() => _depositAmount = n),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _checkAmountRow(
                        label: 'بدهی قبلی:',
                        value: _hasPrevDebt,
                        dark: dark,
                        controller: _prevDebtCtrl,
                        onChanged: (v) {
                          setState(() {
                            _hasPrevDebt = v;
                            if (!v) {
                              _prevDebtAmount = 0;
                              _prevDebtCtrl.clear();
                            } else if (_prevDebtCtrl.text.isEmpty && _prevDebtAmount > 0) {
                              _setCtrl(_prevDebtCtrl, _fmtAmt(_prevDebtAmount));
                            }
                          });
                        },
                        onAmount: (n) => setState(() => _prevDebtAmount = n),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Divider(color: dark ? _slate700 : _cardGrayBorder, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جمع قابل پرداخت',
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.white : _slate800,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        PersianNumberFormatter.formatCurrency(_finalTotal),
                        style: TextStyle(
                          fontSize: 18,
                          color: dark ? Colors.white : _orange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 5) نوع پرداخت و نوع فاکتور در ردیف‌های جدا، مطابق تصویر مرجع
            _grayCard(
              dark: dark,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                children: [
                  _choiceRow(
                    title: 'نوع پرداخت',
                    dark: dark,
                    children: [
                      _radio(label: 'نقدی', value: 'cash', group: _paymentType, onChanged: (v) => setState(() => _paymentType = v!), dark: dark),
                      const SizedBox(width: 4),
                      _radio(label: 'غیر نقدی', value: 'non_cash', group: _paymentType, onChanged: (v) => setState(() => _paymentType = v!), dark: dark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: dark ? _slate700 : _cardGrayBorder, height: 1),
                  const SizedBox(height: 14),
                  _choiceRow(
                    title: 'نوع فاکتور',
                    dark: dark,
                    children: [
                      _radio(label: 'پیش فاکتور', value: 'proforma', group: _invoiceType, onChanged: (v) => setState(() => _invoiceType = v!), dark: dark),
                      const SizedBox(width: 4),
                      _radio(label: 'فاکتور فروش', value: 'sale', group: _invoiceType, onChanged: (v) => setState(() => _invoiceType = v!), dark: dark),
                      const SizedBox(width: 4),
                      _radio(label: 'فاکتور خرید', value: 'purchase', group: _invoiceType, onChanged: (v) => setState(() => _invoiceType = v!), dark: dark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // تیک نمایش مهر و امضا روی فاکتور
            _grayCard(
              dark: dark,
              child: Builder(builder: (ctx) {
                final st = ref.watch(settingsProvider);
                final biz = ref.watch(businessProvider);
                return Column(
                  children: [
                    _checkRow(
                      label: 'نمایش مهر و امضا روی فاکتور',
                      value: st.showStamp,
                      dark: dark,
                      onChanged: (v) {
                        final enabled = v ?? false;
                        ref.read(settingsProvider.notifier).updateSettings(
                              st.copyWith(showStamp: enabled, showSignature: enabled),
                            );
                      },
                      trailing: (biz.stampPath.isEmpty && biz.signaturePath.isEmpty)
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
                    const SizedBox(height: 4),
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
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                  hintText: 'توضیحات',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(color: _slate400, fontSize: 12),
                ),
                style: const TextStyle(fontSize: 12, color: _slate800),
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
                      ? accent
                      : (dark ? _slate800 : _cardGray),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEditing
                        ? accent
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
      // ناوبری اصلی چهارگزینه‌ای دقیقاً مثل تصویر مرجع
      bottomNavigationBar: _referenceNavigation(dark),
    );
  }

  // ── Helpers ──
  Widget _referencePill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductCatalog() {
    final products = ref.read(productListProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.58,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Text(
                  'لیست محصولات',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text('کاتالوگ خالی است'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final product = products[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: const Color(0xFFF7F8FC),
                            title: Text(
                              product.name,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              PersianNumberFormatter.formatCurrency(product.sellPrice),
                              textAlign: TextAlign.right,
                            ),
                            trailing: const Icon(Icons.add_circle_outline, color: _orange),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                final emptyIdx = _items.indexWhere(
                                  (e) => e.title.trim().isEmpty && e.unitPrice == 0,
                                );
                                final row = InvoiceItemModel(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  title: product.name,
                                  quantity: 1,
                                  unit: product.unit,
                                  unitPrice: product.sellPrice,
                                  totalPrice: product.sellPrice,
                                );
                                if (emptyIdx >= 0) {
                                  _items[emptyIdx] = row;
                                  _selectedRow = emptyIdx;
                                } else {
                                  _items.add(row);
                                  _selectedRow = _items.length - 1;
                                }
                                _formGen++;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grayCard({required bool dark, required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF9AA7BD).withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  /// ردیف فیلد مشتری با آیکن و لیبل سمت راست، مطابق تصویر مرجع.
  Widget _customerField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool dark,
    required ValueChanged<String> onChanged,
    bool isPhone = false,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Icon(icon, color: accent, size: 25),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: dark ? _slate400 : _slate700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: isPhone ? TextInputType.phone : TextInputType.name,
              textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                filled: true,
                fillColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
                hintText: hint,
                hintTextDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
                hintStyle: TextStyle(
                  color: dark ? _slate400 : const Color(0xFF9AA1AF),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.45), width: 1.2),
                ),
              ),
              style: TextStyle(
                color: dark ? Colors.white : _slate800,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaInfo({
    required IconData icon,
    required String label,
    required String value,
    required bool dark,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: TextStyle(
                  color: dark ? Colors.white : _slate800,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: fontFamily,
                ),
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// فیلد مشتری: لیبل بالا + یک Outline تمیز (بدون تکه سفید اضافه)
  Widget _labeledInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool dark,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    final isPhone = keyboardType == TextInputType.phone;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 6),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              color: dark ? _slate400 : _slate500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            isCollapsed: false,
            filled: true,
            fillColor: dark ? const Color(0xFF0F172A) : Colors.white,
            hintText: hint,
            hintTextDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
            hintStyle: TextStyle(
              fontSize: 12,
              color: dark ? _slate400.withValues(alpha: 0.65) : const Color(0xFF94A3B8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? _slate600 : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: dark ? _slate600 : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : _slate800,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  /// چک‌باکس + فیلد مبلغ — در ویرایش مقدار واقعی فاکتور نمایش داده می‌شود
  Widget _checkAmountRow({
    required String label,
    required bool value,
    required bool dark,
    required TextEditingController controller,
    required ValueChanged<bool> onChanged,
    required ValueChanged<double> onAmount,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: BorderSide(color: dark ? _slate500 : _slate400),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (value) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 96,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                ThousandSeparatorInputFormatter(allowDecimal: true),
              ],
              onTap: () {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              },
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  onAmount(0);
                  return;
                }
                onAmount(ThousandSeparatorInputFormatter.parseToDouble(v) ?? 0);
              },
              decoration: InputDecoration(
                hintText: '۰',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: dark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: dark ? _slate600 : const Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: dark ? _slate600 : const Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 1.4),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : _slate800,
              ),
            ),
          ),
        ],
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

  Widget _choiceRow({
    required String title,
    required bool dark,
    required List<Widget> children,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white : _slate700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(children: children),
            ),
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
        Text(label, style: TextStyle(fontSize: 10, color: selected? _orange: (dark? _slate400: _slate500), fontWeight: selected? FontWeight.w800: FontWeight.w500)),
        const SizedBox(width: 3),
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected? _orange: _slate400, width: 2), color: selected? _orange: Colors.transparent),
          child: selected? const Center(child: Icon(Icons.circle, size: 9, color: Colors.white)): null,
        ),
      ]),
    );
  }

  Widget _referenceNavigation(bool dark) {
    final accent = Color(ref.watch(settingsProvider).accentColor);
    final inactive = dark ? _slate400 : const Color(0xFF4B5563);

    return Container(
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        border: Border(top: BorderSide(color: dark ? _slate700 : const Color(0xFFE8EBF2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: _navItem(
                    icon: Icons.settings_outlined,
                    label: 'تنظیمات',
                    color: inactive,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
                Expanded(
                  child: _navItem(
                    icon: Icons.people_outline,
                    label: 'مشتریان',
                    color: inactive,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                    ),
                  ),
                ),
                Expanded(
                  child: _navItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'فاکتورها',
                    color: inactive,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InvoiceListScreen()),
                    ),
                  ),
                ),
                Expanded(
                  child: _navItem(
                    icon: Icons.home,
                    label: 'خانه',
                    color: accent,
                    active: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: active ? 28 : 26),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomTabs(bool dark) {
    final accent = Color(ref.watch(settingsProvider).accentColor);
    // عنوان تب‌ها را تازه نگه دار
    final activeIdx = _draftTabs.indexWhere((t) => t.id == _activeTabId);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        border: Border(top: BorderSide(color: dark ? _slate700 : _cardGrayBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // + فاکتور/شیت جدید
          InkWell(
            onTap: _addNewDraftTab,
            child: Container(
              width: 48,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: dark ? _slate700 : _cardGrayBorder)),
              ),
              child: Icon(Icons.add, color: accent, size: 26),
            ),
          ),
          // تب‌های باز
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // RTL: تب‌ها از راست
              itemCount: _draftTabs.length,
              itemBuilder: (_, i) {
                final t = _draftTabs[i];
                final active = t.id == _activeTabId;
                return InkWell(
                  onTap: () => _switchToTab(t.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? (dark ? _slate700 : const Color(0xFFF1F5F9))
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(color: dark ? _slate700 : _cardGrayBorder),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? accent : (dark ? _slate400 : _slate600),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_up, color: accent, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // همبرگر: لیست پنجره‌های باز
          InkWell(
            onTap: _showOpenWindowsSheet,
            child: Container(
              width: 48,
              height: 52,
              alignment: Alignment.center,
              child: Icon(Icons.menu, color: dark ? Colors.white : _slate700),
            ),
          ),
        ],
      ),
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
