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

  // Cart
  'cart_empty': {'en': 'Your cart is empty', 'ur': 'آپ کی کارٹ خالی ہے'},
  'start_shopping': {'en': 'Start shopping', 'ur': 'خریداری شروع کریں'},
  'clear': {'en': 'Clear', 'ur': 'صاف کریں'},
  'clear_cart_q': {'en': 'Remove all items from your cart?', 'ur': 'کارٹ سے تمام اشیاء ہٹا دیں؟'},
  'remove': {'en': 'Remove', 'ur': 'ہٹائیں'},
  'items_total': {'en': 'Items total', 'ur': 'اشیاء کا کل'},
  'delivery_added_at_checkout': {'en': 'Delivery charges are added at checkout.', 'ur': 'ڈیلیوری چارجز چیک آؤٹ پر شامل ہوں گے۔'},
  'proceed_checkout': {'en': 'Proceed to checkout', 'ur': 'چیک آؤٹ کریں'},

  // Checkout
  'checkout': {'en': 'Checkout', 'ur': 'چیک آؤٹ'},
  'your_details': {'en': 'Your details', 'ur': 'آپ کی معلومات'},
  'delivery_address': {'en': 'Delivery address', 'ur': 'ڈیلیوری کا پتہ'},
  'add_address': {'en': 'Add address', 'ur': 'پتہ شامل کریں'},
  'change': {'en': 'Change', 'ur': 'تبدیل کریں'},
  'payment_method': {'en': 'Payment method', 'ur': 'ادائیگی کا طریقہ'},
  'cod': {'en': 'Cash on Delivery', 'ur': 'ڈیلیوری پر نقد ادائیگی'},
  'cod_sub': {'en': 'Pay the rider in cash when your order arrives.', 'ur': 'آرڈر ملنے پر رائیڈر کو نقد ادائیگی کریں۔'},
  'note_for_rider': {'en': 'Note for us (optional)', 'ur': 'ہمارے لیے نوٹ (اختیاری)'},
  'order_summary': {'en': 'Order summary', 'ur': 'آرڈر کا خلاصہ'},
  'subtotal': {'en': 'Subtotal', 'ur': 'ذیلی کل'},
  'discount': {'en': 'Discount', 'ur': 'رعایت'},
  'delivery_charge': {'en': 'Delivery charge', 'ur': 'ڈیلیوری چارج'},
  'to_be_confirmed': {'en': 'Confirmed on delivery', 'ur': 'ڈیلیوری پر طے ہوگا'},
  'total_payable': {'en': 'Total payable', 'ur': 'کل قابلِ ادائیگی'},
  'confirm_order': {'en': 'Confirm order', 'ur': 'آرڈر کی تصدیق کریں'},
  'placing_order': {'en': 'Placing your order…', 'ur': 'آپ کا آرڈر دیا جا رہا ہے…'},
  'need_address': {'en': 'Please add a delivery address.', 'ur': 'براہ کرم ڈیلیوری کا پتہ شامل کریں۔'},
  'need_mobile': {'en': 'Please enter your mobile number.', 'ur': 'براہ کرم اپنا موبائل نمبر درج کریں۔'},
  'cart_changed': {'en': 'Some items in your cart changed. Please review before confirming.', 'ur': 'آپ کی کارٹ میں کچھ اشیاء تبدیل ہو گئی ہیں۔ براہ کرم تصدیق سے پہلے دیکھ لیں۔'},
  'prices_changed': {'en': 'Prices have changed. Please check the new total.', 'ur': 'قیمتیں تبدیل ہو گئی ہیں۔ براہ کرم نیا کل دیکھ لیں۔'},
  'problem_unavailable': {'en': 'is no longer available', 'ur': 'اب دستیاب نہیں'},
  'problem_stock': {'en': 'only {n} left', 'ur': 'صرف {n} باقی'},
  'problem_max': {'en': 'maximum {n} per order', 'ur': 'فی آرڈر زیادہ سے زیادہ {n}'},
  'fix_cart': {'en': 'Update my cart', 'ur': 'میری کارٹ درست کریں'},
  'outside_area': {'en': 'Sorry, this address is outside our delivery area.', 'ur': 'معذرت، یہ پتہ ہمارے ڈیلیوری علاقے سے باہر ہے۔'},
  'order_failed': {'en': 'Your order could not be placed. Please try again.', 'ur': 'آپ کا آرڈر نہیں دیا جا سکا۔ براہ کرم دوبارہ کوشش کریں۔'},

  // Confirmation
  'order_placed_title': {'en': 'Order placed!', 'ur': 'آرڈر دے دیا گیا!'},
  'order_placed_body': {'en': 'Thank you. We have received your order and will confirm it shortly.', 'ur': 'شکریہ۔ ہمیں آپ کا آرڈر مل گیا ہے، ہم جلد تصدیق کریں گے۔'},
  'order_number': {'en': 'Order number', 'ur': 'آرڈر نمبر'},
  'order_date': {'en': 'Date', 'ur': 'تاریخ'},
  'view_order': {'en': 'View order', 'ur': 'آرڈر دیکھیں'},
  'continue_shopping': {'en': 'Continue shopping', 'ur': 'خریداری جاری رکھیں'},

  // Orders
  'current_orders': {'en': 'Current', 'ur': 'جاری'},
  'past_orders': {'en': 'Past', 'ur': 'پچھلے'},
  'no_current_orders': {'en': 'You have no orders in progress.', 'ur': 'آپ کا کوئی آرڈر جاری نہیں۔'},
  'no_past_orders': {'en': 'No previous orders yet.', 'ur': 'ابھی تک کوئی پچھلا آرڈر نہیں۔'},
  'order': {'en': 'Order', 'ur': 'آرڈر'},
  'items': {'en': 'Items', 'ur': 'اشیاء'},
  'status': {'en': 'Status', 'ur': 'صورتحال'},
  'step_placed': {'en': 'Order placed', 'ur': 'آرڈر دیا گیا'},
  'step_confirmed': {'en': 'Confirmed – being prepared', 'ur': 'تصدیق شدہ – تیار ہو رہا ہے'},
  'step_rider': {'en': 'Rider assigned', 'ur': 'رائیڈر مقرر'},
  'step_out': {'en': 'Out for delivery', 'ur': 'ڈیلیوری کے لیے روانہ'},
  'step_delivered': {'en': 'Delivered', 'ur': 'پہنچا دیا گیا'},
  'step_completed': {'en': 'Completed', 'ur': 'مکمل'},
  'step_cancelled': {'en': 'Cancelled', 'ur': 'منسوخ'},
  'cancel_order': {'en': 'Cancel order', 'ur': 'آرڈر منسوخ کریں'},
  'cancel_order_q': {'en': 'Cancel this order?', 'ur': 'کیا یہ آرڈر منسوخ کریں؟'},
  'order_cancelled': {'en': 'Your order has been cancelled.', 'ur': 'آپ کا آرڈر منسوخ ہو گیا ہے۔'},
  'keep_order': {'en': 'Keep order', 'ur': 'آرڈر رکھیں'},
  'request_change': {'en': 'Request change', 'ur': 'تبدیلی کی درخواست'},
  'send_change_request': {'en': 'Send request', 'ur': 'درخواست بھیجیں'},
  'change_how_it_works': {'en': 'Change the items, address or note below. The store reviews your request and updates the order – you will be told when it is done and see the new total.', 'ur': 'نیچے اشیاء، پتہ یا نوٹ تبدیل کریں۔ اسٹور آپ کی درخواست دیکھ کر آرڈر اپ ڈیٹ کرے گا – مکمل ہونے پر آپ کو اطلاع اور نئی رقم ملے گی۔'},
  'change_message': {'en': 'Message to the store', 'ur': 'اسٹور کے لیے پیغام'},
  'change_message_hint': {'en': 'e.g. please add 1 dozen eggs', 'ur': 'مثلاً براہ کرم ایک درجن انڈے شامل کریں'},
  'change_nothing': {'en': 'Change something first, or write a message.', 'ur': 'پہلے کچھ تبدیل کریں یا پیغام لکھیں۔'},
  'change_sent': {'en': 'Your request has been sent to the store.', 'ur': 'آپ کی درخواست اسٹور کو بھیج دی گئی ہے۔'},
  'change_pending': {'en': 'Change requested – waiting for the store', 'ur': 'تبدیلی کی درخواست – اسٹور کے جواب کا انتظار'},
  'change_rejected': {'en': 'Your change request was declined', 'ur': 'آپ کی تبدیلی کی درخواست نامنظور ہوئی'},
  'change_accepted': {'en': 'Your requested changes have been made', 'ur': 'آپ کی درخواست کردہ تبدیلیاں کر دی گئی ہیں'},
  'cannot_change_now': {'en': 'Cancel and changes are no longer available', 'ur': 'منسوخی اور تبدیلی اب ممکن نہیں'},
  'add_product': {'en': 'Add product', 'ur': 'پروڈکٹ شامل کریں'},
  'no_products_in_order': {'en': 'No products. Add one, or describe what you need in the message.', 'ur': 'کوئی پروڈکٹ نہیں۔ شامل کریں یا پیغام میں لکھیں۔'},
  'less': {'en': 'Less', 'ur': 'کم'},
  'more_qty': {'en': 'More', 'ur': 'زیادہ'},
  'no_results': {'en': 'Nothing found.', 'ur': 'کچھ نہیں ملا۔'},
  'mark_received': {'en': 'I received my order', 'ur': 'مجھے آرڈر مل گیا'},
  'reorder': {'en': 'Reorder', 'ur': 'دوبارہ آرڈر کریں'},
  'reorder_done': {'en': '{n} item(s) added to your cart with today\'s prices.', 'ur': '{n} اشیاء آج کی قیمتوں کے ساتھ کارٹ میں شامل ہو گئیں۔'},
  'reorder_some_missing': {'en': 'Some items are no longer available and were not added: {names}', 'ur': 'کچھ اشیاء دستیاب نہیں تھیں اس لیے شامل نہیں ہوئیں: {names}'},
  'your_list': {'en': 'Your shopping list', 'ur': 'آپ کی خریداری کی فہرست'},
  'rider': {'en': 'Rider', 'ur': 'رائیڈر'},
  'call_rider': {'en': 'Call rider', 'ur': 'رائیڈر کو کال کریں'},
  'rider_on_map': {'en': 'See rider on map', 'ur': 'رائیڈر نقشے پر دیکھیں'},
  'rider_updated': {'en': 'Location updated {t}', 'ur': 'مقام اپ ڈیٹ {t}'},
  'deliver_to': {'en': 'Deliver to', 'ur': 'ترسیل کا پتہ'},
  'final_bill_note': {'en': 'The final bill is confirmed when your order is delivered.', 'ur': 'حتمی بل آرڈر کی ترسیل پر طے ہوگا۔'},

  // Market request
  'market_request_title': {'en': 'Tell us what you need', 'ur': 'ہمیں بتائیں آپ کو کیا چاہیے'},
  'market_request_hint': {'en': 'e.g.\n2 kg potatoes\n1 dozen eggs\n1 packet Tapal tea (190 g)', 'ur': 'مثلاً\n2 کلو آلو\n1 درجن انڈے\n1 پیکٹ تاپال چائے'},
  'market_request_info': {'en': 'We buy these from the market and deliver them to you. You pay the actual price plus delivery, in cash, when the order arrives.', 'ur': 'ہم یہ اشیاء بازار سے خرید کر آپ تک پہنچائیں گے۔ آرڈر ملنے پر اصل قیمت اور ڈیلیوری چارج نقد ادا کریں۔'},
  'market_request_empty': {'en': 'Please write what you would like us to buy.', 'ur': 'براہ کرم لکھیں کہ ہم آپ کے لیے کیا خریدیں۔'},
  'send_request': {'en': 'Send my list', 'ur': 'میری فہرست بھیجیں'},
  'write_list': {'en': 'Write your shopping list', 'ur': 'اپنی خریداری کی فہرست لکھیں'},

  // Addresses
  'addresses': {'en': 'My addresses', 'ur': 'میرے پتے'},
  'no_addresses': {'en': 'You have no saved addresses yet.', 'ur': 'آپ کا کوئی محفوظ پتہ نہیں۔'},
  'address_label': {'en': 'Label (e.g. Home, Office)', 'ur': 'نام (مثلاً گھر، دفتر)'},
  'address_line': {'en': 'House, street, area', 'ur': 'مکان، گلی، علاقہ'},
  'city': {'en': 'City', 'ur': 'شہر'},
  'use_my_location': {'en': 'Use my current location', 'ur': 'میرا موجودہ مقام استعمال کریں'},
  'delivery_location': {'en': 'Delivery location on map', 'ur': 'نقشے پر ڈیلیوری کی جگہ'},
  'pick_on_map': {'en': 'Choose location on map', 'ur': 'نقشے پر جگہ منتخب کریں'},
  'change_on_map': {'en': 'Change location on map', 'ur': 'نقشے پر جگہ تبدیل کریں'},
  'pin_set': {'en': 'Delivery point pinned on the map', 'ur': 'ڈیلیوری کی جگہ نقشے پر مقرر'},
  'pin_missing': {'en': 'No map pin – delivery charge confirmed on delivery', 'ur': 'نقشے پر پن نہیں – ڈیلیوری چارج ڈیلیوری پر طے ہوگا'},
  'adjust_pin': {'en': 'Adjust pin', 'ur': 'پن درست کریں'},
  'remove_location': {'en': 'Remove location', 'ur': 'لوکیشن ہٹائیں'},
  'keep_location': {'en': 'Keep this location', 'ur': 'یہی لوکیشن رکھیں'},
  'search_place': {'en': 'Search area, street or landmark', 'ur': 'علاقہ، گلی یا مشہور جگہ تلاش کریں'},
  'no_places_found': {'en': 'No places found. Try another name or move the map.', 'ur': 'کوئی جگہ نہیں ملی۔ دوسرا نام آزمائیں یا نقشہ ہلائیں۔'},
  'move_map_hint': {'en': 'Move the map so the pin is on the delivery point.', 'ur': 'نقشہ ہلا کر پن کو ڈیلیوری کی جگہ پر رکھیں۔'},
  'confirm_location': {'en': 'Confirm this location', 'ur': 'یہ لوکیشن کنفرم کریں'},
  'nearest_branch': {'en': '{km} km from {branch}', 'ur': '{branch} سے {km} کلومیٹر'},
  'far_from_branches': {'en': 'This point is {km} km from our nearest branch – outside our delivery area.', 'ur': 'یہ جگہ ہماری قریبی برانچ سے {km} کلومیٹر دور ہے – ڈیلیوری علاقے سے باہر۔'},
  'gps_far_warning': {'en': 'You are {km} km from our nearest branch. If the order is for another place (for example, you are ordering from another city), choose the delivery location on the map.', 'ur': 'آپ ہماری قریبی برانچ سے {km} کلومیٹر دور ہیں۔ اگر آرڈر کسی اور جگہ کے لیے ہے (مثلاً آپ دوسرے شہر سے آرڈر کر رہے ہیں) تو نقشے پر ڈیلیوری کی جگہ منتخب کریں۔'},
  'location_saved': {'en': 'Map location saved – delivery charge will be calculated automatically.', 'ur': 'نقشے پر مقام محفوظ – ڈیلیوری چارج خودکار طور پر لگے گا۔'},
  'location_missing': {'en': 'No map location – the delivery charge will be confirmed by the rider.', 'ur': 'نقشے پر مقام نہیں – ڈیلیوری چارج رائیڈر طے کرے گا۔'},
  'location_denied': {'en': 'Location permission is off. You can still save the address without it.', 'ur': 'مقام کی اجازت بند ہے۔ آپ اس کے بغیر بھی پتہ محفوظ کر سکتے ہیں۔'},
  'location_off': {'en': 'Please turn on location (GPS) on your phone.', 'ur': 'براہ کرم فون میں لوکیشن (GPS) آن کریں۔'},
  'default_address': {'en': 'Default', 'ur': 'بنیادی'},
  'make_default': {'en': 'Make default', 'ur': 'بنیادی بنائیں'},
  'edit': {'en': 'Edit', 'ur': 'ترمیم'},
  'delete': {'en': 'Delete', 'ur': 'حذف کریں'},
  'delete_address_q': {'en': 'Delete this address?', 'ur': 'کیا یہ پتہ حذف کریں؟'},

  // Profile
  'profile': {'en': 'Profile', 'ur': 'پروفائل'},
  'profile_saved': {'en': 'Profile saved.', 'ur': 'پروفائل محفوظ ہو گیا۔'},
  'change_password': {'en': 'Change password', 'ur': 'پاس ورڈ تبدیل کریں'},
  'current_password': {'en': 'Current password', 'ur': 'موجودہ پاس ورڈ'},
  'new_password': {'en': 'New password (min. 6 characters)', 'ur': 'نیا پاس ورڈ (کم از کم 6 حروف)'},
  'password_changed': {'en': 'Password changed.', 'ur': 'پاس ورڈ تبدیل ہو گیا۔'},
  'delete_account': {'en': 'Delete my account', 'ur': 'میرا اکاؤنٹ حذف کریں'},
  'delete_account_q': {'en': 'Delete your account? You will not be able to log in again. Your past orders are kept for our records.', 'ur': 'کیا اکاؤنٹ حذف کریں؟ آپ دوبارہ لاگ ان نہیں کر سکیں گے۔ پچھلے آرڈرز ہمارے ریکارڈ میں رہیں گے۔'},
  'account_deleted': {'en': 'Your account has been deleted.', 'ur': 'آپ کا اکاؤنٹ حذف ہو گیا ہے۔'},
  'security': {'en': 'Security', 'ur': 'سیکیورٹی'},

  // Order Now chooser
  'how_to_order_en': {'en': 'How would you like to order?', 'ur': 'How would you like to order?'},
  'how_to_order_ur': {'en': 'آپ کس طرح آرڈر کرنا چاہتے ہیں؟', 'ur': 'آپ کس طرح آرڈر کرنا چاہتے ہیں؟'},
  'online_order': {'en': 'Online Order', 'ur': 'آن لائن آرڈر'},
  'online_order_sub': {'en': 'Choose products and check out in the app', 'ur': 'ایپ میں اشیاء منتخب کر کے آرڈر کریں'},
  'call_order': {'en': 'Call', 'ur': 'کال کریں'},
  'call_order_sub': {'en': 'Tell us your order on the phone', 'ur': 'فون پر اپنا آرڈر بتائیں'},
  'whatsapp_order': {'en': 'WhatsApp', 'ur': 'واٹس ایپ'},
  'whatsapp_order_sub': {'en': 'Send us your list on WhatsApp', 'ur': 'واٹس ایپ پر اپنی فہرست بھیجیں'},
  'whatsapp_greeting': {'en': 'Assalam o Alaikum, I would like to place an order.', 'ur': 'السلام علیکم، میں آرڈر دینا چاہتا/چاہتی ہوں۔'},
  'no_contact_number': {'en': 'Our phone number is not available yet. Please order online.', 'ur': 'ہمارا فون نمبر ابھی دستیاب نہیں۔ براہ کرم آن لائن آرڈر کریں۔'},
  'prefer_phone': {'en': 'Prefer to order by phone?', 'ur': 'فون پر آرڈر کرنا چاہتے ہیں؟'},

  // Branches
  'select_branch': {'en': 'Choose a branch', 'ur': 'برانچ منتخب کریں'},
  'branch_choose_hint': {'en': 'Choose the branch that will prepare and deliver your order.', 'ur': 'وہ برانچ منتخب کریں جو آپ کا آرڈر تیار کر کے پہنچائے گی۔'},
  'need_branch': {'en': 'Please choose a branch first.', 'ur': 'براہ کرم پہلے برانچ منتخب کریں۔'},
  'branch_unavailable': {'en': 'That branch is not taking orders right now. Please choose another branch.', 'ur': 'یہ برانچ اس وقت آرڈر نہیں لے رہی۔ براہ کرم کوئی اور برانچ منتخب کریں۔'},
  'open_now': {'en': 'Open now', 'ur': 'ابھی کھلی ہے'},
  'closed_now': {'en': 'Closed now', 'ur': 'ابھی بند ہے'},
  'km_away': {'en': '{km} km away', 'ur': '{km} کلومیٹر دور'},
  'delivery_rs': {'en': 'Delivery Rs. {n}', 'ur': 'ڈیلیوری {n} روپے'},
  'branch_outside_area': {'en': 'Does not deliver to this address', 'ur': 'اس پتے پر ڈیلیوری نہیں کرتی'},
  'after_branch': {'en': 'After choosing a branch', 'ur': 'برانچ منتخب کرنے کے بعد'},
  'branch_distance_hint': {'en': 'Add your location to the delivery address to see distances and charges.', 'ur': 'فاصلہ اور چارجز دیکھنے کے لیے ڈیلیوری کے پتے میں اپنی لوکیشن شامل کریں۔'},
  'view_on_map': {'en': 'View on map', 'ur': 'نقشے پر دیکھیں'},
  'location': {'en': 'Location', 'ur': 'مقام'},

  // Shop / market items
  'shop_all': {'en': 'All categories', 'ur': 'تمام کیٹیگریز'},
  'market_items_title': {'en': 'Market items', 'ur': 'بازار کی اشیاء'},
  'not_in_list': {'en': 'Item not in the list? Add it', 'ur': 'چیز فہرست میں نہیں؟ شامل کریں'},
  'custom_item_name': {'en': 'What do you need? (name, brand, size)', 'ur': 'آپ کو کیا چاہیے؟ (نام، برانڈ، سائز)'},
  'quantity': {'en': 'Quantity', 'ur': 'مقدار'},
  'custom_items_section': {'en': 'Market items – price confirmed at delivery', 'ur': 'بازار کی اشیاء – قیمت ڈیلیوری پر طے ہوگی'},
  'custom_item_added': {'en': 'Added to your cart', 'ur': 'کارٹ میں شامل ہو گیا'},
  'price_at_delivery': {'en': 'Price at delivery', 'ur': 'قیمت ڈیلیوری پر'},

  // My Orders tabs
  'history': {'en': 'History', 'ur': 'تاریخچہ'},
  'favorite_orders': {'en': 'Favorites', 'ur': 'پسندیدہ'},
  'no_favorite_orders': {'en': 'Tap ☆ on any order to keep it here and reorder it quickly.', 'ur': 'کسی بھی آرڈر پر ☆ دبائیں تاکہ وہ یہاں محفوظ ہو اور آسانی سے دوبارہ منگوایا جا سکے۔'},
  'star_order': {'en': 'Add to favorite orders', 'ur': 'پسندیدہ آرڈرز میں شامل کریں'},
  'unstar_order': {'en': 'Remove from favorite orders', 'ur': 'پسندیدہ آرڈرز سے ہٹائیں'},

  // Notifications
  'notifications': {'en': 'Notifications', 'ur': 'اطلاعات'},
  'no_notifications': {'en': 'No notifications yet. Order updates and offers will appear here.', 'ur': 'ابھی کوئی اطلاع نہیں۔ آرڈر کی اپ ڈیٹس اور آفرز یہاں نظر آئیں گی۔'},
  'notification_settings': {'en': 'Notification settings', 'ur': 'اطلاعات کی ترتیبات'},
  'notify_orders': {'en': 'Order updates', 'ur': 'آرڈر کی اپ ڈیٹس'},
  'notify_orders_sub': {'en': 'Always on – you need these to follow your orders.', 'ur': 'ہمیشہ آن – آرڈر کی معلومات کے لیے ضروری۔'},
  'notify_promos': {'en': 'Offers & deals', 'ur': 'آفرز اور ڈیلز'},
  'notify_promos_sub': {'en': 'Discounts, deals and new products.', 'ur': 'رعایتیں، ڈیلز اور نئی اشیاء۔'},
  'just_now': {'en': 'just now', 'ur': 'ابھی'},
  'minutes_ago': {'en': '{n} min ago', 'ur': '{n} منٹ پہلے'},
  'hours_ago': {'en': '{n} h ago', 'ur': '{n} گھنٹے پہلے'},

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

  /// Translation with `{name}` placeholders filled in.
  String trf(String key, Map<String, Object> values) {
    var s = tr(key);
    values.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}

/// Short date + time, e.g. 27/9/2026 14:05.
String formatDateTime(DateTime? d) => d == null
    ? ''
    : '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Maps an [ApiResult]-style error into a customer-friendly message.
String friendlyError(BuildContext context, {String? errorCode, String? serverMessage}) {
  if (errorCode == 'network') return context.tr('err_network');
  if (errorCode == 'session_expired') return context.tr('err_session');
  if (serverMessage != null && serverMessage.isNotEmpty && context.lang == 'en') return serverMessage;
  return context.tr('err_generic');
}
