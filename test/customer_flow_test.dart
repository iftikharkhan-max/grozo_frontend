// Customer frame against responses recorded from the live server
// (test/fixtures), at a real phone size.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grozo/services/api.dart';
import 'package:grozo/models/product.dart';
import 'package:grozo/views/account/addresses_view.dart';
import 'package:grozo/views/account/profile_view.dart';
import 'package:grozo/views/cart/cart_view.dart';
import 'package:grozo/views/catalog/market_view.dart';
import 'package:grozo/views/catalog/product_detail_view.dart';
import 'package:grozo/views/catalog/product_list_view.dart';
import 'package:grozo/views/catalog/shop_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/notifications/notifications_view.dart';
import 'package:grozo/views/partners/partner_view.dart';
import 'package:grozo/views/shell/grozo_header.dart';
import 'package:grozo/state/app_state.dart';
import 'package:grozo/views/shell/main_shell.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

final requests = <String>[];

http.Client fakeServer() => MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      requests.add('${req.method} $path');
      const json = {'content-type': 'application/json; charset=utf-8'};
      switch (path) {
        case '/home':
          return http.Response.bytes(utf8.encode(fixture('home')), 200, headers: json);
        case '/branches':
          return http.Response.bytes(utf8.encode(fixture('branches')), 200, headers: json);
        case '/categories':
          return http.Response.bytes(utf8.encode(fixture('categories')), 200, headers: json);
        case '/products':
          return http.Response.bytes(utf8.encode(fixture('products')), 200, headers: json);
        case '/settings':
          return http.Response('{}', 200, headers: json);
        case '/auth/me':
          return http.Response(jsonEncode({'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': 'Customer'}), 200, headers: json);
        case '/auth/login':
          return http.Response(jsonEncode({'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': 'Customer', 'token': 'new-token'}), 200, headers: json);
        case '/me/addresses':
          return http.Response('[]', 200, headers: json);
        case '/orders/quote':
          return http.Response(jsonEncode({'lines': [], 'problems': [], 'subtotal': 0, 'discount_total': 0, 'delivery_charge': null, 'total': 0}), 200, headers: json);
        case '/auth/logout':
          return http.Response('{"message":"Logged out."}', 200, headers: json);
        case '/me/favorites':
        case '/orders/mine':
          return http.Response('[]', 200, headers: json);
        case '/me/notifications/unread-count':
          return http.Response('{"unread":0}', 200, headers: json);
        case '/delivery-charges':
          return http.Response.bytes(utf8.encode(jsonEncode(jsonDecode(fixture('home'))['delivery_charges'])), 200, headers: json);
        case '/partners':
          return http.Response.bytes(utf8.encode(jsonEncode(jsonDecode(fixture('home'))['partners'])), 200, headers: json);
        case '/partners/3':
          final partner = (jsonDecode(fixture('home'))['partners'] as List).first as Map;
          return http.Response.bytes(utf8.encode(jsonEncode({...partner, 'products': partnerItems})), 200, headers: json);
      }
      return http.Response('{"error":"not found"}', 404, headers: json);
    });

/// Faridullah Fish's items (partner 3 in the home fixture).
final partnerItems = [
  {'id': 501, 'name': 'Rahu fish', 'price': 1200, 'final_price': 1200, 'unit': '1 kg', 'available': true,
   'partner_id': 3, 'partner_name': 'Faridullah Fish'},
  {'id': 502, 'name': 'Fried fish plate', 'price': 650, 'final_price': 650, 'available': true,
   'partner_id': 3, 'partner_name': 'Faridullah Fish'},
];

/// Where layout errors happened (file:line), so failures name the widget.
final errorWhere = <String>[];

