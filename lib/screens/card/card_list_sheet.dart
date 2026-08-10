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
                        ref.read(selectedBankCardProvider.notifier).state = c;
                        Navigator.pop(context);
                      });
                    },
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
                child: const Icon(Icons.owl, size: 64, color: Color(0xFF29B6F6)),
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
            Row(children: [
              Container(width: 36, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.account_balance, size: 16, color: Color(0xFF2196F3))),
              const SizedBox(width: 8),
              Text(card.bankName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(card.persianName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            Text(PersianNumberFormatter.toPersian(card.formattedCard), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(PersianNumberFormatter.toPersian(card.spacedSheba), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.8), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
