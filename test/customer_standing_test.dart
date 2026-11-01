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
      await tester.scrollUntilVisible(find.textContaining('Said he never ordered'), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('Said he never ordered'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('GRZ000009  •  Cancelled'), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('GRZ000009  •  Cancelled'), findsOneWidget);

      // A wrong report can be removed.
      h.overrides['PUT /staff/incidents/31/void'] = (200, {'message': 'Removed. It no longer counts.'});
      await tester.scrollUntilVisible(find.byTooltip('Remove (recorded by mistake)').first, -200,
          scrollable: find.byType(Scrollable).last);
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

  group('Regular / new / blacklisted', () {
    final manager = UserModel(id: 9, name: 'Mgr', email: 'm@x.pk', role: 'Manager');
    Map<String, dynamic> row(int id, String name, Map<String, dynamic> extra) => {
          'id': id, 'tracking_number': 'GRZ0000$id', 'status': 'Order Placed', 'customer_id': id,
          'customer_name': name, 'created_at': '2026-10-25T08:00:00Z', 'items_json': '[]',
          'customer_incidents': 0, 'customer_problematic': false, ...extra,
        };

    testWidgets('incoming orders say who the customer is', (tester) async {
      h.overrides['GET /orders/pool'] = (200, [
        row(21, 'Asma', {'customer_label': 'regular', 'customer_delivered': 7}),
        row(22, 'Bano', {'customer_label': 'new', 'customer_delivered': 0}),
        row(23, 'Chand', {'customer_label': 'blacklisted', 'customer_blacklisted': true, 'customer_problematic': true, 'customer_incidents': 3}),
      ]);
      h.overrides['GET /orders/reports/9/manager'] = (200, {'count': 0, 'total': 0});
      await h.startApp(tester, role: 'Manager', home: ManagerDashboard(user: manager));
      final pool = find.byType(Scrollable).first;
      for (final text in ['★ Regular customer · 7 delivered', '🆕 New customer', '⛔ Blacklisted customer · 3 problems']) {
        await tester.scrollUntilVisible(find.text(text), 200, scrollable: pool);
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('history: blacklist for fraud, then remove once resolved', (tester) async {
      var blacklisted = false;
      Map<String, dynamic> data() => {
            ...history,
            'standing': {
              'incidents': 1, 'flagged': false, 'threshold': 2, 'problematic': blacklisted, 'blacklisted': blacklisted,
              'blacklist_reason': blacklisted ? 'Fake orders' : null,
              'blacklisted_at': blacklisted ? '2026-10-30T09:00:00Z' : null,
              'blacklist_threshold': 3, 'label': blacklisted ? 'blacklisted' : 'returning', 'delivered': 3,
            },
            'blacklist_log': [
              if (blacklisted) {'action': 'added', 'automatic': 0, 'reason': 'Fake orders', 'by_name': 'Mgr', 'created_at': '2026-10-30T09:00:00Z'},
            ],
          };
      h.overrides['GET /staff/customers/5/history'] = (200, data());
      h.overrides['PUT /staff/customers/5/blacklist'] = (200, {'message': 'Customer blacklisted.'});
      await h.startApp(tester, role: 'Manager', home: const CustomerHistoryView(customerId: 5));
      expect(find.text('Not blacklisted'), findsOneWidget);
      expect(find.text('Blacklisted automatically after 3 problems.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Blacklist'));
      await h.settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Fake orders');
      blacklisted = true;
      h.overrides['GET /staff/customers/5/history'] = (200, data());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Blacklist'));
      await h.settle(tester);
      expect(h.bodies['PUT /staff/customers/5/blacklist']!.single, {'blacklisted': true, 'reason': 'Fake orders'});
      expect(find.text('BLACKLISTED'), findsOneWidget);
      expect(find.text('Fake orders'), findsOneWidget);
      expect(find.textContaining('Blacklisted by Mgr: Fake orders'), findsOneWidget);

      // Matter resolved: removed, with a note.
      h.overrides['PUT /staff/customers/5/blacklist'] = (200, {'message': 'Removed from the blacklist.'});
      await tester.tap(find.text('Remove from blacklist'));
      await h.settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Paid for the order');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await h.settle(tester);
      expect(h.bodies['PUT /staff/customers/5/blacklist']!.last, {'blacklisted': false, 'reason': 'Paid for the order'});
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('blacklisted customers list', (tester) async {
      h.overrides['GET /staff/blacklist'] = (200, [
        {'id': 5, 'name': 'Bilal', 'mobile': '0300-5555555', 'blacklist_reason': 'Automatic: 3 problems recorded (limit 3).',
         'blacklisted_at': '2026-10-30T09:00:00Z', 'incidents': 3, 'order_count': 7},
      ]);
      h.overrides['GET /staff/customers/5/history'] = (200, history);
      await h.startApp(tester, role: 'Admin', home: const BlacklistView());
      expect(find.text('Bilal  •  0300-5555555'), findsOneWidget);
      expect(find.textContaining('Automatic: 3 problems'), findsOneWidget);
      await tester.tap(find.text('Bilal  •  0300-5555555'));
      await h.settle(tester);
      expect(find.byType(CustomerHistoryView), findsOneWidget);
      await h.stopApp(tester);
    });
  });

  group('Admin', () {
    testWidgets('admin sets the loyalty deal and the problem limit', (tester) async {
      h.overrides['GET /admin/customer-rules'] = (200, {
        'problem_threshold': '2', 'loyalty_enabled': '0', 'loyalty_every': '3', 'loyalty_reward': 'free_delivery', 'loyalty_amount': '0',
        'blacklist_threshold': '3', 'regular_after': '3',
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
      // Lower down the page: scroll to them first.
      for (final (label, value) in [('Problems before blacklisting *', '4'), ('Delivered orders for "Regular" *', '5')]) {
        final field = find.widgetWithText(TextFormField, label);
        await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
        await tester.enterText(field, value);
      }
      await h.settle(tester);
      await tester.tap(find.text('SAVE'));
      await h.settle(tester);
      final body = h.bodies['PUT /admin/customer-rules']!.single;
      expect(body['loyalty_enabled'], true);
      expect(body['loyalty_every'], '4');
      expect(body['loyalty_reward'], 'free_delivery');
      expect(body['problem_threshold'], '3');
      expect(body['blacklist_threshold'], '4');
      expect(body['regular_after'], '5');
      await h.stopApp(tester);
    });
  });

  group('Customer', () {
    Future<void> checkout(WidgetTester tester, Map<String, dynamic> loyalty,
        {num delivery = 0, num total = 200, List problems = const []}) async {
      h.overrides['/branches'] = (200, [h.twoBranches.first]);
      h.overrides['GET /me/addresses'] = (200, [
        {'id': 7, 'address_line': 'House 1', 'latitude': '34.17', 'longitude': '73.22', 'is_default': 1}
      ]);
      h.overrides['/orders/quote'] = (200, {
        'lines': [], 'problems': problems, 'subtotal': 200, 'discount_total': 0,
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

    testWidgets('blacklisted: told to call the branch; Confirm is off', (tester) async {
      await checkout(tester, {'enabled': false}, problems: [{'reason': 'blacklisted'}]);
      await tester.scrollUntilVisible(find.textContaining('Your account is on hold'), -200,
          scrollable: find.descendant(of: find.byType(CheckoutView), matching: find.byType(Scrollable)).first);
      expect(find.textContaining('Please call the branch to order.'), findsOneWidget);
      final confirm = tester.widget<ElevatedButton>(find.descendant(
          of: find.byType(CheckoutView), matching: find.byType(ElevatedButton)).last);
      expect(confirm.onPressed, isNull);
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
