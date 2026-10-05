// Manager and rider screens against realistic order data: older orders store
// quantities/prices as text, newer ones carry products, extra market items and
// phone orders. Everything goes through a fake server.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:grozo/models/user_model.dart';
import 'package:grozo/services/api.dart';
import 'package:grozo/state/app_state.dart';
import 'package:grozo/views/admin/add_user_view.dart';
import 'package:grozo/views/manager/manager_dashboard.dart';
import 'package:grozo/views/rider/rider_dashboard.dart';

Map<String, dynamic> legacyOrder(int id, String status, {int? manager, int? rider}) => {
      'id': id,
      'tracking_number': 'TRK$id',
      'customer_id': 15,
      'manager_id': manager,
      'delivery_agent_id': rider,
      'items_json': [
        {'qty': '2', 'name': 'Fresh Milk 1L', 'price': '250.00'},
        {'qty': 1, 'name': 'Whole Wheat Bread', 'price': 120},
      ],
      'status': status,
      'created_at': '2026-09-05T09:50:56.000Z',
      'assigned_at': '2026-09-05T10:00:00.000Z',
      'amount': '620.00',
      'destination': 'House 1, Jinnahabad',
      'customer_name': 'Ali',
      'customer_mobile': '0300-1234567',
      'order_type': 'catalog',
      'order_source': 'app',
      'rider_name': rider == null ? 'Unassigned' : 'Rider A',
    };

Map<String, dynamic> newOrder(int id, String status, {int? manager, int? rider, String source = 'app'}) => {
      'id': id,
      'tracking_number': 'GRZ000$id',
      'customer_id': 15,
      'manager_id': manager,
      'delivery_agent_id': rider,
      'items_json': [
        {'product_id': 6, 'name': 'Mangoes', 'unit': '1 kg', 'qty': 2, 'price': 200, 'original_price': 250, 'line_total': 400},
      ],
      'request_text': 'Tapal tea 190g × 1',
      'customer_note': 'Ring the bell',
      'status': status,
      'created_at': '2026-09-27T10:00:00.000Z',
      'amount': '500.00',
      'subtotal': '500.00',
      'discount_total': '100.00',
      'delivery_charge': '100.00',
      'destination': 'Mandian, Abbottabad',
      'customer_name': 'Sara',
      'customer_mobile': '0311-7654321',
      'contact_name': 'Sara',
      'address_latitude': '34.2',
      'address_longitude': '73.24',
      'order_type': 'catalog',
      'order_source': source,
      'rider_name': rider == null ? 'Unassigned' : 'Rider A',
    };

final requests = <String>[];

http.Client fakeServer() => MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      requests.add('${req.method} $path ${req.body}');
      const h = {'content-type': 'application/json; charset=utf-8'};
      http.Response ok(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: h);
      if (path == '/orders/pool') {
        return ok([legacyOrder(12, 'Order Placed'), newOrder(300, 'Order Placed'), newOrder(301, 'Order Placed', source: 'phone')]);
      }
      if (path.startsWith('/orders/manager/')) {
        return ok([legacyOrder(40, 'Order Placed', manager: 5), newOrder(41, 'Dispatched', manager: 5, rider: 3)]);
      }
      if (path.startsWith('/orders/rider/')) {
        return ok([legacyOrder(50, 'Dispatched', manager: 5, rider: 3), newOrder(51, 'In the way', manager: 5, rider: 3)]);
      }
      if (path.startsWith('/orders/reports/')) return ok({'count': 3, 'total': '1500.00'});
      if (path == '/admin') {
        return ok([
          {'id': 3, 'name': 'Rider A', 'role': 'Rider', 'mobile': '0311-0000000'},
          {'id': 15, 'name': 'Ali', 'role': 'Customer', 'mobile': '0300-1234567'},
        ]);
      }
      if (path == '/products') {
        return ok([
          {'id': 6, 'name': 'Mangoes', 'price': '250.00', 'final_price': 200, 'available': true, 'unit': '1 kg'},
        ]);
      }
      if (path == '/delivery-charges') return ok([{'min_km': '0.00', 'max_km': '2.00', 'charge': '50.00'}]);
      if (path == '/branches') return ok([{'id': 1, 'name': 'Mandian Road'}]);
      if (path == '/staff/customers') return ok([]);
      if (path == '/admin/summary') {
        return ok({'today_orders': 4, 'today_delivered_value': 1250.5, 'unclaimed_orders': 2, 'active_orders': 3,
          'low_stock': [{'id': 6, 'name': 'Mangoes', 'stock_qty': 2}]});
      }
      if (path == '/admin/orders') return ok([legacyOrder(12, 'Order Placed'), newOrder(301, 'Dispatched', manager: 5, rider: 3, source: 'phone')]);
      if (path == '/staff/phone-orders') {
        return http.Response(jsonEncode({'message': 'Phone order GRZ000999 created.'}), 201, headers: h);
      }
      return ok({'message': 'ok'}); // claim, dispatch, status updates
    });

/// Where layout errors happened (file:line), so failures name the widget.
final errorWhere = <String>[];

