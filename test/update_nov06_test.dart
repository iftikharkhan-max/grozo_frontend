// Changes requested in Nov 2026: a description for each partner, branch map
// location (needed for delivery charges), and partner items in the same order
// as groceries.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/services/staff_alerts.dart';
import 'package:grozo/views/account/location_picker_view.dart';
import 'package:grozo/views/admin/store/branch_admin_view.dart';
import 'package:grozo/views/admin/store/partners_admin_view.dart';
import 'phase1_requirements_test.dart' as h;

Widget opener(Widget page) => Scaffold(
      body: Builder(
          builder: (ctx) => TextButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
              child: const Text('open'))),
    );

void main() {
  setUp(() {
    h.requests.clear();
    h.urls.clear();
    h.bodies.clear();
    h.forms.clear();
    h.overrides.clear();
    StaffAlerts.showPhoneNotifications = false;
    LocationPickerView.tileUrl = null;
  });

  testWidgets('admin writes a description for a partner', (tester) async {
    h.overrides['PUT /admin/partners/3'] = (200, {'message': 'Partner updated.'});
    await h.startApp(tester, role: 'Admin', home: opener(const PartnerEditView(partner: {
      'id': 3, 'name': 'Faridullah Fish', 'kind': 'Fish', 'latitude': '34.2', 'longitude': '73.2',
      'is_active': 1, 'coming_soon': 0, 'product_count': 2,
    })));
    await tester.tap(find.text('open'));
    await h.settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'About the partner (English)'),
        'Fresh river fish every morning since 1985.');
    await tester.tap(find.text('SAVE'));
    await h.settle(tester);
    final form = h.forms['PUT /admin/partners/3']!.replaceAll('\r', '');
    expect(form, contains('name="description"\n\nFresh river fish every morning since 1985.'));
    expect(tester.takeException(), isNull);
    await h.stopApp(tester);
  });

  testWidgets('branches without a map location are flagged in the list', (tester) async {
    h.overrides['GET /admin/branches'] = (200, [
      {'id': 1, 'name': 'Supply Branch', 'latitude': '34.19', 'longitude': '73.23', 'is_active': 1},
      {'id': 2, 'name': 'Mandian Branch', 'latitude': null, 'longitude': null, 'is_active': 1},
    ]);
    await h.startApp(tester, role: 'Admin', home: opener(const BranchesAdminView()));
    await tester.tap(find.text('open'));
    await h.settle(tester);
    expect(find.textContaining('No map location'), findsOneWidget);
    await h.stopApp(tester);
  });

  testWidgets('branch: Pick on map, and a warning before saving without a location', (tester) async {
    h.overrides['PUT /admin/branches/2'] = (200, {'message': 'Branch updated.'});
    await h.startApp(tester, role: 'Admin', home: opener(const BranchAdminView(branch: {
      'id': 2, 'name': 'Mandian Branch', 'latitude': null, 'longitude': null, 'is_active': 1,
    })));
    await tester.tap(find.text('open'));
    await h.settle(tester);
    expect(find.text('Pick on map'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await h.settle(tester);
    expect(find.text('No map location'), findsOneWidget, reason: 'warned before saving');
    await tester.tap(find.text('Set location'));
    await h.settle(tester);
    expect(find.byType(LocationPickerView), findsOneWidget, reason: 'opens the map picker');
    expect(h.requests, isNot(contains('PUT /admin/branches/2')));
    expect(tester.takeException(), isNull);
    await h.stopApp(tester);
  });
}
