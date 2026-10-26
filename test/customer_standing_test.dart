// Problem customers (recorded by riders/managers, visible to managers) and the
// admin's loyalty deal (every N orders: free delivery or Rs. X off).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/models/product.dart';
import 'package:grozo/models/user_model.dart';
import 'package:grozo/services/staff_alerts.dart';
import 'package:grozo/views/admin/store/customer_rules_admin_view.dart';
import 'package:grozo/views/checkout/checkout_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/manager/manager_dashboard.dart';
import 'package:grozo/views/manager/phone_order_view.dart';
import 'package:grozo/views/rider/rider_dashboard.dart';
import 'package:grozo/views/shell/main_shell.dart';
import 'package:grozo/views/staff/customer_standing.dart';
import 'phase1_requirements_test.dart' as h;

final history = {
  'customer': {'id': 5, 'name': 'Bilal', 'mobile': '0300-5555555', 'email': 'b@x.pk', 'is_flagged': 0},
  'standing': {'incidents': 3, 'flagged': false, 'threshold': 2, 'problematic': true},
  'stats': {'orders': 7, 'delivered': 3, 'cancelled': 2, 'spent': 4200},
  'loyalty': {'enabled': true, 'every': 3, 'reward': 'free_delivery', 'amount': 0, 'done': 3, 'eligible': false, 'blocked_problematic': true},
  'recent_orders': [
    {'id': 9, 'tracking_number': 'GRZ000009', 'status': 'Cancelled', 'amount': 600, 'created_at': '2026-10-20T08:00:00Z'},
  ],
  'incidents': [
    {'id': 31, 'reason': 'no_answer', 'tracking_number': 'GRZ000009', 'reported_by_name': 'Ali (rider)', 'voided': 0, 'created_at': '2026-10-20T09:00:00Z'},
    {'id': 30, 'reason': 'refused', 'note': 'Said he never ordered', 'reported_by_name': 'Sara', 'voided': 0, 'created_at': '2026-10-12T09:00:00Z'},
  ],
};

