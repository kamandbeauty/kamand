import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/bank_card_model.dart';
import '../../providers/bank_card_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _cardGray = Color(0xFFF1F5F9);
const _cardBorder = Color(0xFFE2E8F0);

/// حداکثر ارقام شبا بدون IR (استاندارد ایران: IR + ۲۴ رقم)
const int kShebaDigitsMax = 24;
const int kCardDigitsMax = 16;

class CardCreateScreen extends ConsumerStatefulWidget {
  final BankCardModel? editCard;
  const CardCreateScreen({super.key, this.editCard});
  @override
  ConsumerState<CardCreateScreen> createState() => _CardCreateScreenState();
}

class _CardCreateScreenState extends ConsumerState<CardCreateScreen> {
  late TextEditingController _cardCtrl;
  late TextEditingController _shebaCtrl;
  late TextEditingController _nameCtrl;
  String _bankName = '';

  final List<String> _banks = const [
    'بانک ملت',
    'بانک ملی',
    'بانک صادرات',
    'بانک تجارت',
    'بانک سپه',
    'بانک کشاورزی',
    'بانک پارسیان',
    'بانک مسکن',
    'پست بانک',
    'بانک اقتصاد نوین',
    'بانک کارآفرین',
    'بانک سینا',
    'بانک سرمایه',
    'بانک شهر',
    'بانک دی',
    'بانک پاسارگاد',
    'بانک سامان',
    'بانک انصار',
    'بانک توسعه تعاون',
    'بانک قوامین',
    'بانک حکمت ایرانیان',
    'بانک ایران زمین',
    'بانک گردشگری',
    'بانک صنعت و معدن',
    'بانک توسعه صادرات',
    'بانک مهر اقتصاد',
    'بانک ایران ونزوئلا',
    'بانک قرض الحسنه رسالت',
    'موسسه ملل',
    'بانک آینده',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editCard;
    _cardCtrl = TextEditingController(text: e?.cardNumber ?? '');
    // فقط ارقام شبا (بدون IR)
    final shebaRaw = (e?.sheba ?? '').replaceAll(RegExp(r'[^0-9۰-۹]'), '');
    _shebaCtrl = TextEditingController(text: _faToEn(shebaRaw));
    _nameCtrl = TextEditingController(text: e?.persianName ?? '');
    _bankName = e?.bankName ?? '';
    if (_cardCtrl.text.isNotEmpty) _autoDetectBank(_cardCtrl.text);
    _cardCtrl.addListener(() => _autoDetectBank(_cardCtrl.text));
  }

  void _autoDetectBank(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      final detected = detectBankName(digits);
      if (detected.isNotEmpty && detected != _bankName && _banks.contains(detected)) {
        setState(() => _bankName = detected);
      } else if (detected.isNotEmpty && detected != _bankName) {
        // اگر در لیست نبود ولی تشخیص داده شد
        setState(() => _bankName = detected);
      }
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _shebaCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _faToEn(String s) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var r = s;
    for (int i = 0; i < 10; i++) {
      r = r.replaceAll(fa[i], en[i]);
    }
    return r;
  }

  String _onlyDigits(String s) => _faToEn(s).replaceAll(RegExp(r'\D'), '');

