// Phase 2 of "requirement specs 5-10-2026 v2": compact home sections (5),
// cancel/change rules and change requests (7), new-order alerts (9), newest
// orders first (12), reassigning a rider (14) and the delivery pin at
// checkout (17). Image storage (2) is checked on the backend.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/models/product.dart';
import 'package:grozo/models/user_model.dart';
import 'package:grozo/services/staff_alerts.dart';
import 'package:grozo/views/account/location_picker_view.dart';
import 'package:grozo/views/checkout/checkout_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/manager/edit_order_view.dart';
import 'package:grozo/views/manager/manager_dashboard.dart';
import 'package:grozo/views/orders/order_detail_view.dart';
import 'package:grozo/views/shell/main_shell.dart';
import 'phase1_requirements_test.dart' as h;

Map<String, dynamic> order({String status = 'Order Placed', Map<String, dynamic> extra = const {}}) => {
      'id': 1,
      'tracking_number': 'GRZ000001',
      'status': status,
      'customer_id': 15,
      'manager_id': 9,
      'created_at': '2026-10-09T08:00:00.000Z',
      'amount': 250,
      'subtotal': 200,
      'discount_total': 0,
      'delivery_charge': 50,
      'destination': 'House 1, Abbottabad',
      'items': [
        {'product_id': 10, 'name': 'Potato', 'qty': 2, 'price': 100, 'original_price': 100, 'line_total': 200}
      ],
      ...extra,
    };

Future<void> openOrder(WidgetTester tester, Map<String, dynamic> o) async {
  h.overrides['GET /orders/1'] = (200, o);
  await h.startApp(tester);
  MainShell.push(tester.element(find.byType(HomeView)), const OrderDetailView(orderId: 1));
  await h.settle(tester);
}