void main() {
  setUp(() {
    h.requests.clear();
    h.urls.clear();
    h.bodies.clear();
    h.forms.clear();
    h.overrides.clear();
    StaffAlerts.showPhoneNotifications = false;
  });

  group('Manager & rider', () {
    final manager = UserModel(id: 9, name: 'Mgr', email: 'm@x.pk', role: 'Manager');
    final rider = UserModel(id: 20, name: 'Ali', email: 'a@x.pk', role: 'Rider');
    final order = {
      'id': 12, 'tracking_number': 'GRZ000012', 'status': 'Order Placed', 'customer_id': 5,
      'customer_name': 'Bilal', 'created_at': '2026-10-25T08:00:00Z', 'items_json': '[]',
      'customer_incidents': 3, 'customer_flagged': 0, 'customer_problematic': true,
    };

    testWidgets('workspace shows the warning; manager records a problem and opens the history', (tester) async {
      h.overrides['GET /orders/manager/9'] = (200, [order]);
      h.overrides['GET /orders/reports/9/manager'] = (200, {'count': 0, 'total': 0});
      h.overrides['POST /orders/12/incidents'] = (201, {'message': 'Recorded.'});
      h.overrides['GET /staff/customers/5/history'] = (200, history);
      await h.startApp(tester, role: 'Manager', home: ManagerDashboard(user: manager));
      await tester.tap(find.text('My Tasks'));
      await h.settle(tester);
      expect(find.text('⚠ Problematic customer · 3 problems'), findsOneWidget);

      await tester.ensureVisible(find.text('Report problem'));
      await tester.tap(find.text('Report problem'));
      await h.settle(tester);
      expect(find.text('Record'), findsOneWidget);
      await tester.tap(find.text('Did not answer the phone'));
      await h.settle(tester);
      await tester.tap(find.text('Record'));
      await h.settle(tester);
      expect(h.bodies['POST /orders/12/incidents']!.single['reason'], 'no_answer');

      await tester.ensureVisible(find.text('Customer history'));
      await tester.tap(find.text('Customer history'));
      await h.settle(tester);
      expect(find.byType(CustomerHistoryView), findsOneWidget);
      expect(find.text('7'), findsOneWidget, reason: 'orders');
      expect(find.textContaining('Problematic: 3 problems (limit 2)'), findsOneWidget);
      expect(find.text('Reward (free delivery) withheld: problematic customer'), findsOneWidget);
      expect(find.text('Did not answer the phone'), findsOneWidget);
      expect(find.textContaining('Said he never ordered'), findsOneWidget);
      expect(find.textContaining('GRZ000009  •  Cancelled'), findsOneWidget);

      // A wrong report can be removed.
      h.overrides['PUT /staff/incidents/31/void'] = (200, {'message': 'Removed. It no longer counts.'});
      await tester.tap(find.byTooltip('Remove (recorded by mistake)').first);
      await h.settle(tester);
      await tester.tap(find.text('Remove'));
      await h.settle(tester);
      expect(h.requests, contains('PUT /staff/incidents/31/void'));
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('rider can report a problem (no history button)', (tester) async {
      h.overrides['GET /orders/rider/20'] = (200, [
        {...order, 'status': 'Dispatched', 'delivery_agent_id': 20}
      ]);
      h.overrides['GET /orders/reports/20/rider'] = (200, {'count': 0, 'total': 0});
      h.overrides['POST /orders/12/incidents'] = (201, {'message': 'Recorded.'});
      await h.startApp(tester, role: 'Rider', home: RiderDashboard(user: rider));
      expect(find.text('⚠ Problematic customer · 3 problems'), findsOneWidget);
      expect(find.text('Customer history'), findsNothing);
      await tester.ensureVisible(find.text('Report problem'));
      await tester.tap(find.text('Report problem'));
      await h.settle(tester);
      await tester.tap(find.text('Not at the address'));
      await h.settle(tester);
      await tester.tap(find.text('Record'));
      await h.settle(tester);
      expect(h.bodies['POST /orders/12/incidents']!.single['reason'], 'not_home');
      await h.stopApp(tester);
    });

    testWidgets('phone order: caller search shows the warning, history and reward due', (tester) async {
      h.overrides['GET /staff/customers'] = (200, [
        {'id': 5, 'name': 'Bilal', 'mobile': '0300-5555555', 'order_count': 7, 'customer_incidents': 3, 'customer_problematic': true},
      ]);
      h.overrides['GET /staff/customers/5/history'] = (200, {
        ...history,
        'loyalty': {'enabled': true, 'every': 3, 'reward': 'free_delivery', 'done': 3, 'eligible': true},
      });
      await h.startApp(tester, role: 'Manager', home: const PhoneOrderView());
      await tester.enterText(find.widgetWithText(TextField, 'Find customer by name or phone'), 'Bil');
      await tester.pump(const Duration(milliseconds: 600));
      await h.settle(tester);
      expect(find.textContaining('7 orders'), findsOneWidget);
      expect(find.text('⚠ Problematic customer · 3 problems'), findsOneWidget);
      await tester.tap(find.text('Bilal'));
      await h.settle(tester);
      expect(find.text('⚠ Problematic customer · 3 problems'), findsOneWidget, reason: 'still shown after picking');
      expect(find.textContaining('Loyalty reward due: free delivery'), findsOneWidget);
      await tester.tap(find.text('View order history and problems'));
      await h.settle(tester);
      expect(find.byType(CustomerHistoryView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });

  group('Admin', () {
    testWidgets('admin sets the loyalty deal and the problem limit', (tester) async {
      h.overrides['GET /admin/customer-rules'] = (200, {
        'problem_threshold': '2', 'loyalty_enabled': '0', 'loyalty_every': '3', 'loyalty_reward': 'free_delivery', 'loyalty_amount': '0'
      });
      h.overrides['PUT /admin/customer-rules'] = (200, {'message': 'Saved.'});
      await h.startApp(tester, role: 'Admin', home: Scaffold(
        body: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CustomerRulesAdminView())),
          child: const Text('open'))),
      ));
      await tester.tap(find.text('open'));
      await h.settle(tester);
      await tester.tap(find.text('Reward regular customers'));
      await h.settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Completed orders needed *'), '4');
      await tester.enterText(find.widgetWithText(TextFormField, 'Problems before "Problematic" *'), '3');
      await h.settle(tester);
      expect(find.textContaining('After every 4 delivered orders'), findsOneWidget);
      await tester.tap(find.text('SAVE'));
      await h.settle(tester);
      final body = h.bodies['PUT /admin/customer-rules']!.single;
      expect(body['loyalty_enabled'], true);
      expect(body['loyalty_every'], '4');
      expect(body['loyalty_reward'], 'free_delivery');
      expect(body['problem_threshold'], '3');
      await h.stopApp(tester);
    });
  });

  group('Customer', () {
    Future<void> checkout(WidgetTester tester, Map<String, dynamic> loyalty, {num delivery = 0, num total = 200}) async {
      h.overrides['/branches'] = (200, [h.twoBranches.first]);
      h.overrides['GET /me/addresses'] = (200, [
        {'id': 7, 'address_line': 'House 1', 'latitude': '34.17', 'longitude': '73.22', 'is_default': 1}
      ]);
      h.overrides['/orders/quote'] = (200, {
        'lines': [], 'problems': [], 'subtotal': 200, 'discount_total': 0,
        'delivery_charge': delivery, 'total': total, 'loyalty': loyalty, 'loyalty_discount': 0,
      });
      final state = await h.startApp(tester);
      final products = (jsonDecode(File('test/fixtures/products.json').readAsStringSync()) as List)
          .map((p) => Product.fromJson(p)).toList();
      state.addToCart(products.firstWhere((p) => p.available && !p.hasVariants));
      MainShell.push(tester.element(find.byType(HomeView)), const CheckoutView());
      await h.settle(tester);
      await tester.scrollUntilVisible(find.text('Total payable'), 200,
          scrollable: find.descendant(of: find.byType(CheckoutView), matching: find.byType(Scrollable)).first);
    }

    testWidgets('reward due: free delivery shown on the bill', (tester) async {
      await checkout(tester, {'enabled': true, 'every': 3, 'reward': 'free_delivery', 'done': 3, 'eligible': true, 'applied': true, 'saving': 80});
      expect(find.text('Free'), findsOneWidget);
      expect(find.textContaining('Your loyalty reward – free delivery – is applied'), findsOneWidget);
      await h.stopApp(tester);
    });

    testWidgets('progress towards the next reward', (tester) async {
      await checkout(tester, {'enabled': true, 'every': 3, 'reward': 'free_delivery', 'done': 1, 'eligible': false, 'applied': false},
          delivery: 80, total: 280);
      expect(find.textContaining('1 of 3 orders done. 2 more delivered order(s)'), findsOneWidget);
      await h.stopApp(tester);
    });
  });
}