Future<AppState> startApp(WidgetTester tester, {bool loggedIn = false, String lang = 'en', Size dp = const Size(393, 851)}) async {
  errorWhere.clear();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    errorWhere.addAll(RegExp(r'lib/[\w/%]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)!));
    previousOnError?.call(d);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
  // A phone of [dp] logical pixels, with status bar and gesture bar.
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = dp * 2.75;
  tester.view.padding = const FakeViewPadding(top: 24 * 2.75, bottom: 16 * 2.75);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'language': lang});
  FlutterSecureStorage.setMockInitialValues(loggedIn
      ? {
          'auth_token': 'test-token',
          'auth_user': jsonEncode({'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': 'Customer'}),
        }
      : {});
  Api.client = fakeServer();
  Api.token = null;
  requests.clear();

  final state = AppState();
  await tester.runAsync(state.load);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    ),
  ));
  await settle(tester);
  return state;
}

/// Lets fake network calls finish and animations run.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unmount so the app's periodic timers are cancelled before the test ends.
Future<void> stopApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('home: Explore Categories, "not in the list" and Order from our partners', (tester) async {
    final state = await startApp(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Explore Categories'), findsOneWidget);
    // Six categories on the home page (two columns); View all lists the rest.
    for (final name in ['Vegetables', 'Fruits', 'Dairy & Eggs', 'Bakery', 'Beverages', 'Baby Care']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Home Care'), findsNothing);
    expect(find.text('Deals & Discounts'), findsNothing, reason: 'replaced by partners');
    final scroll = find.descendant(of: find.byType(HomeView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('FARIDULLAH FISH'), 200, scrollable: scroll);
    expect(find.text('Order from our partners'), findsOneWidget);
    expect(find.text('Fish'), findsOneWidget);
    expect(find.text('SAVOUR FOODS'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    // A partner's page lists all its items with prices; they go in their own order.
    // (Scrolled clear of the footer and the round Order Now button first.)
    await tester.drag(scroll, const Offset(0, -2000));
    await settle(tester);
    await tester.tap(find.text('FARIDULLAH FISH'));
    await settle(tester);
    expect(find.byType(PartnerView), findsOneWidget);
    expect(find.text('Rahu fish'), findsOneWidget);
    expect(find.text('Rs. 1200'), findsOneWidget);
    state.addCustomItem('Sugar 1 kg', 1);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add').first);
    await settle(tester);
    expect(find.text('Added. Items from Faridullah Fish will be a separate order.'), findsOneWidget);
    expect(state.cartGroups, [null, 3]);
    expect(tester.takeException(), isNull);

    // View all categories.
    Navigator.of(tester.element(find.byType(PartnerView))).pop();
    await settle(tester);
    await tester.drag(scroll, const Offset(0, 3000)); // back to the top
    await settle(tester);
    await tester.tap(find.text('View all').first);
    await settle(tester);
    expect(find.byType(AllCategoriesView), findsOneWidget);
    expect(find.text('Home Care'), findsOneWidget);
    await stopApp(tester);
  });

  testWidgets('cart with groceries and a partner: one order each', (tester) async {
    final state = await startApp(tester, loggedIn: true);
    final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
    state.addToCart(products.firstWhere((p) => p.available && !p.hasVariants));
    state.addToCart(Product.fromJson(partnerItems.first), qty: 2);
    await settle(tester);
    await tester.tap(find.byTooltip('Cart'));
    await settle(tester);
    expect(find.text('Each shop is a separate order with its own delivery charge.'), findsOneWidget);
    expect(find.text('Grozo groceries'), findsOneWidget);
    expect(find.text('Faridullah Fish'), findsOneWidget);

    await tester.tap(find.text('Proceed to checkout'));
    await settle(tester);
    // Asked which order first.
    await tester.tap(find.text('Faridullah Fish').last);
    await settle(tester);
    expect(find.text('Checkout – Faridullah Fish'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await stopApp(tester);
  });

  testWidgets('customer can log out from the menu', (tester) async {
    final state = await startApp(tester, loggedIn: true);
    expect(state.isLoggedIn, isTrue);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Logout').last);
    await settle(tester);
    // Confirmation dialog
    await tester.tap(find.widgetWithText(TextButton, 'Logout'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(state.isLoggedIn, isFalse);
    expect(requests, contains('POST /auth/logout'));
    expect(find.text('You have been logged out.'), findsOneWidget);
    await stopApp(tester);
  });

  testWidgets('customer can log out from My Account after visiting other tabs', (tester) async {
    final state = await startApp(tester, loggedIn: true);

    for (final tab in ['My Orders', 'Delivery Charges', 'My Account']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'opening $tab');
    }
    await tester.scrollUntilVisible(find.text('Logout'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Logout'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Logout'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(state.isLoggedIn, isFalse);
    // Back on the store home, logged out.
    expect(find.text('Explore Categories'), findsWidgets);
    await stopApp(tester);
  });

  for (final lang in ['en', 'ur']) {
    testWidgets('main customer pages render without layout errors ($lang)', (tester) async {
      final state = await startApp(tester, loggedIn: true, lang: lang);
      final categories = (jsonDecode(fixture('categories')) as List).map((c) => Category.fromJson(c)).toList();
      final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
      state.addToCart(products.firstWhere((p) => p.available));
      state.addCustomItem('Tapal tea 190g', 2);
      await settle(tester);

      final shellContext = tester.element(find.byType(HomeView));
      final errors = <String>[];
      final pages = <String, Widget>{
        'category products': ProductListView(category: categories.first),
        'market shopping': const MarketView(),
        'all categories': const ShopView(),
        'cart': const CartView(),
        'search': const ProductListView(searchMode: true),
        'product details': ProductDetailView(product: products.first),
        'my addresses': const AddressesView(),
        'profile': const ProfileView(),
        'notifications': const NotificationsView(),
      };
      for (final entry in pages.entries) {
        MainShell.push(shellContext, entry.value);
        await settle(tester);
        final e = tester.takeException();
        if (e != null) errors.add('${entry.key}: $e at $errorWhere');
        Navigator.of(tester.element(find.byWidget(entry.value))).pop();
        await settle(tester);
      }

      showDeliveryCharges(shellContext, List<Map<String, dynamic>>.from(jsonDecode(fixture('home'))['delivery_charges']));
      await settle(tester);
      if (tester.takeException() case final e?) errors.add('delivery charges: $e');
      Navigator.of(shellContext, rootNavigator: true).pop();
      await settle(tester);

      showBranchPicker(shellContext);
      await settle(tester);
      if (tester.takeException() case final e?) errors.add('branch picker: $e');

      expect(errors, isEmpty);
      await stopApp(tester);
    });
  }

  testWidgets('cart survives logging in at checkout; login fields are not covered', (tester) async {
    final state = await startApp(tester);
    final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
    state.addToCart(products.firstWhere((p) => p.available), qty: 2);
    state.addCustomItem('Tapal tea 190g', 1);
    await settle(tester);
    final before = state.cartCount;

    // Cart -> Proceed to checkout -> login screen.
    await tester.tap(find.byTooltip('Cart'));
    await settle(tester);
    await tester.tap(find.text('Proceed to checkout'));
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    // Keyboard open (as on a phone): the fields must stay visible and tappable.
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    await settle(tester);
    for (final label in ['Email address', 'Password']) {
      final field = find.widgetWithText(TextField, label);
      await tester.ensureVisible(field);
      await settle(tester);
      expect(field.hitTestable(), findsOneWidget, reason: '$label must not be hidden behind other buttons');
    }
    expect(find.text('Order Now').hitTestable(), findsNothing, reason: 'Order Now must not float over the login form');

    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 't@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
    tester.view.resetViewInsets();
    await settle(tester);
    await tester.tap(find.text('Sign in'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(state.isLoggedIn, isTrue);
    expect(state.cartCount, before, reason: 'cart must be kept after logging in');
    expect(find.text('Checkout'), findsWidgets, reason: 'customer continues to checkout after logging in');
    await stopApp(tester);
  });

  testWidgets('cart is kept when the app is closed and reopened', (tester) async {
    final state = await startApp(tester);
    final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
    state.addToCart(products.firstWhere((p) => p.available), qty: 3);
    state.addCustomItem('Sugar 1 kg', 2);
    await settle(tester);
    await stopApp(tester);

    // Same phone storage, fresh app start.
    final reopened = AppState();
    await tester.runAsync(reopened.load);
    expect(reopened.cartCount, 5);
    expect(reopened.customItems.single.name, 'Sugar 1 kg');
  });

  testWidgets('cart is kept when logging in from My Account', (tester) async {
    final state = await startApp(tester);
    final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
    state.addToCart(products.firstWhere((p) => p.available));
    await settle(tester);

    await tester.tap(find.text('My Account').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 't@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.tap(find.text('Sign in'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(state.isLoggedIn, isTrue);
    expect(state.cartCount, 1);
    await stopApp(tester);
  });

  testWidgets('Delivery Charges tab: table and a calculator with any delivery point', (tester) async {
    await startApp(tester);
    await tester.tap(find.text('Delivery Charges').last);
    await settle(tester);
    expect(find.text('Please log in'), findsNothing, reason: 'no login needed');
    expect(find.text('Check the delivery charge'), findsOneWidget);
    expect(find.text('Via partner shop (optional)'), findsOneWidget, reason: 'partner with a map location');
    expect(find.text('Choose location on map'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Charges by distance'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('0 – 2 KM'), findsOneWidget);
    expect(find.text('Rs. 150'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await stopApp(tester);
  });

  testWidgets('Favorites moved to My Account', (tester) async {
    await startApp(tester, loggedIn: true);
    expect(find.text('Favorites'), findsNothing, reason: 'not in the footer any more');
    await tester.tap(find.text('My Account').last);
    await settle(tester);
    await tester.tap(find.text('Favorites'));
    await settle(tester);
    expect(find.text('Favorites'), findsWidgets);
    expect(tester.takeException(), isNull);
    await stopApp(tester);
  });

  for (final tab in ['My Orders']) {
    testWidgets('after logging in from the $tab tab, it shows the real page (no login loop)', (tester) async {
      final state = await startApp(tester);
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(find.text('Please log in'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Email address'), 't@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
      await tester.tap(find.text('Sign in'));
      await settle(tester);

      expect(state.isLoggedIn, isTrue);
      expect(find.text('Please log in'), findsNothing, reason: '$tab must not ask to log in again');
      // Switching away and back must not bring the login page back either.
      await tester.tap(find.text('Home').last);
      await settle(tester);
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(find.text('Please log in'), findsNothing);
      expect(tester.takeException(), isNull);
      await stopApp(tester);
    });
  }

  for (final lang in ['en', 'ur']) {
    for (final dp in const [Size(360, 640), Size(360, 740), Size(393, 851), Size(412, 915)]) {
      testWidgets('home lays out without errors at ${dp.width.toInt()}x${dp.height.toInt()} ($lang)', (tester) async {
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          // Keep where it happened, so a failure names the widget and line.
          // The description names the widget that overflowed and its source line.
          final text = d.toString();
          final where = RegExp(r'lib/[\w/%]+\.dart:\d+').allMatches(text).map((m) => m.group(0)).toSet();
          if (where.isEmpty) File('build/layout_error.txt').writeAsStringSync(text);
          errors.add('${d.exceptionAsString().split('\n').first} at ${where.join(', ')}');
        };
        addTearDown(() => FlutterError.onError = previous);
        final state = await startApp(tester, lang: lang, dp: dp);
        state.addCustomItem('Sugar', 2);
        await settle(tester);
        // The banner and categories are on the first screen; scroll to the partners.
        final categories = lang == 'en' ? 'Explore Categories' : 'کیٹیگریز دیکھیں';
        final partners = lang == 'en' ? 'Order from our partners' : 'ہمارے پارٹنرز سے آرڈر کریں';
        expect(find.text(categories).hitTestable(), findsOneWidget);
        final homeScroll = find.descendant(of: find.byType(HomeView), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(find.text(partners), 200, scrollable: homeScroll);
        await tester.drag(homeScroll, const Offset(0, -2000));
        await settle(tester);
        expect(find.text(partners).hitTestable(), findsOneWidget);
        FlutterError.onError = previous;
        expect(errors.toSet(), isEmpty, reason: 'no overflow or layout errors');
        await stopApp(tester);
      });
    }
  }
}