void main() {
  setUp(() {
    h.requests.clear();
    h.urls.clear();
    h.bodies.clear();
    h.overrides.clear();
    StaffAlerts.showPhoneNotifications = false;
    StaffAlerts.shown.clear();
    LocationPickerView.tileUrl = null;
  });

  group('5. Compact home sections', () {
    testWidgets('Market Shopping and Discounts are no taller than needed', (tester) async {
      await h.startApp(tester);
      final market = tester.getRect(find.text('Market Shopping').first);
      final deals = tester.getRect(find.text('Deals & Discounts'));
      expect(deals.top - market.top, lessThanOrEqualTo(135), reason: 'market panel ≤ 120 + gap');
      final dealsBox = find.ancestor(
          of: find.text('Deals & Discounts'),
          matching: find.byWidgetPredicate((w) => w is SizedBox && (w.height ?? 0) >= 150 && w.height! <= 170));
      expect(dealsBox, findsOneWidget, reason: 'discounts strip capped at 170');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });

  group('7. Cancelling and changing an order', () {
    testWidgets('after dispatch, Cancel is disabled and the reason is shown', (tester) async {
      await openOrder(
          tester,
          order(status: 'Dispatched', extra: {
            'can_cancel': false,
            'can_request_change': false,
            'cancel_block_reason': 'A rider has been assigned to this order, so it can no longer be cancelled or changed.',
          }));
      final cancel = find.widgetWithText(OutlinedButton, 'Cancel order');
      expect(cancel, findsOneWidget);
      expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
      expect(find.text('Cancel and changes are no longer available'), findsOneWidget);
      expect(find.textContaining('A rider has been assigned'), findsOneWidget);
      expect(find.text('Request change'), findsNothing);
      await h.stopApp(tester);
    });

    testWidgets('customer requests a change; it is shown as waiting', (tester) async {
      await openOrder(tester, order(extra: {'can_cancel': true, 'can_request_change': true}));
      h.overrides['POST /orders/1/change-request'] = (201, {'message': 'sent'});
      await tester.tap(find.text('Request change'));
      await h.settle(tester);

      // One more potato and a message.
      await tester.tap(find.byTooltip('More').last);
      final message = find.widgetWithText(TextField, 'e.g. please add 1 dozen eggs');
      await tester.scrollUntilVisible(message, 200, scrollable: find.byType(Scrollable).last);
      await tester.enterText(message, 'Please add one more');
      await h.settle(tester);
      h.overrides['GET /orders/1'] = (200, order(extra: {
        'can_cancel': true,
        'can_request_change': true,
        'has_pending_change': true,
        'change_request': {'id': 3, 'status': 'pending', 'message': 'Please add one more'},
      }));
      await tester.tap(find.text('Send request'));
      await h.settle(tester);

      final body = h.bodies['POST /orders/1/change-request']!.single;
      expect(body['items'], [
        {'productId': 10, 'qty': 3}
      ]);
      expect(body['message'], 'Please add one more');
      expect(find.text('Change requested – waiting for the store'), findsOneWidget);
      expect(find.text('Request change'), findsNothing, reason: 'one request at a time');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('manager opens the request pre-filled and saves it', (tester) async {
      h.overrides['GET /orders/1'] = (200, order(extra: {
        'can_request_change': true,
        'change_request': {
          'id': 3,
          'status': 'pending',
          'message': 'Add onion please',
          'items': [
            {'productId': 10, 'qty': 3},
            {'productId': 11, 'qty': 1}
          ],
        },
        'events': [
          {'event': 'change_requested', 'actor_name': 'Test Customer', 'created_at': '2026-10-09T08:05:00.000Z', 'details': {'message': 'Add onion please'}}
        ],
      }));
      h.overrides['GET /products/11'] = (200, {'id': 11, 'name': 'Onion', 'price': 60, 'is_available': 1});
      h.overrides['PUT /orders/1/items'] = (200, {'message': 'Order updated. New total Rs. 410.'});
      await h.startApp(tester, role: 'Manager', home: Scaffold(
        body: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const EditOrderView(orderId: 1))),
          child: const Text('open'))),
      ));
      await tester.tap(find.text('open'));
      await h.settle(tester);

      expect(find.text('“Add onion please”'), findsOneWidget);
      expect(find.textContaining('Onion'), findsWidgets, reason: 'requested product filled in');
      expect(find.textContaining('customer asked for a change'), findsOneWidget, reason: 'history shown');
      await tester.tap(find.textContaining('Save'));
      await h.settle(tester);
      final body = h.bodies['PUT /orders/1/items']!.single;
      expect(body['requestId'], 3);
      expect(body['items'], [
        {'productId': 10, 'qty': 3},
        {'productId': 11, 'qty': 1}
      ]);
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });

  group('9/12/14. Manager workspace', () {
    final manager = UserModel(id: 9, name: 'Mgr', email: 'm@x.pk', role: 'Manager');
    List<Map<String, dynamic>> workspace() => [
          {'id': 1, 'tracking_number': 'GRZ000001', 'status': 'Order Placed', 'created_at': '2026-10-09T07:00:00.000Z', 'items_json': '[]', 'pending_changes': 1},
          {'id': 2, 'tracking_number': 'GRZ000002', 'status': 'Dispatched', 'created_at': '2026-10-09T09:00:00.000Z', 'items_json': '[]', 'rider_name': 'Ali', 'delivery_agent_id': 20},
        ];

    Future<void> openWorkspace(WidgetTester tester) async {
      h.overrides['GET /orders/manager/9'] = (200, workspace());
      h.overrides['GET /admin'] = (200, [
        {'id': 20, 'name': 'Ali', 'role': 'Rider', 'mobile': '0300-1'},
        {'id': 21, 'name': 'Bilal', 'role': 'Rider', 'mobile': '0300-2'},
      ]);
      h.overrides['GET /admin/users'] = h.overrides['GET /admin']!;
      h.overrides['GET /orders/reports/9/manager'] = (200, {'count': 0, 'total': 0});
      await h.startApp(tester, role: 'Manager', home: ManagerDashboard(user: manager));
      await tester.tap(find.text('My Tasks'));
      await h.settle(tester);
    }

    testWidgets('newest order first, change request flagged', (tester) async {
      await openWorkspace(tester);
      final newer = tester.getRect(find.textContaining('GRZ000002'));
      final older = tester.getRect(find.textContaining('GRZ000001'));
      expect(newer.top, lessThan(older.top));
      expect(find.text('✏️ Change requested by customer'), findsOneWidget);
      expect(find.text('Review change request'), findsOneWidget);
      await h.stopApp(tester);
    });

    testWidgets('manager changes the rider of a dispatched order', (tester) async {
      await openWorkspace(tester);
      h.overrides['POST /orders/2/dispatch'] = (200, {'message': 'Order reassigned to Bilal.'});
      await tester.tap(find.text('Change rider'));
      await h.settle(tester);
      expect(find.text('Current rider: Ali'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<dynamic>).last);
      await h.settle(tester);
      await tester.tap(find.textContaining('Bilal').last);
      await h.settle(tester);
      await tester.tap(find.text('Reassign'));
      await h.settle(tester);
      expect(h.bodies['POST /orders/2/dispatch']!.single['riderId'], 21);
      expect(find.text('Rider changed.'), findsOneWidget);
      await h.stopApp(tester);
    });

    testWidgets('a new order alert is raised once and refreshes the lists', (tester) async {
      h.overrides['GET /me/notifications'] = (200, [
        {'id': 5, 'type': 'order', 'title': 'Old', 'read_at': null}
      ]);
      await openWorkspace(tester);
      expect(StaffAlerts.shown, isEmpty, reason: 'alerts from before are not replayed');

      final before = h.requests.where((r) => r == 'GET /orders/manager/9').length;
      h.overrides['GET /me/notifications'] = (200, [
        {'id': 6, 'type': 'order', 'title': 'New order GRZ000003', 'body': '2 items · Rs. 300', 'order_id': 3, 'read_at': null},
        {'id': 5, 'type': 'order', 'title': 'Old', 'read_at': null},
      ]);
      // The check runs on a timer: let it fire, then let the network calls finish.
      await tester.pump(StaffAlerts.interval);
      await h.settle(tester);
      expect(StaffAlerts.shown.map((n) => n['title']), ['New order GRZ000003']);
      expect(h.requests.where((r) => r == 'GET /orders/manager/9').length, greaterThan(before));
      await h.stopApp(tester);
    });
  });

  group('17. Delivery pin at checkout', () {
    testWidgets('pinned location is shown and can be adjusted before confirming', (tester) async {
      h.overrides['/branches'] = (200, h.twoBranches);
      h.overrides['GET /me/addresses'] = (200, [
        {'id': 7, 'label': 'Home', 'address_line': 'House 1', 'city': 'Abbottabad', 'latitude': '34.17', 'longitude': '73.22', 'is_default': 1}
      ]);
      h.overrides['/orders/quote'] = (200, {
        'lines': [], 'problems': [], 'subtotal': 0, 'discount_total': 0, 'delivery_charge': 50, 'total': 50
      });
      h.overrides['PUT /me/addresses/7'] = (200, {
        'id': 7, 'label': 'Home', 'address_line': 'House 1', 'city': 'Abbottabad', 'latitude': '34.17', 'longitude': '73.22'
      });
      final state = await h.startApp(tester);
      final products = (jsonDecode(File('test/fixtures/products.json').readAsStringSync()) as List)
          .map((p) => Product.fromJson(p))
          .toList();
      state.addToCart(products.firstWhere((p) => p.available));
      MainShell.push(tester.element(find.byType(HomeView)), const CheckoutView());
      await h.settle(tester);

      expect(find.text('Delivery point pinned on the map'), findsOneWidget);
      await tester.tap(find.text('Adjust pin'));
      await h.settle(tester);
      expect(find.byType(LocationPickerView), findsOneWidget);
      await tester.tap(find.text('Confirm this location'));
      await h.settle(tester);
      final body = h.bodies['PUT /me/addresses/7']!.single;
      expect(body['address_line'], 'House 1');
      expect(body['latitude'], closeTo(34.17, 0.001));
      expect(h.requests.where((r) => r == 'POST /orders/quote').length, greaterThan(1), reason: 'charges recalculated');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });
}