  /// گروه‌بندی ۴تایی شماره کارت — ترتیب LTR حفظ می‌شود
  String _formatCardGroups(String digits) {
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// شبا: IR + گروه‌های ۴تایی (۲۴ رقم)
  String _formatShebaPreview(String digits) {
    if (digits.isEmpty) return '';
    final limited = digits.length > kShebaDigitsMax ? digits.substring(0, kShebaDigitsMax) : digits;
    final withIr = 'IR$limited';
    final buf = StringBuffer();
    for (int i = 0; i < withIr.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(withIr[i]);
    }
    return buf.toString();
  }

  void _save() {
    final card = _onlyDigits(_cardCtrl.text);
    var sheba = _onlyDigits(_shebaCtrl.text);
    // اگر کاربر IR را هم تایپ کرده باشد
    if (sheba.length > kShebaDigitsMax) {
      sheba = sheba.substring(sheba.length - kShebaDigitsMax);
    }
    final name = _nameCtrl.text.trim();

    if (card.length != kCardDigitsMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شماره کارت باید ۱۶ رقم باشد')),
      );
      return;
    }
    if (sheba.isNotEmpty && sheba.length != kShebaDigitsMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شماره شبا باید دقیقاً ۲۴ رقم باشد (بدون IR)')),
      );
      return;
    }
    if (_bankName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بانک را انتخاب کنید')),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام فارسی را وارد کنید')),
      );
      return;
    }

    final isEdit = widget.editCard != null;
    final model = BankCardModel(
      id: isEdit ? widget.editCard!.id : 'card-${DateTime.now().millisecondsSinceEpoch}',
      cardNumber: card,
      sheba: sheba,
      bankName: _bankName,
      persianName: name,
    );
    if (isEdit) {
      ref.read(bankCardListProvider.notifier).updateCard(model);
    } else {
      ref.read(bankCardListProvider.notifier).addCard(model);
    }
    ref.read(selectedBankCardProvider.notifier).state = model;
    if (!mounted) return;
    Navigator.of(context).pop(); // بستن صفحه ایجاد کارت
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کارت ذخیره شد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardDigits = _onlyDigits(_cardCtrl.text);
    final shebaDigits = _onlyDigits(_shebaCtrl.text);
    final previewName = _nameCtrl.text.trim();
    final previewBank = _bankName;
    final shebaCount = shebaDigits.length > kShebaDigitsMax ? kShebaDigitsMax : shebaDigits.length;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.editCard == null ? 'ایجاد کارت' : 'ویرایش کارت',
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            // ── پیش‌نمایش کارت ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : _cardGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ردیف بالا: لوگو + نام بانک و شخص — همه سمت راست
                  Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // لوگو درشت، بدون بک‌گراند سفید
                      _buildBankLogo(previewBank, size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // در RTL = راست
                          children: [
                            Text(
                              previewBank.isEmpty ? 'بانک' : previewBank,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: dark ? _slate400 : _slate500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              previewName.isEmpty ? 'نام صاحب کارت' : previewName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: dark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // شماره شبا — LTR برای جلوگیری از برعکس شدن، تراز راست کارت
                  if (shebaDigits.isNotEmpty)
                    _ltrRightAlignedText(
                      PersianNumberFormatter.toPersian(_formatShebaPreview(shebaDigits)),
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: dark ? _slate400 : _slate500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        height: 12,
                        width: 160,
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF334155) : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // شماره کارت — LTR + راست‌چین (مثل نمونه)
                  if (cardDigits.isNotEmpty)
                    _ltrRightAlignedText(
                      PersianNumberFormatter.toPersian(_formatCardGroups(cardDigits)),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: dark ? Colors.white : const Color(0xFF0F172A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        height: 16,
                        width: 200,
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF334155) : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // شماره کارت
            _fieldLabel('شماره کارت'),
            const SizedBox(height: 6),
            _buildField(
              dark: dark,
              controller: _cardCtrl,
              hint: '۱۶ رقم شماره کارت',
              keyboardType: TextInputType.number,
              maxLength: kCardDigitsMax,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')),
                LengthLimitingTextInputFormatter(kCardDigitsMax),
              ],
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${PersianNumberFormatter.toPersian(cardDigits.length.toString())} / ۱۶',
                  style: TextStyle(fontSize: 11, color: _slate400),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // شماره شبا — محدودیت ۲۴ رقم
            _fieldLabel('شماره شبا'),
            const SizedBox(height: 6),
            _buildField(
              dark: dark,
              controller: _shebaCtrl,
              hint: '۲۴ رقم (بدون IR)',
              keyboardType: TextInputType.number,
              maxLength: kShebaDigitsMax,
              prefixText: 'IR',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')),
                LengthLimitingTextInputFormatter(kShebaDigitsMax),
                _ShebaDigitsFormatter(),
              ],
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${PersianNumberFormatter.toPersian(shebaCount.toString())} / ۲۴ رقم',
                  style: TextStyle(
                    fontSize: 11,
                    color: shebaCount == kShebaDigitsMax ? const Color(0xFF16A34A) : _slate400,
                    fontWeight: shebaCount == kShebaDigitsMax ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // بانک
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('بانک', style: TextStyle(fontSize: 12, color: _slate500)),
                  const Text(' *', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : _cardGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _banks.contains(_bankName) ? _bankName : null,
                  hint: Text('انتخاب کنید', style: TextStyle(color: _slate400, fontSize: 13)),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: _slate500),
                  dropdownColor: dark ? const Color(0xFF1E293B) : Colors.white,
                  items: _banks.map((b) {
                    return DropdownMenuItem(
                      value: b,
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          _buildBankLogo(b, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _bankName = v ?? ''),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // نام فارسی
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('نام فارسی', style: TextStyle(fontSize: 12, color: _slate500)),
                  const Text(' *', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildField(
              dark: dark,
              controller: _nameCtrl,
              hint: 'نام صاحب کارت',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'ذخیره',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// متن LTR که به سمت راست کارت می‌چسبد — جلوگیری از برعکس شدن ارقام
  Widget _ltrRightAlignedText(String text, {required TextStyle style}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.left, // داخل LTR، شروع از چپِ بلوک که خودش راستِ کارت است
        ),
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(t, style: TextStyle(fontSize: 12, color: _slate500)),
    );
  }

  Widget _buildBankLogo(String bankName, {double size = 64}) {
    final asset = bankLogoAsset(bankName);
    if (asset.isNotEmpty) {
      // بدون بک‌گراند سفید — فقط خود لوگو
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _logoFallback(bankName, size),
        ),
      );
    }
    if (bankName.isNotEmpty) {
      return _logoFallback(bankName, size);
    }
    // حالت خالی
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.account_balance, color: _orange.withValues(alpha: 0.5), size: size * 0.55),
    );
  }

  Widget _logoFallback(String bankName, double size) {
    final label = bankName.replaceAll('بانک ', '');
    final letter = label.isNotEmpty ? label.substring(0, 1) : 'ب';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bankColor(bankName),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  Widget _buildField({
    required bool dark,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : _cardGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _slate400, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          counterText: '',
          prefixIcon: prefixText != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, right: 2),
                  child: Align(
                    widthFactor: 1,
                    alignment: Alignment.center,
                    child: Text(
                      prefixText,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: dark ? Colors.white70 : _slate500,
                      ),
                    ),
                  ),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : Colors.black,
          letterSpacing: keyboardType == TextInputType.number ? 0.8 : 0,
        ),
        textAlign: TextAlign.right,
        textDirection: keyboardType == TextInputType.number ? TextDirection.ltr : TextDirection.rtl,
      ),
    );
  }
}

/// فقط ارقام شبا را نگه می‌دارد و IR را از ورودی حذف می‌کند
class _ShebaDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text;
    // حذف IR/ir در ابتدا
    t = t.replaceFirst(RegExp(r'^[Ii][Rr]'), '');
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < 10; i++) {
      t = t.replaceAll(fa[i], '$i');
    }
    t = t.replaceAll(RegExp(r'\D'), '');
    if (t.length > kShebaDigitsMax) {
      t = t.substring(0, kShebaDigitsMax);
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
