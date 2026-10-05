// Phase 1 of "requirement specs 5-10-2026 v2": staying logged in (1), admin
// categories on the home page (4), address field visible above the keyboard (8),
// branch selection before confirming (11) and reactivating removed staff (15).
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

import 'package:grozo/models/product.dart';
import 'package:grozo/services/api.dart';
import 'package:grozo/state/app_state.dart';
import 'package:grozo/utils/opening_hours.dart';
import 'package:grozo/views/account/addresses_view.dart';
import 'package:grozo/views/admin/add_user_view.dart';
import 'package:grozo/views/checkout/checkout_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/shell/grozo_header.dart';
import 'package:grozo/views/shell/main_shell.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

/// "METHOD /path" of every request, and the decoded JSON body of each.
final requests = <String>[];
final bodies = <String, List<dynamic>>{};

/// Per-test overrides: path -> (status, json body).
final overrides = <String, (int, Object)>{};

const _json = {'content-type': 'application/json; charset=utf-8'};

const twoBranches = [
  {'id': 1, 'name': 'Mandian Branch', 'address': 'Mandian Road', 'opening_hours': '12:00 AM - 11:59 PM', 'latitude': '34.19', 'longitude': '73.23', 'is_active': 1},
  {'id': 2, 'name': 'Supply Branch', 'address': 'Supply Bazaar', 'opening_hours': null, 'latitude': '34.15', 'longitude': '73.21', 'is_active': 1},
];

http.Client fakeServer() => MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      final key = '${req.method} $path';
      requests.add(key);
      if (req.body.isNotEmpty && req.headers['content-type']?.contains('json') == true) {
        (bodies[key] ??= []).add(jsonDecode(req.body));
      }
      final o = overrides[key] ?? overrides[path];
      if (o != null) return http.Response.bytes(utf8.encode(jsonEncode(o.$2)), o.$1, headers: _json);
      switch (path) {
        case '/home':
        case '/categories':
        case '/products':
          return http.Response.bytes(utf8.encode(fixture(path.substring(1))), 200, headers: _json);
        case '/branches':
          return http.Response.bytes(utf8.encode(fixture('branches')), 200, headers: _json);
        case '/admin/summary':
          return http.Response(jsonEncode({'today_orders': 0, 'today_delivered_value': 0, 'unclaimed_orders': 0, 'active_orders': 0, 'low_stock': []}), 200, headers: _json);
        case '/auth/me':
          return http.Response(jsonEncode({'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': 'Customer', 'mobile': '0300-1234567'}), 200, headers: _json);
        case '/me/notifications/unread-count':
          return http.Response('{"unread":0}', 200, headers: _json);
      }
      if (req.method == 'GET') return http.Response('[]', 200, headers: _json);
      return http.Response('{"error":"not found"}', 404, headers: _json);
    });

