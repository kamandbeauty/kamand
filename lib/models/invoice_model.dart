import 'invoice_item_model.dart';

class InvoiceModel {
  final String id;
  final String number;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String type; // sale, proforma, purchase
  final String paymentType; // cash, non_cash
  final String status; // paid, unpaid, partial, proforma
  final String date;
  final List<InvoiceItemModel> items;
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double shippingFee;
  final double taxPercent; // مالیات بر ارزش افزوده (٪) — صفر = غیرفعال
  final double previousDebt;
  final double deposit;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String notes;
  final String cardNumber;
  final String cardBank;
  final String cardOwner;
  final String createdAt;

  InvoiceModel({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.type,
    required this.paymentType,
    required this.status,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.shippingFee,
    this.taxPercent = 0,
    required this.previousDebt,
    required this.deposit,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.notes,
    required this.cardNumber,
    this.cardBank = '',
    this.cardOwner = '',
    required this.createdAt,
  });

  /// پایهٔ محاسبهٔ مالیات: اقلام − تخفیف + ارسال (بدهی قبلی مشمول نیست)
  double get taxBase {
    final b = subtotal - discountAmount + shippingFee;
    return b < 0 ? 0 : b;
  }

  /// مبلغ مالیات بر ارزش افزوده
  double get taxAmount => (taxBase * taxPercent.clamp(0, 100)) / 100;

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'type': type,
    'paymentType': paymentType,
    'status': status,
    'date': date,
    'items': items.map((i) => i.toMap()).toList(),
    'subtotal': subtotal,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'shippingFee': shippingFee,
    'taxPercent': taxPercent,
    'previousDebt': previousDebt,
    'deposit': deposit,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'notes': notes,
    'cardNumber': cardNumber,
    'cardBank': cardBank,
    'cardOwner': cardOwner,
    'createdAt': createdAt,
  };

  factory InvoiceModel.fromMap(Map<String, dynamic> map) => InvoiceModel(
    id: map['id'] ?? '',
    number: map['number'] ?? '',
    customerId: map['customerId'] ?? '',
    customerName: map['customerName'] ?? '',
    customerPhone: map['customerPhone'] ?? '',
    type: map['type'] ?? 'sale',
    paymentType: map['paymentType'] ?? 'cash',
    status: map['status'] ?? 'paid',
    date: map['date'] ?? '',
    items: (map['items'] as List? ?? [])
        .map((i) => InvoiceItemModel.fromMap(i))
        .toList(),
    subtotal: (map['subtotal'] ?? 0).toDouble(),
    discountPercent: (map['discountPercent'] ?? 0).toDouble(),
    discountAmount: (map['discountAmount'] ?? 0).toDouble(),
    shippingFee: (map['shippingFee'] ?? 0).toDouble(),
    taxPercent: (map['taxPercent'] ?? 0).toDouble(),
    previousDebt: (map['previousDebt'] ?? 0).toDouble(),
    deposit: (map['deposit'] ?? 0).toDouble(),
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    paidAmount: (map['paidAmount'] ?? 0).toDouble(),
    remainingAmount: (map['remainingAmount'] ?? 0).toDouble(),
    notes: map['notes'] ?? '',
    cardNumber: map['cardNumber'] ?? '',
    cardBank: map['cardBank'] ?? '',
    cardOwner: map['cardOwner'] ?? '',
    createdAt: map['createdAt'] ?? '',
  );
}