Future<void> pumpStaff(WidgetTester tester, Widget screen) async {
  errorWhere.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    errorWhere.addAll(RegExp(r'lib/[\w/%]+\.dart:\d+').allMatches(d.toString()).map((m) => m.group(0)!));
    previous?.call(d);
  };
  addTearDown(() => FlutterError.onError = previous);
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = const Size(393, 851) * 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  Api.client = fakeServer();
  Api.token = 'staff-token';
  requests.clear();
  await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AppState(), child: MaterialApp(home: screen)));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final manager = UserModel(id: 5, name: 'Manager M', email: 'm@x.com', role: 'Manager');
  final rider = UserModel(id: 3, name: 'Rider A', email: 'r@x.com', role: 'Rider');

  testWidgets('manager: pool, claim, dispatch, reports', (tester) async {
    await pumpStaff(tester, ManagerDashboard(user: manager));
    expect(tester.takeException(), isNull);

    // Pool lists legacy, new and phone orders.
    expect(find.textContaining('TRK12'), findsOneWidget);
    expect(find.textContaining('GRZ000300'), findsOneWidget);
    expect(find.textContaining('PHONE'), findsWidgets);

    // Order details (text quantities) open without errors.
    await tester.tap(find.textContaining('TRK12'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fresh Milk 1L'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Claim').first);
    await settle(tester);
    expect(requests.any((r) => r.startsWith('PUT /orders/12/claim')), isTrue);

    // My Tasks: assign a rider and dispatch.
    await tester.tap(find.text('My Tasks'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('TRK40'), findsOneWidget);
    expect(find.textContaining('Tapal tea'), findsOneWidget, reason: 'extra market items shown to the manager');
    await tester.tap(find.byType(DropdownButtonFormField<dynamic>).first);
    await settle(tester);
    await tester.tap(find.textContaining('Rider A').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'DISPATCH').first);
    await settle(tester);
    expect(requests.any((r) => r.startsWith('POST /orders/40/dispatch') && r.contains('"riderId":3')), isTrue);

    await tester.tap(find.text('Reports'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1500'), findsOneWidget);
  });

  testWidgets('manager: phone order for a new caller', (tester) async {
    await pumpStaff(tester, ManagerDashboard(user: manager));
    await tester.tap(find.byTooltip('New phone order'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Caller C');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile *'), '0311-2223334');
    await tester.enterText(find.widgetWithText(TextField, 'Delivery address *'), 'House 5, Jinnahabad');
    await tester.tap(find.text('Add products'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.tap(find.text('CREATE PHONE ORDER'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    final sent = requests.firstWhere((r) => r.startsWith('POST /staff/phone-orders'));
    expect(sent, contains('"mobile":"0311-2223334"'));
    expect(sent, contains('"productId":6'));
    expect(find.textContaining('TRK12'), findsOneWidget, reason: 'back on the manager dashboard');
  });

  testWidgets('rider: deliveries, start transit (location off), confirm delivery', (tester) async {
    await pumpStaff(tester, RiderDashboard(user: rider));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fresh Milk 1L'), findsOneWidget, reason: 'items of older orders (text quantities)');
    expect(find.textContaining('Tapal tea'), findsOneWidget, reason: 'extra market items to buy');

    await tester.tap(find.text('START TRANSIT'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(requests.any((r) => r.startsWith('PUT /orders/50/status') && r.contains('In the way')), isTrue);
    // No GPS in tests: the rider is told to turn location on.
    expect(find.textContaining('Turn on location'), findsOneWidget);

    // Order 51 has extra market items priced at delivery, so the rider must
    // enter the cash actually collected; confirming empty is refused.
    // Let the location message go away (as it does after a few seconds).
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    final deliveryList = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(find.text('CONFIRM DELIVERY'), 200, scrollable: deliveryList);
    await settle(tester);
    await tester.tap(find.text('CONFIRM DELIVERY'));
    await settle(tester);
    expect(find.textContaining('Enter the total cash collected'), findsOneWidget);
    expect(requests.any((r) => r.startsWith('PUT /orders/51/status') && r.contains('Delivered')), isFalse);

    await tester.enterText(find.widgetWithText(TextField, 'Final Cash Collected (PKR)'), '650');
    await tester.pump(const Duration(seconds: 6)); // prompt goes away
    await settle(tester);
    await tester.tap(find.text('CONFIRM DELIVERY'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      requests.any((r) => r.startsWith('PUT /orders/51/status') && r.contains('Delivered') && r.contains('"amount":650')),
      isTrue,
    );

    await tester.tap(find.text('My Reports'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin: orders, staff, manage and store tabs open', (tester) async {
    await pumpStaff(tester, const AddUserView());
    expect(tester.takeException(), isNull, reason: 'admin opens at $errorWhere');
    expect(find.text('Orders today'), findsOneWidget);
    expect(find.textContaining('Mangoes (2)'), findsOneWidget, reason: 'low-stock warning');
    for (final tab in ['Add Staff', 'Manage', 'Store', 'Orders']) {
      await tester.tap(find.text(tab).first);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'opening $tab at $errorWhere');
    }
    await tester.tap(find.textContaining('TRK12'));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'admin order page at $errorWhere');
    expect(find.text('Dispatch to rider'), findsOneWidget);
  });
}
