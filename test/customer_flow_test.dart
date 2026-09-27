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
        case '/auth/logout':
          return http.Response('{"message":"Logged out."}', 200, headers: json);
        case '/me/favorites':
        case '/orders/mine':
          return http.Response('[]', 200, headers: json);
        case '/me/notifications/unread-count':
          return http.Response('{"unread":0}', 200, headers: json);
      }
      return http.Response('{"error":"not found"}', 404, headers: json);
    });

Future<AppState> startApp(WidgetTester tester, {bool loggedIn = false, String lang = 'en'}) async {
  tester.view.physicalSize = const Size(1080, 2340); // typical Android phone
  tester.view.devicePixelRatio = 2.75;
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
  testWidgets('home shows categories, market and deal products', (tester) async {
    await startApp(tester);
    expect(tester.takeException(), isNull);

    final home = jsonDecode(fixture('home'));
    final deals = (home['discounted_products'] as List).map((p) => p['name'] as String).toList();
    expect(find.text('Market Shopping'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Deals & Discounts'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Deals & Discounts'), findsOneWidget);
    expect(find.text(deals.first), findsWidgets, reason: 'deal products should be visible on the home page');
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

    for (final tab in ['My Orders', 'Favorites', 'My Account']) {
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
    expect(find.text('Market Shopping'), findsWidgets);
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
        if (e != null) errors.add('${entry.key}: $e');
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
}
