import '../../core/normalization/persian_normalizer.dart';

const internalSourceId = 'source-internal-review';

final seedSource = <String, Object?>{
  'id': internalSourceId,
  'title': 'داده آزمایشی داخلی علم اسامی',
  'author': 'تیم محتوا',
  'publisher': 'علم اسامی',
  'publication_year': null,
  'language': 'fa',
  'source_type': 'internal_review',
  'url': '',
  'reliability_level': 'low',
  'notes': 'این منبع برای تست معماری است و جایگزین منبع دانشگاهی یا تاریخی نیست.',
};

final seedNames = <Map<String, Object?>>[
  _name('آریا', 'آریا', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['ایرانی', 'کوتاه']),
  _name('آراد', 'آراد', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['ایرانی', 'کوتاه']),
  _name('سام', 'سام', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['باستانی', 'کوتاه']),
  _name('رایان', 'رایان', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['مدرن', 'بین‌المللی']),
  _name('آوا', 'آوا', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['فارسی', 'کوتاه']),
  _name('دریا', 'دریا', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['فارسی', 'کوتاه']),
  _name('نازنین', 'نازنین', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['فارسی']),
  _name('یاسمن', 'یاسمن', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['فارسی']),
  _name('نور', 'نور', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['مذهبی', 'کوتاه']),
  _name('مهسا', 'مهسا', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', 'نامشخص', ['مدرن']),
];

Map<String, Object?> _name(
  String id,
  String displayName,
  String transliteration,
  String language,
  String origin,
  String gender,
  String meaning,
  String etymology,
  String pronunciation,
  List<String> styles,
) {
  final normalized = PersianNormalizer.normalizeForSearch(displayName);
  return {
    'id': 'name-$id',
    'display_name': displayName,
    'normalized_name': normalized,
    'transliteration': transliteration,
    'language': language,
    'origin': origin,
    'gender': gender,
    'meaning': meaning,
    'etymology': etymology,
    'pronunciation': pronunciation,
    'status': 'unverified',
    'confidence': 'low',
    'styles': styles.join('|'),
    'source_id': internalSourceId,
    'source_note': 'رکورد آزمایشی است؛ پیش از انتشار باید با منابع معتبر بررسی شود.',
  };
}

const abjadKabirLetters = <String, int>{
  'ا': 1,
  'ب': 2,
  'ج': 3,
  'د': 4,
  'ه': 5,
  'و': 6,
  'ز': 7,
  'ح': 8,
  'ط': 9,
  'ی': 10,
  'ک': 20,
  'ل': 30,
  'م': 40,
  'ن': 50,
  'س': 60,
  'ع': 70,
  'ف': 80,
  'ص': 90,
  'ق': 100,
  'ر': 200,
  'ش': 300,
  'ت': 400,
  'ث': 500,
  'خ': 600,
  'ذ': 700,
  'ض': 800,
  'ظ': 900,
  'غ': 1000,
};

final seedArchiveEntries = <Map<String, Object?>>[
  {
    'id': 'archive-methodology',
    'title': 'راهنمای اعتبار داده در علم اسامی',
    'category': 'روش‌شناسی',
    'body': 'هر معنی، ریشه یا کاربرد تاریخی باید به منبع متصل باشد. نبود منبع به‌معنای ناشناخته بودن ادعا است، نه درست یا غلط بودن آن.',
    'source_id': internalSourceId,
    'status': 'verified',
  },
  {
    'id': 'archive-tradition-disclaimer',
    'title': 'تفاوت نام‌شناسی و عددشناسی سنتی',
    'category': 'راهنمای کاربر',
    'body': 'نام‌شناسی بر مطالعه زبان، تاریخ و فرهنگ نام‌ها تمرکز دارد. ابجد و عددشناسی در این برنامه به‌عنوان سنت تاریخی و تفسیر سرگرمی ارائه می‌شوند و پیش‌بینی علمی نیستند.',
    'source_id': internalSourceId,
    'status': 'verified',
  },
];