Future<AppState> startApp(WidgetTester tester,
    {bool loggedIn = true, Size dp = const Size(393, 851), Widget? home, String? role}) async {
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = dp * 2.75;
  tester.view.padding = const FakeViewPadding(top: 24 * 2.75, bottom: 16 * 2.75);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'language': 'en'});
  FlutterSecureStorage.setMockInitialValues(loggedIn
      ? {
          'auth_token': 'test-token',
          'auth_user': jsonEncode({'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': role ?? 'Customer'}),
        }
      : {});
  Api.client = fakeServer();
  Api.token = null;

  final state = AppState();
  await tester.runAsync(state.load);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home ?? const MainShell(),
    ),
  ));
  await settle(tester);
  return state;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> stopApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    requests.clear();
    bodies.clear();
    overrides.clear();
  });

  group('1. My Orders keeps the login', () {
    testWidgets('a renewed token from the server is stored for the next start', (tester) async {
      overrides['/auth/me'] = (200, {'id': 15, 'name': 'Test Customer', 'email': 't@example.com', 'role': 'Customer', 'token': 'renewed-token'});
      final state = await startApp(tester);
      expect(state.isLoggedIn, isTrue);
      expect(Api.token, 'renewed-token');
      await stopApp(tester);

      // Next app start uses the renewed token.
      final reopened = AppState();
      await tester.runAsync(reopened.load);
      expect(reopened.isLoggedIn, isTrue);
      expect(Api.token, 'renewed-token');
    });

    testWidgets('a logged-in customer reopening the app sees My Orders, not a login page', (tester) async {
      await startApp(tester);
      await tester.tap(find.text('My Orders').last);
      await settle(tester);
      expect(find.text('Please log in'), findsNothing);
      expect(requests, contains('GET /orders/mine'));
      await stopApp(tester);
    });
  });

  group('4. Admin categories on the home page', () {
    Map<String, dynamic> homeWithFeatured(int n) {
      final home = Map<String, dynamic>.from(jsonDecode(fixture('home')));
      home['featured_categories'] = [
        for (var i = 1; i <= n; i++)
          {'id': 900 + i, 'name': 'Featured $i', 'display_group': 'featured', 'is_active': 1, 'products': []}
      ];
      return home;
    }

    testWidgets('every active featured category is reachable, not only the first two', (tester) async {
      overrides['/home'] = (200, homeWithFeatured(4));
      await startApp(tester);
      expect(tester.takeException(), isNull);
      for (var i = 1; i <= 4; i++) {
        final card = find.text('Featured $i');
        await tester.dragUntilVisible(card, find.byType(ListView).first, const Offset(-150, 0));
        expect(card, findsOneWidget);
      }
      await stopApp(tester);
    });

    testWidgets('a category added in the admin app shows after returning to Home', (tester) async {
      overrides['/home'] = (200, homeWithFeatured(1));
      await startApp(tester);
      expect(find.text('Featured 2'), findsNothing);

      overrides['/home'] = (200, homeWithFeatured(2));
      await tester.tap(find.text('My Orders').last);
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 21)));
      await tester.tap(find.text('Home').last);
      await settle(tester);
      expect(find.text('Featured 2'), findsOneWidget);
      await stopApp(tester);
    });
  });

  group('8. Address field stays visible while typing', () {
    for (final dp in const [Size(360, 640), Size(393, 851)]) {
      testWidgets('address field above the keyboard at ${dp.width.toInt()}x${dp.height.toInt()}', (tester) async {
        await startApp(tester, dp: dp);
        MainShell.push(tester.element(find.byType(HomeView)), const AddressEditView());
        await settle(tester);

        final field = find.widgetWithText(TextFormField, 'House, street, area *');
        await tester.tap(field);
        // A typical phone keyboard: about 45% of the screen.
        tester.view.viewInsets = FakeViewPadding(bottom: dp.height * 0.45 * 2.75);
        await settle(tester);
        await tester.enterText(field, 'House 12, Street 4, Jinnahabad');
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(GrozoHeader), findsNothing, reason: 'header makes room while typing');
        expect(field.hitTestable(), findsOneWidget, reason: 'the field being typed in must stay visible');
        final box = tester.getRect(find.text('House 12, Street 4, Jinnahabad'));
        expect(box.bottom, lessThan(dp.height * 0.55), reason: 'typed text is above the keyboard');

        tester.view.resetViewInsets();
        await settle(tester);
        expect(find.byType(GrozoHeader), findsOneWidget);
        await stopApp(tester);
      });
    }
  });

  group('11. Branch selection before confirming', () {
    Map<String, dynamic> quote({bool outsideFor2 = false}) => {
          'lines': [
            {'product_id': 1, 'name': 'Potato', 'qty': 1, 'price': 100, 'original_price': 100, 'line_total': 100, 'line_discount': 0}
          ],
          'problems': [],
          'subtotal': 100,
          'discount_total': 0,
          'delivery_charge': 50,
          'total': 150,
          'branch_options': [
            {'id': 1, 'name': 'Mandian Branch', 'address': 'Mandian Road', 'opening_hours': '12:00 AM - 11:59 PM', 'distance_km': 1.2, 'delivery_charge': 50, 'outside_delivery_area': false},
            {'id': 2, 'name': 'Supply Branch', 'address': 'Supply Bazaar', 'opening_hours': null, 'distance_km': 14.8, 'delivery_charge': null, 'outside_delivery_area': outsideFor2},
          ],
        };

    Future<AppState> openCheckout(WidgetTester tester) async {
      overrides['/branches'] = (200, twoBranches);
      overrides['/me/addresses'] = (200, [
        {'id': 7, 'label': 'Home', 'address_line': 'House 1', 'city': 'Abbottabad', 'latitude': '34.17', 'longitude': '73.22', 'is_default': 1}
      ]);
      overrides['/orders/quote'] = (200, quote(outsideFor2: true));
      final state = await startApp(tester);
      final products = (jsonDecode(fixture('products')) as List).map((p) => Product.fromJson(p)).toList();
      state.addToCart(products.firstWhere((p) => p.available));
      MainShell.push(tester.element(find.byType(HomeView)), const CheckoutView());
      await settle(tester);
      return state;
    }

    Finder inCheckout(String text) =>
        find.descendant(of: find.byType(CheckoutView), matching: find.text(text));

    testWidgets('with several branches the customer must choose one; nothing is picked silently', (tester) async {
      final state = await openCheckout(tester);
      expect(state.hasChosenBranch, isFalse);
      expect(find.text('Choose the branch that will prepare and deliver your order.'), findsOneWidget);
      expect(inCheckout('Mandian Branch'), findsOneWidget);
      expect(inCheckout('Supply Branch'), findsOneWidget);
      // Distance, opening status and charge are shown for each branch.
      expect(find.text('1.2 km away'), findsOneWidget);
      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('Delivery Rs. 50'), findsOneWidget);
      expect(find.text('Does not deliver to this address'), findsOneWidget);
      await tester.scrollUntilVisible(inCheckout('After choosing a branch'), 200,
          scrollable: find.descendant(of: find.byType(CheckoutView), matching: find.byType(Scrollable)).first);
      expect(inCheckout('After choosing a branch'), findsOneWidget);
      // Back to the top, where the branch list is.
      await tester.drag(find.descendant(of: find.byType(CheckoutView), matching: find.byType(Scrollable)).first,
          const Offset(0, 2000));
      await settle(tester);

      final confirm = find.widgetWithText(ElevatedButton, 'Choose a branch');
      expect(confirm, findsOneWidget);
      expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull, reason: 'cannot confirm without a branch');
      expect(bodies['POST /orders/quote']!.first['branchId'], isNull);

      await tester.tap(inCheckout('Mandian Branch'));
      await settle(tester);
      expect(bodies['POST /orders/quote']!.last['branchId'], 1);
      expect(state.hasChosenBranch, isTrue, reason: 'header shows the chosen branch too');
      final ready = find.widgetWithText(ElevatedButton, 'Confirm order  •  Rs. 150');
      expect(tester.widget<ElevatedButton>(ready).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await stopApp(tester);
    });

    testWidgets('the order is placed for the chosen branch', (tester) async {
      await openCheckout(tester);
      overrides['POST /orders'] = (409, {'error': 'cart_changed', 'quote': quote()});
      await tester.tap(inCheckout('Mandian Branch'));
      await settle(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm order  •  Rs. 150'));
      await settle(tester);
      expect(bodies['POST /orders']!.single['branchId'], 1);
      await stopApp(tester);
    });

    testWidgets('a branch that stopped taking orders is not swapped for another', (tester) async {
      await openCheckout(tester);
      overrides['/orders/quote'] = (200, {...quote(), 'problems': [{'reason': 'branch_unavailable'}]});
      await tester.tap(inCheckout('Supply Branch'));
      await settle(tester);
      expect(find.text('That branch is not taking orders right now. Please choose another branch.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Choose a branch'), findsOneWidget);
      await stopApp(tester);
    });

    test('opening hours are understood', () {
      DateTime at(int h, int m) => DateTime(2026, 10, 5, h, m);
      const store = '7:00 AM – 11:00 PM (closed during prayer times)';
      expect(isOpenAt(store, at(6, 59)), isFalse);
      expect(isOpenAt(store, at(7, 0)), isTrue);
      expect(isOpenAt(store, at(22, 59)), isTrue);
      expect(isOpenAt(store, at(23, 0)), isFalse);
      expect(isOpenAt('09:00 - 21:30', at(21, 0)), isTrue);
      expect(isOpenAt('09:00 - 21:30', at(21, 31)), isFalse);
      expect(isOpenAt('6 pm - 2 am', at(1, 0)), isTrue, reason: 'overnight');
      expect(isOpenAt('6 pm - 2 am', at(12, 0)), isFalse);
      expect(isOpenAt('Open 24/7', at(3, 0)), isTrue);
      expect(isOpenAt('Ask the shop', at(3, 0)), isNull);
      expect(isOpenAt(null, at(3, 0)), isNull);
    });
  });

  group('15. Re-adding removed staff', () {
    testWidgets('admin is offered Reactivate instead of "already added"', (tester) async {
      overrides['POST /admin/add-user'] = (409, {
        'error': 'Ali (Rider) was removed earlier with this email. Reactivate this account?',
        'message': 'Ali (Rider) was removed earlier with this email. Reactivate this account?',
        'code': 'inactive_user',
        'user': {'id': 42, 'name': 'Ali', 'email': 'ali@grozo.pk', 'role': 'Rider'},
      });
      overrides['PUT /admin/42/reactivate'] = (200, {'message': 'Ali has been reactivated.'});
      await startApp(tester, home: const AddUserView(), role: 'Admin');

      await tester.tap(find.text('Add Staff'));
      await settle(tester);
      Future<void> fill(String label, String text) async {
        final f = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, text);
      }

      await fill('Full Name', 'Ali');
      await fill('Email Address', 'ali@grozo.pk');
      await fill('Security Password', 'newpass1');
      await fill('CNIC (NNNNN-NNNNNNN-N)', '12345-1234567-1');
      await fill('Mobile Phone (NNNN-NNNNNNN)', '0300-1234567');
      await tester.ensureVisible(find.text('PROVISION ACCESS ACCOUNT'));
      await tester.tap(find.text('PROVISION ACCESS ACCOUNT'));
      await settle(tester);

      expect(find.text('Previously removed staff'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reactivate'));
      await settle(tester);

      final body = bodies['PUT /admin/42/reactivate']!.single;
      expect(body['role'], 'Rider');
      expect(body['password'], 'newpass1');
      expect(body['mobile'], '0300-1234567');
      expect(find.text('Ali has been reactivated.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await stopApp(tester);
    });

    testWidgets('removed staff are listed with a Reactivate button', (tester) async {
      overrides['GET /admin/inactive'] = (200, [
        {'id': 42, 'name': 'Ali', 'email': 'ali@grozo.pk', 'role': 'Rider', 'mobile': '0300-1234567'}
      ]);
      overrides['PUT /admin/42/reactivate'] = (200, {'message': 'Ali has been reactivated.'});
      await startApp(tester, home: const AddUserView(), role: 'Admin');
      await tester.tap(find.text('Manage'));
      await settle(tester);
      await tester.tap(find.text('Removed staff (1)'));
      await settle(tester);
      await tester.tap(find.text('REACTIVATE'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Reactivate'));
      await settle(tester);
      expect(requests, contains('PUT /admin/42/reactivate'));
      expect(tester.takeException(), isNull);
      await stopApp(tester);
    });
  });
}
