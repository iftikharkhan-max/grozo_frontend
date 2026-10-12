// Categories with sub-categories: the admin creates them (with image and the
// same options as a category) and customers browse them inside the main category.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/models/product.dart';
import 'package:grozo/views/admin/store/categories_admin_view.dart';
import 'package:grozo/views/catalog/product_list_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/shell/main_shell.dart';
import 'phase1_requirements_test.dart' as h;

const adminCategories = [
  {'id': 1, 'name': 'Vegetables', 'display_group': 'featured', 'sort_order': 1, 'is_active': 1, 'parent_id': null},
  {'id': 5, 'name': 'Root Vegetables', 'display_group': 'featured', 'sort_order': 1, 'is_active': 1, 'parent_id': 1},
  {'id': 6, 'name': 'Leafy Vegetables', 'display_group': 'featured', 'sort_order': 2, 'is_active': 0, 'parent_id': 1},
  {'id': 2, 'name': 'Bakery', 'display_group': 'market', 'sort_order': 3, 'is_active': 1, 'parent_id': null},
];

void main() {
  setUp(() {
    h.requests.clear();
    h.urls.clear();
    h.bodies.clear();
    h.overrides.clear();
  });

  group('Admin', () {
    Future<void> openList(WidgetTester tester) async {
      h.overrides['GET /admin/categories'] = (200, adminCategories);
      await h.startApp(tester, role: 'Admin', home: const CategoriesAdminView());
    }

    testWidgets('sub-categories are listed under their main category', (tester) async {
      await openList(tester);
      expect(tester.takeException(), isNull);
      final main = tester.getRect(find.textContaining('Vegetables  ').first);
      final sub = tester.getRect(find.textContaining('↳ Root Vegetables'));
      final other = tester.getRect(find.textContaining('Bakery'));
      expect(sub.top, greaterThan(main.top));
      expect(sub.top, lessThan(other.top), reason: 'listed with its main category');
      expect(sub.left, greaterThan(main.left), reason: 'indented');
      expect(find.textContaining('Hidden'), findsOneWidget, reason: 'hidden sub-category is marked');
      await h.stopApp(tester);
    });

    testWidgets('Add sub-category saves it under the chosen main category', (tester) async {
      await openList(tester);
      h.overrides['POST /admin/categories'] = (201, {'id': 9});
      await tester.tap(find.byTooltip('Add sub-category').first);
      await h.settle(tester);
      expect(find.text('Add sub-category'), findsOneWidget);
      expect(find.text('Sub-category of Vegetables'), findsOneWidget);
      // Same options as a category (names, image, order, visible) – except the
      // home-page placement, which follows the main category.
      expect(find.text('Where it appears'), findsNothing);
      expect(find.text('Visible in the app'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name (English) *'), 'Other Vegetables');
      await tester.tap(find.text('SAVE'));
      await h.settle(tester);
      expect(h.requests, contains('POST /admin/categories'));
      // Form fields arrive as: name="field" <blank line> value
      final form = h.forms['POST /admin/categories']!.replaceAll('\r', '');
      expect(form, contains('name="parent_id"\n\n1\n'), reason: 'saved under Vegetables (id 1)');
      expect(form, contains('name="name"\n\nOther Vegetables\n'));
      expect(find.byType(CategoryEditView), findsNothing, reason: 'saved and closed');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('a category that has sub-categories stays a main category', (tester) async {
      await openList(tester);
      await tester.tap(find.textContaining('Vegetables  ').first);
      await h.settle(tester);
      expect(find.text('Has sub-categories, so it stays a main category.'), findsOneWidget);
      expect(find.text('Where it appears'), findsOneWidget);
      await h.stopApp(tester);
    });
  });

  group('Customer', () {
    testWidgets('a main category shows its sub-categories; tapping one filters the products', (tester) async {
      h.overrides['GET /products'] = (200, [
        {'id': 10, 'name': 'Potato', 'price': 100, 'category_id': 5, 'is_available': 1, 'available': true},
      ]);
      await h.startApp(tester);
      final vegetables = Category.fromJson({
        'id': 1,
        'name': 'Vegetables',
        'subcategories': [
          {'id': 5, 'name': 'Root Vegetables', 'parent_id': 1},
          {'id': 7, 'name': 'Other Vegetables', 'parent_id': 1},
        ],
      });
      MainShell.push(tester.element(find.byType(HomeView)), ProductListView(category: vegetables));
      await h.settle(tester);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Root Vegetables'), findsOneWidget);
      expect(find.text('Other Vegetables'), findsOneWidget);
      expect(h.urls.last.queryParameters['category'], '1', reason: 'everything in the main category first');

      await tester.tap(find.text('Root Vegetables'));
      await h.settle(tester);
      expect(h.urls.last.queryParameters['category'], '5');
      await tester.tap(find.text('All'));
      await h.settle(tester);
      expect(h.urls.last.queryParameters['category'], '1');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('a category without sub-categories looks as before', (tester) async {
      await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)),
          ProductListView(category: Category.fromJson({'id': 2, 'name': 'Bakery'})));
      await h.settle(tester);
      expect(find.text('All'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });
}
