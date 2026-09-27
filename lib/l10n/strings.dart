import 'package:flutter/widgets.dart';

/// All interface text in English and Urdu. Use `context.tr('key')`.
/// Missing Urdu entries fall back to English.
const Map<String, Map<String, String>> _strings = {
  // General
  'app_tagline': {'en': 'Your Daily Needs • Delivered', 'ur': 'آپ کی روزمرہ ضروریات • گھر تک'},
  'retry': {'en': 'Try again', 'ur': 'دوبارہ کوشش کریں'},
  'cancel': {'en': 'Cancel', 'ur': 'منسوخ'},
  'ok': {'en': 'OK', 'ur': 'ٹھیک ہے'},
  'save': {'en': 'Save', 'ur': 'محفوظ کریں'},
  'close': {'en': 'Close', 'ur': 'بند کریں'},
  'view_all': {'en': 'View all', 'ur': 'سب دیکھیں'},
  'coming_soon': {'en': 'This section is coming in the next update.', 'ur': 'یہ حصہ اگلی اپ ڈیٹ میں آ رہا ہے۔'},
  'rs': {'en': 'Rs.', 'ur': 'روپے'},

  // Errors
  'err_network': {'en': 'No internet connection. Please check your connection and try again.', 'ur': 'انٹرنیٹ دستیاب نہیں۔ براہ کرم کنکشن چیک کر کے دوبارہ کوشش کریں۔'},
  'err_generic': {'en': 'Something went wrong. Please try again.', 'ur': 'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔'},
  'err_session': {'en': 'Your session has expired. Please log in again.', 'ur': 'آپ کا سیشن ختم ہو گیا ہے۔ براہ کرم دوبارہ لاگ ان کریں۔'},
  'err_home': {'en': 'We couldn\'t load the store right now.', 'ur': 'اس وقت اسٹور لوڈ نہیں ہو سکا۔'},

  // Header / search
  'search_hint': {'en': 'Search for anything…', 'ur': 'آپ کو کیا چاہیے؟'},
  'language': {'en': 'Language', 'ur': 'زبان'},
  'english': {'en': 'English', 'ur': 'English'},
  'urdu': {'en': 'اردو', 'ur': 'اردو'},
  'cart': {'en': 'Cart', 'ur': 'کارٹ'},
  'more': {'en': 'More', 'ur': 'مزید'},

  // More menu
  'branch_location': {'en': 'Branch / Location', 'ur': 'برانچ / مقام'},
  'account': {'en': 'Account', 'ur': 'اکاؤنٹ'},
  'help_support': {'en': 'Help & Support', 'ur': 'مدد اور سپورٹ'},
  'about_us': {'en': 'About Us', 'ur': 'ہمارے بارے میں'},
  'terms': {'en': 'Terms & Conditions', 'ur': 'شرائط و ضوابط'},
  'privacy': {'en': 'Privacy Policy', 'ur': 'رازداری کی پالیسی'},
  'logout': {'en': 'Logout', 'ur': 'لاگ آؤٹ'},
  'login': {'en': 'Login', 'ur': 'لاگ ان'},
  'logout_confirm': {'en': 'Do you want to log out?', 'ur': 'کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟'},
  'logged_out': {'en': 'You have been logged out.', 'ur': 'آپ لاگ آؤٹ ہو گئے ہیں۔'},

  // Footer
  'home': {'en': 'Home', 'ur': 'ہوم'},
  'my_orders': {'en': 'My Orders', 'ur': 'میرے آرڈرز'},
  'order_now': {'en': 'Order Now', 'ur': 'ابھی آرڈر کریں'},
  'favorites': {'en': 'Favorites', 'ur': 'پسندیدہ'},
  'my_account': {'en': 'My Account', 'ur': 'میرا اکاؤنٹ'},

  // Home
  'hero_title': {'en': 'Order Anything', 'ur': 'کچھ بھی آرڈر کریں'},
  'hero_sub': {'en': 'We buy from the market & deliver to you', 'ur': 'ہم بازار سے خرید کر آپ تک پہنچاتے ہیں'},
  'fresh_badge': {'en': 'Fresh • Quality • Reliable', 'ur': 'تازہ • معیاری • قابلِ اعتماد'},
  'market_shopping': {'en': 'Market Shopping', 'ur': 'مارکیٹ سے منگوائیں'},
  'market_shopping_sub': {'en': 'Tell us what you need. We\'ll buy it from the market and deliver it to you.', 'ur': 'ہمیں بتائیں آپ کو کیا چاہیے، ہم بازار سے خرید کر آپ تک پہنچائیں گے۔'},
  'how_it_works': {'en': 'How it works?', 'ur': 'یہ کیسے کام کرتا ہے؟'},
  'how_it_works_body': {
    'en': '1. Pick a category or type your shopping list.\n2. We buy the items from the market.\n3. Our rider delivers them to your door.\n4. Pay cash on delivery — the final bill is confirmed at delivery.',
    'ur': '1۔ کیٹیگری منتخب کریں یا اپنی خریداری کی فہرست لکھیں۔\n2۔ ہم بازار سے اشیاء خریدتے ہیں۔\n3۔ ہمارا رائیڈر آپ کے دروازے تک پہنچاتا ہے۔\n4۔ ڈیلیوری پر نقد ادائیگی کریں — حتمی بل ڈیلیوری پر طے ہوگا۔',
  },
  'our': {'en': 'Our', 'ur': 'ہمارے'},
  'delivery_charges': {'en': 'Delivery Charges', 'ur': 'ڈیلیوری چارجز'},
  'distance_km': {'en': 'Distance (KM)', 'ur': 'فاصلہ (کلومیٹر)'},
  'charge_rs': {'en': 'Charge (Rs.)', 'ur': 'چارج (روپے)'},
  'delivery_note': {'en': 'Delivery charge depends on your location.', 'ur': 'ڈیلیوری چارج آپ کے مقام کے مطابق ہوگا۔'},
  'repeat_order': {'en': 'Repeat Order', 'ur': 'دوبارہ آرڈر کریں'},
  'repeat_order_sub': {'en': 'Quickly order your previous items', 'ur': 'پچھلی اشیاء جلدی سے دوبارہ منگوائیں'},
  'reorder_previous': {'en': 'Reorder Previous Order', 'ur': 'پچھلا آرڈر دوبارہ منگوائیں'},
  'deals_discounts': {'en': 'Deals & Discounts', 'ur': 'ڈیلز اور رعایتیں'},
  'off': {'en': 'OFF', 'ur': 'رعایت'},
  'trust_quality': {'en': 'Quality Products', 'ur': 'معیاری اشیاء'},
  'trust_fresh': {'en': 'Fresh & Hygienic', 'ur': 'تازہ اور محفوظ'},
  'trust_fast': {'en': 'Fast Delivery', 'ur': 'تیز ڈیلیوری'},
  'trust_support': {'en': '24/7 Support', 'ur': '24 گھنٹے مدد'},
  'trust_payment': {'en': 'Cash on Delivery', 'ur': 'ڈیلیوری پر ادائیگی'},
  'add': {'en': 'Add', 'ur': 'شامل کریں'},
  'added_to_cart': {'en': 'Added to cart', 'ur': 'کارٹ میں شامل ہو گیا'},
  'max_qty_reached': {'en': 'No more of this item is available.', 'ur': 'اس چیز کی مزید مقدار دستیاب نہیں۔'},
  'out_of_stock': {'en': 'Out of stock', 'ur': 'دستیاب نہیں'},
  'no_products_yet': {'en': 'Products coming soon', 'ur': 'اشیاء جلد آ رہی ہیں'},
  'favorites_empty': {'en': 'Tap the ♡ on any product to save it here.', 'ur': 'کسی بھی چیز پر ♡ دبائیں تاکہ وہ یہاں محفوظ ہو جائے۔'},
  'add_favorite': {'en': 'Add to favorites', 'ur': 'پسندیدہ میں شامل کریں'},
  'remove_favorite': {'en': 'Remove from favorites', 'ur': 'پسندیدہ سے ہٹائیں'},
  'favorite_failed': {'en': 'Could not update favorites. Please try again.', 'ur': 'پسندیدہ اپ ڈیٹ نہیں ہو سکا۔ دوبارہ کوشش کریں۔'},

  // Login
  'login_required_title': {'en': 'Please log in', 'ur': 'براہ کرم لاگ ان کریں'},
  'login_required_body': {'en': 'Log in to see your orders, favorites and account.', 'ur': 'اپنے آرڈرز، پسندیدہ اشیاء اور اکاؤنٹ دیکھنے کے لیے لاگ ان کریں۔'},
  'email': {'en': 'Email address', 'ur': 'ای میل'},
  'password': {'en': 'Password', 'ur': 'پاس ورڈ'},
  'full_name': {'en': 'Full name', 'ur': 'پورا نام'},
  'mobile': {'en': 'Mobile number', 'ur': 'موبائل نمبر'},
  'sign_in': {'en': 'Sign in', 'ur': 'سائن ان'},
  'create_account': {'en': 'Create account', 'ur': 'اکاؤنٹ بنائیں'},
  'no_account': {'en': 'New to Grozo? Create an account', 'ur': 'نئے ہیں؟ اکاؤنٹ بنائیں'},
  'continue_browsing': {'en': 'Continue without logging in', 'ur': 'لاگ ان کے بغیر جاری رکھیں'},
  'fill_all': {'en': 'Please fill in all required fields.', 'ur': 'براہ کرم تمام ضروری خانے پُر کریں۔'},
  'welcome_back': {'en': 'Welcome back', 'ur': 'خوش آمدید'},
  'account_inactive': {'en': 'Account inactive', 'ur': 'اکاؤنٹ غیر فعال'},
  'contact_support': {'en': 'Contact support', 'ur': 'سپورٹ سے رابطہ کریں'},

  // Branch / info
  'branch_not_set': {'en': 'Branch details will be available soon.', 'ur': 'برانچ کی تفصیلات جلد دستیاب ہوں گی۔'},
  'open_in_maps': {'en': 'Get directions in Google Maps', 'ur': 'گوگل میپس میں راستہ دیکھیں'},
  'call_branch': {'en': 'Call branch', 'ur': 'برانچ کو کال کریں'},
  'opening_hours': {'en': 'Opening hours', 'ur': 'اوقاتِ کار'},
  'content_not_set': {'en': 'This information will be available soon.', 'ur': 'یہ معلومات جلد دستیاب ہوں گی۔'},
  'call_us': {'en': 'Call us', 'ur': 'ہمیں کال کریں'},
  'whatsapp_us': {'en': 'WhatsApp us', 'ur': 'واٹس ایپ کریں'},
  'email_us': {'en': 'Email us', 'ur': 'ای میل کریں'},
  'faq': {'en': 'Frequently Asked Questions', 'ur': 'عام سوالات'},
};

extension Tr on BuildContext {
  String tr(String key) {
    final lang = Localizations.maybeLocaleOf(this)?.languageCode ?? 'en';
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['en'] ?? key;
  }

  String get lang => Localizations.maybeLocaleOf(this)?.languageCode ?? 'en';
}

/// Maps an [ApiResult]-style error into a customer-friendly message.
String friendlyError(BuildContext context, {String? errorCode, String? serverMessage}) {
  if (errorCode == 'network') return context.tr('err_network');
  if (errorCode == 'session_expired') return context.tr('err_session');
  if (serverMessage != null && serverMessage.isNotEmpty && context.lang == 'en') return serverMessage;
  return context.tr('err_generic');
}
