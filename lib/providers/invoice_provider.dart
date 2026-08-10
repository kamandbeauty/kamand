import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../core/utils/jalali_helper.dart';
import '../database/app_database.dart';

final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, List<InvoiceModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvoiceListNotifier(db);
});

class InvoiceListNotifier extends StateNotifier<List<InvoiceModel>> {
  final AppDatabase? db;

  InvoiceListNotifier([this.db])
      : super([
          InvoiceModel(
            id: 'inv-1001',
            number: '1001',
            customerId: 'c1',
            customerName: 'رضا محمدی',
            customerPhone: '09121112233',
            type: 'sale',
            paymentType: 'cash',
            status: 'paid',
            date: '1405/05/18',
            items: [
              InvoiceItemModel(
                  id: 'i1',
                  title: 'دان قهوه اسپرسو برزیل (۱ کیلویی)',
                  quantity: 2,
                  unit: 'بسته',
                  unitPrice: 520000,
                  totalPrice: 1040000),
              InvoiceItemModel(
                  id: 'i2',
                  title: 'ماگ سرامیکی طرح روبی',
                  quantity: 1,
                  unit: 'عدد',
                  unitPrice: 140000,
                  totalPrice: 140000),
            ],
            subtotal: 1180000,
            discountPercent: 5,
            discountAmount: 59000,
            shippingFee: 50000,
            previousDebt: 0,
            deposit: 0,
            totalAmount: 1171000,
            paidAmount: 1171000,
            remainingAmount: 0,
            notes: 'تحویل داده شد - تشکر از خرید شما',
            cardNumber: '6037-9975-1234-5678',
            createdAt: '1405/05/18',
          ),
          InvoiceModel(
            id: 'inv-1002',
            number: '1002',
            customerId: 'c3',
            customerName: 'شرکت پویاتک',
            customerPhone: '09129998877',
            type: 'sale',
            paymentType: 'non_cash',
            status: 'unpaid',
            date: JalaliHelper.getTodayJalali(),
            items: [
              InvoiceItemModel(
                  id: 'i3',
                  title: 'دستگاه اسپرسوساز خانگی مدل RBY-200',
                  quantity: 1,
                  unit: 'دستگاه',
                  unitPrice: 5800000,
                  totalPrice: 5800000),
            ],
            subtotal: 5800000,
            discountPercent: 0,
            discountAmount: 0,
            shippingFee: 0,
            previousDebt: 0,
            deposit: 1600000,
            totalAmount: 5800000,
            paidAmount: 1600000,
            remainingAmount: 4200000,
            notes: 'سررسید تسویه ۵ روز آینده',
            cardNumber: '5022-2910-8765-4321',
            createdAt: '1405/05/19',
          ),
          InvoiceModel(
            id: 'inv-1003',
            number: '1003',
            customerId: 'c2',
            customerName: 'زهرا کاظمی',
            customerPhone: '09359876543',
            type: 'proforma',
            paymentType: 'cash',
            status: 'proforma',
            date: '1405/05/20',
            items: [
              InvoiceItemModel(
                  id: 'i4',
                  title: 'دان قهوه اسپرسو برزیل (۱ کیلویی)',
                  quantity: 5,
                  unit: 'بسته',
                  unitPrice: 520000,
                  totalPrice: 2600000),
              InvoiceItemModel(
                  id: 'i5',
                  title: 'خدمات سرویس و نگه‌داری دوره‌ای',
                  quantity: 2,
                  unit: 'ساعت',
                  unitPrice: 350000,
                  totalPrice: 700000),
            ],
            subtotal: 3300000,
            discountPercent: 5,
            discountAmount: 165000,
            shippingFee: 65000,
            previousDebt: 0,
            deposit: 0,
            totalAmount: 3200000,
            paidAmount: 0,
            remainingAmount: 3200000,
            notes: 'اعتبار پیش‌فاکتور تا ۳ روز کاری',
            cardNumber: '6037-9975-1234-5678',
            createdAt: '1405/05/20',
          ),
        ]);

  void saveInvoice(InvoiceModel invoice) {
    final index = state.indexWhere((i) => i.id == invoice.id);
    if (index >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) invoice else state[i],
      ];
    } else {
      state = [...state, invoice];
    }
  }

  void deleteInvoice(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  void convertProformaToInvoice(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          InvoiceModel(
            id: item.id,
            number: item.number,
            customerId: item.customerId,
            customerName: item.customerName,
            customerPhone: item.customerPhone,
            type: 'sale',
            paymentType: item.paymentType,
            status: item.remainingAmount == 0 ? 'paid' : 'unpaid',
            date: item.date,
            items: item.items,
            subtotal: item.subtotal,
            discountPercent: item.discountPercent,
            discountAmount: item.discountAmount,
            shippingFee: item.shippingFee,
            previousDebt: item.previousDebt,
            deposit: item.deposit,
            totalAmount: item.totalAmount,
            paidAmount: item.paidAmount,
            remainingAmount: item.remainingAmount,
            notes: item.notes,
            cardNumber: item.cardNumber,
            createdAt: item.createdAt,
          )
        else
          item,
    ];
  }

  void recordPayment(String id, double amount) {
    state = [
      for (final item in state)
        if (item.id == id)
          InvoiceModel(
            id: item.id,
            number: item.number,
            customerId: item.customerId,
            customerName: item.customerName,
            customerPhone: item.customerPhone,
            type: item.type,
            paymentType: item.paymentType,
            status: (item.totalAmount - (item.paidAmount + amount)) <= 0
                ? 'paid'
                : 'partial',
            date: item.date,
            items: item.items,
            subtotal: item.subtotal,
            discountPercent: item.discountPercent,
            discountAmount: item.discountAmount,
            shippingFee: item.shippingFee,
            previousDebt: item.previousDebt,
            deposit: item.deposit,
            totalAmount: item.totalAmount,
            paidAmount: item.paidAmount + amount,
            remainingAmount:
                (item.totalAmount - (item.paidAmount + amount)) < 0
                    ? 0
                    : item.totalAmount - (item.paidAmount + amount),
            notes: item.notes,
            cardNumber: item.cardNumber,
            createdAt: item.createdAt,
          )
        else
          item,
    ];
  }
}
