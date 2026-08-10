class AppConstants {
  static const String appName = 'فاکتور فیدا';
  static const String appVersion = '1.0.0';

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
