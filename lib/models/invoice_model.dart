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
  final double previousDebt;
  final double deposit;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String notes;
  final String cardNumber;
  final String cardBank;
  final String cardOwner;
  final bool isOfficial;
  final double taxRate;
  final double taxAmount;
  final String sellerName;
  final String sellerPhone;
  final String sellerTaxId;
  final String sellerNationalId;
  final String sellerEconomicCode;
  final String sellerRegistrationNumber;
  final String sellerPostalCode;
  final String sellerAddress;
  final String buyerNationalId;
  final String buyerEconomicCode;
  final String buyerPostalCode;
  final String buyerAddress;
  final String createdAt;

  /// Amount this invoice contributes to the customer's outstanding balance.
  ///
  /// `previousDebt` is displayed on the invoice, but it already belongs to the
  /// customer's balance and must not be added for a second time.
  double get customerBalanceImpact {
    if (type != 'sale') return 0;
    // previousDebt is already present in the customer's balance. A large
    // deposit (or a cash payment) may pay part of that old debt, so this delta
    // is intentionally allowed to be negative.
    final effectiveRemaining = paymentType == 'cash' ? 0.0 : remainingAmount;
    return effectiveRemaining - previousDebt;
  }

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
    required this.previousDebt,
    required this.deposit,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.notes,
    required this.cardNumber,
    this.cardBank = '',
    this.cardOwner = '',
    this.isOfficial = false,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.sellerName = '',
    this.sellerPhone = '',
    this.sellerTaxId = '',
    this.sellerNationalId = '',
    this.sellerEconomicCode = '',
    this.sellerRegistrationNumber = '',
    this.sellerPostalCode = '',
    this.sellerAddress = '',
    this.buyerNationalId = '',
    this.buyerEconomicCode = '',
    this.buyerPostalCode = '',
    this.buyerAddress = '',
    required this.createdAt,
  });

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
    'previousDebt': previousDebt,
    'deposit': deposit,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'notes': notes,
    'cardNumber': cardNumber,
    'cardBank': cardBank,
    'cardOwner': cardOwner,
    'isOfficial': isOfficial,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'sellerName': sellerName,
    'sellerPhone': sellerPhone,
    'sellerTaxId': sellerTaxId,
    'sellerNationalId': sellerNationalId,
    'sellerEconomicCode': sellerEconomicCode,
    'sellerRegistrationNumber': sellerRegistrationNumber,
    'sellerPostalCode': sellerPostalCode,
    'sellerAddress': sellerAddress,
    'buyerNationalId': buyerNationalId,
    'buyerEconomicCode': buyerEconomicCode,
    'buyerPostalCode': buyerPostalCode,
    'buyerAddress': buyerAddress,
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
    previousDebt: (map['previousDebt'] ?? 0).toDouble(),
    deposit: (map['deposit'] ?? 0).toDouble(),
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    paidAmount: (map['paidAmount'] ?? 0).toDouble(),
    remainingAmount: (map['remainingAmount'] ?? 0).toDouble(),
    notes: map['notes'] ?? '',
    cardNumber: map['cardNumber'] ?? '',
    cardBank: map['cardBank'] ?? '',
    cardOwner: map['cardOwner'] ?? '',
    isOfficial: map['isOfficial'] ?? false,
    taxRate: (map['taxRate'] ?? 0).toDouble(),
    taxAmount: (map['taxAmount'] ?? 0).toDouble(),
    sellerName: map['sellerName'] ?? '',
    sellerPhone: map['sellerPhone'] ?? '',
    sellerTaxId: map['sellerTaxId'] ?? '',
    sellerNationalId: map['sellerNationalId'] ?? '',
    sellerEconomicCode: map['sellerEconomicCode'] ?? map['sellerTaxId'] ?? '',
    sellerRegistrationNumber: map['sellerRegistrationNumber'] ?? '',
    sellerPostalCode: map['sellerPostalCode'] ?? '',
    sellerAddress: map['sellerAddress'] ?? '',
    buyerNationalId: map['buyerNationalId'] ?? '',
    buyerEconomicCode: map['buyerEconomicCode'] ?? '',
    buyerPostalCode: map['buyerPostalCode'] ?? '',
    buyerAddress: map['buyerAddress'] ?? '',
    createdAt: map['createdAt'] ?? '',
  );
}
