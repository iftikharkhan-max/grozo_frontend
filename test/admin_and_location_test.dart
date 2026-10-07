// Fixes reported after phase 1: tapping an Admin account in Manage crashed,
// the Manage list looked static, and customers in another city could not set a
// delivery location away from where their phone is.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/views/account/addresses_view.dart';
import 'package:grozo/views/account/location_picker_view.dart';
import 'package:grozo/views/admin/add_user_view.dart';
import 'package:grozo/views/admin/store/categories_admin_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/shell/main_shell.dart';
import 'phase1_requirements_test.dart' as h;

final users = [
  {'id': 15, 'name': 'Me Admin', 'email': 'me@grozo.pk', 'role': 'Admin'},
  {'id': 16, 'name': 'Other Admin', 'email': 'm.ajmal@grozo.pk', 'role': 'Admin'},
  {'id': 20, 'name': 'Sara', 'email': 'sara@grozo.pk', 'role': 'Manager', 'mobile': '0300-1111111'},
  for (var i = 0; i < 30; i++) {'id': 100 + i, 'name': 'Customer $i', 'email': 'c$i@x.pk', 'role': 'Customer'},
];

void main() {
  setUp(() {
    h.requests.clear();
    h.bodies.clear();
    h.overrides.clear();
    h.overrides['GET /admin'] = (200, users);
  });

  Future<void> openManage(WidgetTester tester) async {
    await h.startApp(tester, home: const AddUserView(), role: 'Admin');
    await tester.tap(find.text('Manage'));
    await h.settle(tester);
  }

  group('Manage tab', () {
    testWidgets('tapping another Admin opens a read-only dialog instead of crashing', (tester) async {
      await openManage(tester);
      await tester.tap(find.text('Admins (2)'));
      await h.settle(tester);
      await tester.tap(find.text('Other Admin (Admin)'));
      await h.settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Admin accounts cannot be edited here. Only deactivation is permitted.'), findsOneWidget);
      expect(find.text('Update Profile'), findsNothing);
      expect(find.text('DEACTIVATE'), findsOneWidget);
      await h.stopApp(tester);
    });

    testWidgets('your own Admin account cannot be deactivated', (tester) async {
      await openManage(tester);
      await tester.tap(find.text('Me Admin (Admin)'));
      await h.settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('This is your own Admin account'), findsOneWidget);
      expect(find.text('DEACTIVATE'), findsNothing);
      await h.stopApp(tester);
    });

    testWidgets('long list scrolls, shows a scrollbar, and can be searched and filtered', (tester) async {
      await openManage(tester);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.text('All (33)'), findsOneWidget);
      expect(find.text('Customers (30)'), findsOneWidget);

      await tester.drag(find.text('Sara (Manager)'), const Offset(0, -600));
      await h.settle(tester);
      expect(find.text('Sara (Manager)'), findsNothing, reason: 'list scrolled');

      await tester.enterText(find.widgetWithText(TextField, 'Search name, email or mobile'), '0300-1111');
      await h.settle(tester);
      expect(find.text('Sara (Manager)'), findsOneWidget);
      expect(find.textContaining('Customer 1 '), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Search name, email or mobile'), '');
      await tester.tap(find.text('Managers (1)'));
      await h.settle(tester);
      expect(find.text('Sara (Manager)'), findsOneWidget);
      expect(find.text('Customer 0 (Customer)'), findsNothing);
      await h.stopApp(tester);
    });
  });

  group('Delivery location on the map', () {
    setUp(() => LocationPickerView.tileUrl = null);

    testWidgets('customer in another city searches the delivery place and saves it', (tester) async {
      h.overrides['GET /branches'] = (200, h.twoBranches);
      h.overrides['GET /delivery-charges'] = (200, [
        {'min_km': 0, 'max_km': 10, 'charge': 100}
      ]);
      h.overrides['GET /search'] = (200, [
        {'display_name': 'Jinnahabad, Abbottabad, Pakistan', 'lat': '34.1850', 'lon': '73.2300'}
      ]);
      h.overrides['GET /reverse'] = (200, {
        'address': {'road': 'Iqbal Road', 'suburb': 'Jinnahabad'}
      });
      h.overrides['POST /me/addresses'] = (201, {'id': 9});
      await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)), const AddressEditView());
      await h.settle(tester);

      expect(find.text('No map location – the delivery charge will be confirmed by the rider.'), findsOneWidget);
      await tester.tap(find.text('Choose location on map'));
      await h.settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(LocationPickerView), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Search area, street or landmark'), 'Jinnahabad');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await h.settle(tester);
      expect(h.requests, contains('GET /search'));
      // Close to Mandian Branch (inside the 10 km area).
      expect(find.textContaining('km from Mandian Branch'), findsOneWidget);

      await tester.tap(find.text('Confirm this location'));
      await h.settle(tester);
      expect(find.byType(LocationPickerView), findsNothing);
      expect(find.text('Iqbal Road, Jinnahabad'), findsOneWidget, reason: 'empty address line filled from the map');
      expect(find.text('Map location saved – delivery charge will be calculated automatically.'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await h.settle(tester);
      final body = h.bodies['POST /me/addresses']!.single;
      expect(body['latitude'], closeTo(34.185, 0.0001));
      expect(body['longitude'], closeTo(73.23, 0.0001));
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('a point far from every branch is flagged on the map', (tester) async {
      h.overrides['GET /branches'] = (200, h.twoBranches);
      h.overrides['GET /delivery-charges'] = (200, [
        {'min_km': 0, 'max_km': 10, 'charge': 100}
      ]);
      h.overrides['GET /search'] = (200, [
        {'display_name': 'Saddar, Karachi', 'lat': '24.8546', 'lon': '67.0207'}
      ]);
      await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)), const AddressEditView());
      await h.settle(tester);
      await tester.tap(find.text('Choose location on map'));
      await h.settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Search area, street or landmark'), 'Saddar Karachi');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await h.settle(tester);
      expect(find.textContaining('outside our delivery area'), findsOneWidget);
      await h.stopApp(tester);
    });

    test('nearest branch distance', () {
      final near = nearestBranch(h.twoBranches, 34.19, 73.23)!;
      expect(near.branch['name'], 'Mandian Branch');
      expect(near.km, lessThan(1));
    });
  });

  group('Deleting a category', () {
    const category = {'id': 7, 'name': 'Bakery', 'display_group': 'market', 'sort_order': 3, 'is_active': 1};

    Future<void> openEdit(WidgetTester tester) async {
      // Opened from a list page, as in the app, so it can close after deleting.
      await h.startApp(tester,
          role: 'Admin',
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const CategoryEditView(category: category))),
                child: const Text('open'),
              ),
            ),
          ));
      await tester.tap(find.text('open'));
      await h.settle(tester);
      await tester.tap(find.byTooltip('Delete category'));
      await h.settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await h.settle(tester);
    }

    testWidgets('an empty category is deleted', (tester) async {
      h.overrides['DELETE /admin/categories/7'] = (200, {'message': 'Category "Bakery" deleted.'});
      await openEdit(tester);
      expect(h.requests, contains('DELETE /admin/categories/7'));
      expect(find.text('Category "Bakery" deleted.'), findsOneWidget);
      expect(find.byType(CategoryEditView), findsNothing, reason: 'back on the list');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('a category with products offers Hide instead or Delete anyway', (tester) async {
      h.overrides['DELETE /admin/categories/7'] =
          (409, {'error': '"Bakery" still has 4 product(s).', 'code': 'category_has_products', 'product_count': 4});
      await openEdit(tester);
      expect(find.text('"Bakery" has 4 product(s)'), findsOneWidget);

      h.overrides['DELETE /admin/categories/7'] = (200, {'message': 'Category "Bakery" deleted.'});
      await tester.tap(find.text('Delete anyway'));
      await h.settle(tester);
      expect(h.urls.last.queryParameters['force'], '1');
      expect(find.text('Category "Bakery" deleted.'), findsOneWidget);
      await h.stopApp(tester);
    });

    testWidgets('Hide instead keeps the category but hides it', (tester) async {
      h.overrides['DELETE /admin/categories/7'] =
          (409, {'error': 'has products', 'code': 'category_has_products', 'product_count': 4});
      h.overrides['PUT /admin/categories/7'] = (200, {'message': 'Category updated.'});
      await openEdit(tester);
      await tester.tap(find.text('Hide instead'));
      await h.settle(tester);
      expect(h.requests.last, 'PUT /admin/categories/7');
      expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1, reason: 'not deleted');
      await h.stopApp(tester);
    });
  });
}
