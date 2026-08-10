class BankCardModel {
  final String id;
  final String cardNumber; // 16 digits without dash, e.g. 6104337767686528
  final String sheba; // without IR, e.g. 25547...
  final String bankName; // e.g. بانک ملت
  final String persianName; // e.g. جاوید سلمان

  BankCardModel({
    required this.id,
    required this.cardNumber,
    required this.sheba,
    required this.bankName,
    required this.persianName,
  });

  String get formattedCard => cardNumber.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim(); // 6104 3377 6768 6528
  String get spacedCardDash => cardNumber.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} - ').replaceAll(RegExp(r' - $'), ''); // 6104 - 3377 - ...
  String get formattedSheba => 'IR${sheba.padLeft(24,'0')}'; // IR + 24
  String get spacedSheba => formattedSheba.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim();

  Map<String, dynamic> toMap()=> {'id':id,'cardNumber':cardNumber,'sheba':sheba,'bankName':bankName,'persianName':persianName};
  factory BankCardModel.fromMap(Map<String,dynamic> m)=> BankCardModel(id:m['id']??'', cardNumber:m['cardNumber']??'', sheba:m['sheba']??'', bankName:m['bankName']??'', persianName:m['persianName']??'');
}
