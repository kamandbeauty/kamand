class AppConstants {
  static const String appName = 'فاکتور ساز روبی';
  static const String appVersion = '5.8.0';

  static const List<String> currencies = [
    'تومان',
    'ریال',
    'دلار',
    'یورو',
    'دلار کانادا',
    'لیر',
    'افغانی'
  ];

  static const List<String> countries = [
    'ایران',
    'ترکیه',
    'آمریکا',
    'کانادا',
    'افغانستان',
    'امارات',
    'سایر'
  ];

  static const List<Map<String, String>> usageTypes = [
    {'id': 'store', 'title': 'فروشگاه'},
    {'id': 'online_store', 'title': 'فروشگاه اینترنتی'},
    {'id': 'services', 'title': 'خدمات'},
    {'id': 'wholesale', 'title': 'عمده‌فروشی'},
    {'id': 'freelance', 'title': 'فریلنسر'},
    {'id': 'personal', 'title': 'استفاده شخصی'},
    {'id': 'simple_acc', 'title': 'حسابداری ساده'},
    {'id': 'other', 'title': 'سایر'},
  ];

  static const List<String> productUnits = [
    'عدد',
    'کیلوگرم',
    'گرم',
    'متر',
    'بسته',
    'کارتن',
    'دستگاه',
    'ساعت',
    'روز',
    'نفر',
    'لیتر',
    'جفت'
  ];
}
