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
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Form state — متصل به دیتابیس واقعی (§29)
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

  @override
  void initState() {
    super.initState();
    _dateLabel = _todayLabel();
    // یک ردیف پیش‌فرض مثل عکس (۱ عدد)
    _items = [
      InvoiceItemModel(id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0),
    ];
    // شماره بعدی از settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      if (settings.startingInvoiceNum > 0) {
        setState(() => _invoiceNumber = PersianNumberFormatter.toPersian(settings.startingInvoiceNum.toString()));
      }
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
  double get _finalTotal {
    double t = _itemsTotal;
    if (_hasDiscount) t -= _discountAmount;
    if (_hasShipping) t += _shippingFee;
    if (_hasPrevDebt) t += _prevDebtAmount;
    // بیعانه کم نمی‌شود چون پرداخت جداست
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
    if (_items.isEmpty || _items.every((e) => e.title.trim().isEmpty && e.unitPrice == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حداقل یک قلم کالا اضافه کنید')));
      return;
    }
    final biz = ref.read(businessProvider);
    final card = biz.bankCards.isNotEmpty ? biz.bankCards.first : '';
    // شماره را به انگلیسی برگردانیم
    String numEn = _invoiceNumber;
    const persian = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    const english = ['0','1','2','3','4','5','6','7','8','9'];
    for (int i=0;i<10;i++) numEn = numEn.replaceAll(persian[i], english[i]);
    final jalaliEn = JalaliHelper.getTodayJalali();
    final jalali = PersianNumberFormatter.toPersian(jalaliEn);
    final inv = InvoiceModel(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      number: numEn,
      customerId: 'c-${DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerName.isEmpty ? 'مشتری عمومی' : _customerName,
      customerPhone: _customerPhone,
      type: _invoiceType == 'sale' ? 'sale' : (_invoiceType == 'purchase' ? 'purchase' : 'proforma'),
      paymentType: _paymentType,
      status: _invoiceType == 'proforma' ? 'proforma' : (_paymentType == 'cash' ? 'paid' : 'unpaid'),
      date: jalali,
      items: _items.where((e) => e.title.trim().isNotEmpty || e.totalPrice>0).toList(),
      subtotal: _itemsTotal,
      discountPercent: _discountIsPercent ? _discountAmount : 0,
      discountAmount: _hasDiscount ? _discountAmount : 0,
      shippingFee: _hasShipping ? _shippingFee : 0,
      previousDebt: _hasPrevDebt ? _prevDebtAmount : 0,
      deposit: _hasDeposit ? _depositAmount : 0,
      totalAmount: _finalTotal,
      paidAmount: _paymentType == 'cash' ? _finalTotal : _depositAmount,
      remainingAmount: _paymentType == 'cash' ? 0 : (_finalTotal - _depositAmount).clamp(0, double.infinity),
      notes: _notes,
      cardNumber: card,
      createdAt: jalali,
    );
    ref.read(invoiceListProvider.notifier).saveInvoice(inv);
    // اگر مشتری جدید است به لیست مشتریان اضافه کن
    if (_customerName.isNotEmpty) {
      final exists = ref.read(customerListProvider).any((c) => c.name == _customerName);
      if (!exists) {
        // import نمایش داده نمی‌شود تا فایل سبک بماند — provider موجود balance را صفر می‌گیرد
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فاکتور #${PersianNumberFormatter.toPersian(numEn)} ذخیره شد')));
    // تب جدید
    setState(() {
      _invoiceNumber = PersianNumberFormatter.toPersian((int.tryParse(numEn) ?? 1004) + 1 as dynamic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final business = ref.watch(businessProvider);
    final shopName = business.shopName.isNotEmpty ? business.shopName : 'فاکتور ساز روبی';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: dark ? _slate900 : Colors.white,
      drawer: _buildDrawer(),
      // هدر دقیقاً مثل عکس: سفید، ستاره/لوگو چپ، عنوان وسط، همبرگر راست
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: dark ? _slate800 : Colors.white,
          elevation: 0,
          centerTitle: true,
          leadingWidth: 48,
          leading: InkWell(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/logo.png',
                  width: 24, height: 24, fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 22),
                ),
              ),
            ),
          ),
          title: Text(shopName, style: TextStyle(color: dark? Colors.white: _slate800, fontWeight: FontWeight.w900, fontSize: 16)),
          actions: [
            IconButton(icon: Icon(Icons.menu, color: dark? Colors.white: _slate700), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: dark? _slate700: _cardGrayBorder)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) دکمه سربرگ — نارنجی روبی (عکس آبی بود، روبی نارنجی)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('برای افزودن سربرگ کلیک کنید', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 12),

            // 2) کارت اطلاعات مشتری
            _grayCard(
              dark: dark,
              child: Column(
                children: [
                  _customerField(label: 'نام مشتری:', value: _customerName, hint: '', onChanged: (v)=> setState(()=> _customerName=v), dark: dark),
                  const SizedBox(height: 10),
                  _customerField(label: 'شماره مشتری:', value: _customerPhone, hint: '', onChanged: (v)=> setState(()=> _customerPhone=v), dark: dark, keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  Divider(color: dark? _slate700: _cardGrayBorder, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Row(children: [
                        Text('شماره فاکتور:', style: TextStyle(fontSize: 11, color: dark? _slate400: _slate500)),
                        const SizedBox(width: 6),
                        Text(PersianNumberFormatter.toPersian(_invoiceNumber), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark? Colors.white: _slate800)),
                        const SizedBox(width: 6),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
                      ])),
                      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Flexible(child: Text('تاریخ: $_dateLabel', style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate800, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ])),
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
                  // هدر جدول
                  Container(
                    decoration: BoxDecoration(
                      color: dark? _slate700.withValues(alpha: 0.4): const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: dark? _slate700: _cardGrayBorder)),
                    ),
                    child: Row(
                      children: [
                        _tableHeader('عنوان', flex: 3, dark: dark),
                        _tableHeader('مقدار', dark: dark),
                        _tableHeader('واحد', dark: dark),
                        _tableHeader('قیمت واحد', dark: dark),
                        _tableHeader('قیمت کل', dark: dark),
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
                        child: Row(
                          children: [
                            // عنوان + شماره ردیف ثابت + ضربدر
                            Expanded(flex: 3, child: _tableCell(
                              child: Row(
                                children: [
                                  // ضربدر فقط برای ردیف انتخاب‌شده
                                  if (isSelected)
                                    InkWell(
                                      onTap: () => _removeRow(idx),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.close, size: 18, color: _slate500),
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 22),
                                  // شماره ردیف غیرقابل ادیت
                                  Text(' $rowNum -', style: TextStyle(fontSize: 11, color: dark? _slate400: _slate500, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: it.title),
                                      onChanged: (v)=> _updateItem(idx, title: v),
                                      onTap: () => setState(() => _selectedRow = idx),
                                      decoration: const InputDecoration(border: InputBorder.none, hintText: '', contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
                                      style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              dark: dark, isFirst: true,
                            )),
                            _tableCell(child: TextField(
                              controller: TextEditingController(text: it.quantity == it.quantity.roundToDouble() ? PersianNumberFormatter.toPersian(it.quantity.toInt().toString()) : PersianNumberFormatter.toPersian(it.quantity.toString())),
                              keyboardType: TextInputType.number,
                              onChanged: (v){
                                final en = _faToEn(v);
                                final q = double.tryParse(en) ?? 1;
                                _updateItem(idx, qty: q);
                              },
                              onTap: () => setState(() => _selectedRow = idx),
                              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
                              style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800),
                              textAlign: TextAlign.center,
                            ), dark: dark),
                            _tableCell(child: InkWell(
                              onTap: (){
                                setState(()=> _selectedRow = idx);
                                showDialog(context: context, builder: (c)=> SimpleDialog(title: const Text('انتخاب واحد'), children: ['عدد','بسته','کیلو','متر','ساعت'].map((u)=> SimpleDialogOption(child: Text(u), onPressed: (){ Navigator.pop(c); _updateItem(idx, unit: u);})).toList()));
                              },
                              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(it.unit, style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate700), textAlign: TextAlign.center)),
                            ), dark: dark),
                            _tableCell(child: TextField(
                              controller: TextEditingController(text: it.unitPrice==0? '' : PersianNumberFormatter.toPersian(it.unitPrice.toInt().toString())),
                              keyboardType: TextInputType.number,
                              onChanged: (v){
                                final en=_faToEn(v);
                                final p=double.tryParse(en)??0;
                                _updateItem(idx, price: p);
                              },
                              onTap: () => setState(() => _selectedRow = idx),
                              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
                              style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate800),
                              textAlign: TextAlign.center,
                            ), dark: dark),
                            _tableCell(child: Text(it.totalPrice==0? '۰' : PersianNumberFormatter.formatCurrency(it.totalPrice).replaceAll(' تومان',''), style: TextStyle(fontSize: 11, color: dark? Colors.white: _slate800, fontWeight: FontWeight.w700), textAlign: TextAlign.center), dark: dark, isLast: true),
                          ],
                        ),
                      ),
                    );
                  }),
                  // دکمه ایجاد
                  InkWell(
                    onTap: _addItem,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('ایجاد', style: TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(width: 22, height: 22, decoration: BoxDecoration(color: _orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.add, color: _orange, size: 16)),
                        const SizedBox(width: 12),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // جمع آیتم‌ها
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(PersianNumberFormatter.formatCurrency(_itemsTotal), style: TextStyle(fontSize: 12, color: dark? _slate400: _slate500)),
                Text('جمع آیتم‌ها', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark? Colors.white: _slate700)),
              ]),
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

            // 6) جمع کل
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(PersianNumberFormatter.formatCurrency(_finalTotal), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark? Colors.white: _slate800)),
                Text('جمع کل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark? Colors.white: _slate700)),
              ]),
            ),
            const SizedBox(height: 10),

            // 7) توضیحات
            _grayCard(
              dark: dark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                onChanged: (v)=> _notes=v,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(border: InputBorder.none, hintText: 'توضیحات', hintStyle: TextStyle(color: _slate400, fontSize: 12)),
                style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800),
              ),
            ),
            const SizedBox(height: 10),

            // 8) افزودن شماره کارت
            _grayCard(
              dark: dark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(children: [
                Icon(Icons.chevron_left, color: _slate400, size: 20),
                const Spacer(),
                Text('افزودن شماره کارت', style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 10),

            // 9) ذخیره و اشتراک‌گذاری
            InkWell(
              onTap: _saveInvoice,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 56,
                decoration: BoxDecoration(color: dark? _slate800: _cardGray, borderRadius: BorderRadius.circular(12), border: Border.all(color: dark? _slate700: _cardGrayBorder)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.share, color: _slate600, size: 20),
                  const SizedBox(width: 8),
                  Text('ذخیره و اشتراک گذاری فاکتور', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: dark? Colors.white: _slate800)),
                ]),
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

  Widget _customerField({required String label, required String value, required String hint, required Function(String) onChanged, required bool dark, TextInputType? keyboardType}) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 11, color: dark? _slate400: _slate500))),
        Expanded(child: Container(
          height: 36,
          decoration: BoxDecoration(color: dark? _slate700: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: dark? _slate700: _cardGrayBorder)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            onChanged: onChanged,
            keyboardType: keyboardType,
            decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(fontSize: 11, color: _slate400), isDense: true),
            style: TextStyle(fontSize: 12, color: dark? Colors.white: _slate800),
            textAlign: TextAlign.right,
          ),
        )),
      ],
    );
  }

  Widget _tableHeader(String t, {int flex=1, required bool dark}) {
    return Expanded(flex: flex, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: dark? _slate700: _cardGrayBorder))),
      child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: dark? _slate400: _slate600, fontWeight: FontWeight.w700)),
    ));
  }
  Widget _tableCell({required Widget child, required bool dark, bool isFirst=false, bool isLast=false}) {
    return Expanded(child: Container(
      decoration: BoxDecoration(border: Border(left: isLast? BorderSide.none: BorderSide(color: dark? _slate700: _cardGrayBorder))),
      child: child,
    ));
  }

  Widget _checkRow({required String label, required bool value, required Function(bool?) onChanged, required bool dark, Widget? trailing}) {
    return Row(children: [
      SizedBox(
        width: 22, height: 22,
        child: Checkbox(value: value, onChanged: onChanged, activeColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), side: BorderSide(color: dark? _slate500: _slate400)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: dark? _slate400: _slate500)),
      if (trailing!=null) ...[const Spacer(), trailing],
    ]);
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
