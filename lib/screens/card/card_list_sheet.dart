import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/bank_card_provider.dart';
import '../../models/bank_card_model.dart';
import 'card_create_screen.dart';

const _cardGray = Color(0xFFF1F5F9);

void showCardListSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => const CardListSheet(),
  );
}

class CardListSheet extends ConsumerWidget {
  const CardListSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(bankCardListProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close, size: 22), onPressed: ()=> Navigator.pop(context)),
              const Spacer(),
              const Text('کارت ها', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              const SizedBox(width: 40),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cards.isEmpty
                ? _EmptyState(scrollController: scrollController)
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: cards.length,
                    itemBuilder: (ctx, idx){
                      final c = cards[idx];
                      return _CardItem(card: c, onTap: (){
                        ref.read(selectedBankCardProvider.notifier).select(c);
                        Navigator.pop(context);
                      });
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CardCreateScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('افزودن کارت جدید', style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;
  const _EmptyState({required this.scrollController});
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(color: _cardGray, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              // Owl placeholder — blue owl holding card
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.credit_card, size: 64, color: Color(0xFF29B6F6)),
              ),
              const SizedBox(height: 16),
              const Text('هنوز هیچ کارتی ثبت نشده!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 12),
              InkWell(
                onTap: (){
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_)=> const CardCreateScreen()));
                },
                child: const Text('ایجاد کارت جدید', style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardItem extends ConsumerWidget {
  final BankCardModel card;
  final VoidCallback onTap;
  const _CardItem({required this.card, required this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final isSelected = ref.watch(selectedBankCardProvider)?.id == card.id;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : _cardGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF2196F3) : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // لوگو + بانک + نام — سمت راست
            Row(
              textDirection: TextDirection.rtl,
              children: [
                _BankLogo(bankName: card.bankName, size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.bankName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.persianName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // شماره کارت — LTR راست‌چین (جلوگیری از برعکس شدن)
            Align(
              alignment: Alignment.centerRight,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  PersianNumberFormatter.toPersian(card.formattedCard),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.1),
                ),
              ),
            ),
            if (card.sheba.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    PersianNumberFormatter.toPersian(card.spacedSheba),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankLogo extends StatelessWidget {
  final String bankName;
  final double size;
  const _BankLogo({required this.bankName, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final asset = bankLogoAsset(bankName);
    // بدون بک‌گراند سفید — فقط لوگو
    if (asset.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final c = bankColor(bankName);
    final label = bankName.replaceAll('بانک ', '');
    final letter = label.isNotEmpty ? label.substring(0, 1) : 'ب';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * 0.18)),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.36),
      ),
    );
  }
}
