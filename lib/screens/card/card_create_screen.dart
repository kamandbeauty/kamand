import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/bank_card_model.dart';
import '../../providers/bank_card_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate600 = Color(0xFF475569);
const _cardGray = Color(0xFFF1F5F9);
const _cardBorder = Color(0xFFE2E8F0);

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
    'بانک ملت','بانک ملی','بانک سپه','بانک تجارت','بانک صادرات','بانک پارسیان','بانک پاسارگاد','بانک سامان','بانک سینا','بانک شهر','بانک آینده','بانک کشاورزی'
  ];

  @override
  void initState(){
    super.initState();
    final e = widget.editCard;
    _cardCtrl = TextEditingController(text: e?.cardNumber ?? '');
    _shebaCtrl = TextEditingController(text: e?.sheba ?? '');
    _nameCtrl = TextEditingController(text: e?.persianName ?? '');
    _bankName = e?.bankName ?? '';
    if(_cardCtrl.text.isNotEmpty) _autoDetectBank(_cardCtrl.text);
    _cardCtrl.addListener(()=> _autoDetectBank(_cardCtrl.text));
  }
  void _autoDetectBank(String v){
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if(digits.length >= 4){
      final detected = detectBankName(digits);
      if(detected.isNotEmpty && detected != _bankName){
        setState(()=> _bankName = detected);
      }
    }
  }
  @override
  void dispose(){
    _cardCtrl.dispose(); _shebaCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  void _save(){
    final card = _cardCtrl.text.replaceAll(RegExp(r'\D'), '');
    final sheba = _shebaCtrl.text.replaceAll(RegExp(r'\D'), '');
    final name = _nameCtrl.text.trim();
    if(card.length != 16){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره کارت باید ۱۶ رقم باشد')));
      return;
    }
    if(_bankName.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بانک را انتخاب کنید')));
      return;
    }
    if(name.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام فارسی را وارد کنید')));
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
    if(isEdit){
      ref.read(bankCardListProvider.notifier).updateCard(model);
    } else {
      ref.read(bankCardListProvider.notifier).addCard(model);
    }
    ref.read(selectedBankCardProvider.notifier).state = model;
    Navigator.pop(context);
    Navigator.pop(context); // close list sheet if open
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کارت ذخیره شد')));
  }

  @override
  Widget build(BuildContext context){
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardDigits = _cardCtrl.text.replaceAll(RegExp(r'\D'), '');
    final shebaDigits = _shebaCtrl.text.replaceAll(RegExp(r'\D'), '');
    final previewCard = cardDigits.isNotEmpty ? cardDigits : '';
    final previewSheba = shebaDigits.isNotEmpty ? shebaDigits : '';
    final previewName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '';
    final previewBank = _bankName;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: dark? Colors.white: Colors.black), onPressed: ()=> Navigator.pop(context)),
        centerTitle: true,
        title: Text('ایجاد کارت', style: TextStyle(color: dark? Colors.white: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            // Preview card — animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardGray, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(children: [
                    _buildBankLogo(previewBank, size: 48),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(previewBank.isEmpty ? 'بانک' : previewBank, style: TextStyle(fontSize: 12, color: _slate500)),
                      const SizedBox(height: 4),
                      Text(previewName.isEmpty ? 'نام' : previewName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: dark? Colors.white: Colors.black)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  // card number + sheba preview
                  if(previewCard.isEmpty && previewSheba.isEmpty)
                    Column(children: [
                      Container(height: 14, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                    ])
                  else ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(key: ValueKey(previewCard+previewSheba), children: [
                        if(previewSheba.isNotEmpty)
                          Text('IR${PersianNumberFormatter.toPersian(previewSheba)}'.replaceAllMapped(RegExp(r'.{4}'), (m)=> '${m.group(0)} ').trim(), style: const TextStyle(fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(previewCard.isEmpty ? '' : PersianNumberFormatter.toPersian(previewCard).replaceAllMapped(RegExp(r'.{4}'), (m)=> '${m.group(0)} ').trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(height: 1, color: _cardBorder),
                  const SizedBox(height: 8),
                  Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // شماره کارت
            Align(alignment: Alignment.centerRight, child: Text('شماره کارت', style: TextStyle(fontSize: 12, color: _slate500))),
            const SizedBox(height: 6),
            _buildField(
              dark: dark,
              controller: _cardCtrl,
              hint: 'اینجا بنویس',
              keyboardType: TextInputType.number,
              maxLength: 16,
              onChanged: (_)=> setState((){}),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: Text('شماره شبا', style: TextStyle(fontSize: 12, color: _slate500))),
            const SizedBox(height: 6),
            _buildField(dark: dark, controller: _shebaCtrl, hint: 'اینجا بنویس', keyboardType: TextInputType.number, onChanged: (_)=> setState((){})),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('بانک', style: TextStyle(fontSize: 12, color: _slate500)), const Text(' *', style: TextStyle(color: Colors.red)) ])),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _cardGray, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _banks.contains(_bankName) ? _bankName : null,
                  hint: Text('انتخاب کنید', style: TextStyle(color: _slate400, fontSize: 13)),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: _slate500),
                  items: _banks.map((b)=> DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v)=> setState(()=> _bankName = v!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('نام فارسی', style: TextStyle(fontSize: 12, color: _slate500)), const Text(' *', style: TextStyle(color: Colors.red)) ])),
            const SizedBox(height: 6),
            _buildField(dark: dark, controller: _nameCtrl, hint: 'اینجا بنویس', onChanged: (_)=> setState((){})),
            const SizedBox(height: 20),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('ذخیره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankLogo(String bankName, {double size = 48}){
    final asset = bankLogoAsset(bankName);
    if(asset.isNotEmpty){
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(asset, width: size, height: size * 0.66, fit: BoxFit.contain, errorBuilder: (_,__,___)=> Container(width: size, height: size*0.66, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.account_balance, color: bankColor(bankName), size: 22))),
      );
    }
    if(bankName.isNotEmpty){
      return Container(
        width: size, height: size*0.66,
        decoration: BoxDecoration(color: bankColor(bankName), borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(bankName.replaceAll('بانک ', '').substring(0,1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      );
    }
    return Container(width: size, height: size*0.66, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.account_balance, color: _orange, size: 22));
  }

  Widget _buildField({required bool dark, required TextEditingController controller, required String hint, TextInputType? keyboardType, int? maxLength, Function(String)? onChanged}){
    return Container(
      decoration: BoxDecoration(color: _cardGray, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _slate400, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          counterText: '',
        ),
        style: TextStyle(fontSize: 13, color: dark? Colors.white: Colors.black),
        textAlign: TextAlign.right,
      ),
    );
  }
}
