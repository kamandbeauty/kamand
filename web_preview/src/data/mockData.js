import { getTodayJalali } from '../utils/helpers';

export const INITIAL_USER = {
  name: 'علی علوی',
  currency: 'تومان',
  country: 'ایران',
  province: 'تهران',
  city: 'تهران',
  usageType: 'store',
  isOnboarded: false
};

export const INITIAL_BUSINESS = {
  shopName: 'فروشگاه روبی',
  phone: '۰۲۱-۸۸۸۸۹۹۹۹',
  address: 'تهران، خیابان ولیعصر، نرسیده به میدان ونک، پلاک ۱۲۴',
  taxId: '۱۰۱۰۹۸۷۶۵۴۳',
  logoUrl: '',
  bankCards: [
    { id: '1', bank: 'بانک ملی', number: '6037-9975-1234-5678', owner: 'علی علوی' },
    { id: '2', bank: 'بانک پاسارگاد', number: '5022-2910-8765-4321', owner: 'علی علوی' }
  ]
};

export const INITIAL_CUSTOMERS = [
  {
    id: 'c1',
    name: 'رضا محمدی',
    mobile: '09121112233',
    phone: '02144556677',
    address: 'تهران، سعادت‌آباد، خیابان سرو غربی، پلاک ۴۵',
    notes: 'مشتری خوش‌حساب، تحویل حضوری',
    balance: 1500000,
    createdAt: '1405/05/15'
  },
  {
    id: 'c2',
    name: 'زهرا کاظمی',
    mobile: '09359876543',
    phone: '02122334455',
    address: 'اصفهان، خیابان چهارباغ عباسی، مجتمع کوثر',
    notes: 'ارسال با پست پیشتاز',
    balance: 0,
    createdAt: '1405/05/18'
  },
  {
    id: 'c3',
    name: 'شرکت پویاتک',
    mobile: '09129998877',
    phone: '02188776655',
    address: 'مشهد، بلوار سجاد، بزرگمهر شمالی، پلاک ۸',
    notes: 'خریدار عمده قطعات الکترونیک',
    balance: 4200000,
    createdAt: '1405/05/19'
  }
];

export const INITIAL_PRODUCTS = [
  {
    id: 'p1',
    code: '101',
    name: 'دان قهوه اسپرسو برزیل (۱ کیلویی)',
    unit: 'بسته',
    buyPrice: 380000,
    sellPrice: 520000,
    stock: 24,
    notes: 'برشتگی مدیوم دارک'
  },
  {
    id: 'p2',
    code: '102',
    name: 'ماگ سرامیکی طرح روبی',
    unit: 'عدد',
    buyPrice: 85000,
    sellPrice: 140000,
    stock: 50,
    notes: 'گنجایش ۳۵۰ سی‌سی'
  },
  {
    id: 'p3',
    code: '103',
    name: 'دستگاه اسپرسوساز خانگی مدل RBY-200',
    unit: 'دستگاه',
    buyPrice: 4200000,
    sellPrice: 5800000,
    stock: 6,
    notes: 'دارای ۱۸ ماه گارانتی شرکتی'
  },
  {
    id: 'p4',
    code: '104',
    name: 'خدمات سرویس و نگه‌داری دوره‌ای',
    unit: 'ساعت',
    buyPrice: 0,
    sellPrice: 350000,
    stock: 999,
    notes: 'توسط تکنسین مجرب'
  }
];

export const INITIAL_INVOICES = [
  {
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
      { id: 'item-1', title: 'دان قهوه اسپرسو برزیل (۱ کیلویی)', quantity: 2, unit: 'بسته', unitPrice: 520000, totalPrice: 1040000 },
      { id: 'item-2', title: 'ماگ سرامیکی طرح روبی', quantity: 1, unit: 'عدد', unitPrice: 140000, totalPrice: 140000 }
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
    createdAt: '1405/05/18'
  },
  {
    id: 'inv-1002',
    number: '1002',
    customerId: 'c3',
    customerName: 'شرکت پویاتک',
    customerPhone: '09129998877',
    type: 'sale',
    paymentType: 'non_cash',
    status: 'unpaid',
    date: '1405/05/19',
    items: [
      { id: 'item-3', title: 'دستگاه اسپرسوساز خانگی مدل RBY-200', quantity: 1, unit: 'دستگاه', unitPrice: 5800000, totalPrice: 5800000 }
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
    createdAt: '1405/05/19'
  }
];

export const INITIAL_EXPENSES = [
  { id: 'e1', title: 'اجاره دفتر و کارگاه', category: 'اجاره', amount: 8500000, date: '1405/05/01', notes: 'اجاره ماه مرداد' },
  { id: 'e2', title: 'قبض برق و اینترنت', category: 'قبوض', amount: 950000, date: '1405/05/10', notes: 'پرداخت آنلاین' }
];

export const INITIAL_INCOMES = [
  { id: 'inc1', title: 'مشاوره و راه‌اندازی کافه', category: 'خدمات', amount: 4500000, date: '1405/05/05', notes: 'پروژه کافه کاج' }
];

export const INITIAL_SETTINGS = {
  startingInvoiceNum: 1004,
  templateStyle: 'modern',
  showLogo: true,
  showCardNum: true,
  themeMode: 'light',
  autoBackup: true,
  pinCode: '',
  pinEnabled: false
};
