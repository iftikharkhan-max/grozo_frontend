// Changes requested on 15 Oct 2026: product variations, Market Shopping
// sub-categories, Home layout, rider list order, Google Maps (with fallback),
// "Call about this order" and the delivery distance on the bill.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grozo/models/product.dart';
import 'package:grozo/views/account/location_picker_view.dart';
import 'package:grozo/views/admin/store/product_variants_admin.dart';
import 'package:grozo/views/admin/store/products_admin_view.dart';
import 'package:grozo/views/catalog/market_view.dart';
import 'package:grozo/views/catalog/product_detail_view.dart';
import 'package:grozo/views/catalog/product_list_view.dart';
import 'package:grozo/views/checkout/checkout_view.dart';
import 'package:grozo/views/home/home_view.dart';
import 'package:grozo/views/orders/order_detail_view.dart';
import 'package:grozo/views/rider/rider_dashboard.dart';
import 'package:grozo/views/shell/main_shell.dart';
import 'phase1_requirements_test.dart' as h;

/// Potato in three sizes, as the server sends it.
final potatoJson = {
  'id': 10,
  'name': 'Potato',
  'price': 100,
  'final_price': 100,
  'available': true,
  'image_url': '/images/1',
  'category_id': 5,
  'variants': [
    {'id': 100, 'product_id': 10, 'name': '1 kg', 'price': 120, 'final_price': 110, 'discount_percent': 8, 'available': true, 'stock_qty': 5, 'image_url': '/images/2'},
    {'id': 101, 'product_id': 10, 'name': '5 kg', 'price': 550, 'final_price': 550, 'available': true},
    {'id': 102, 'product_id': 10, 'name': '10 kg', 'price': 1000, 'final_price': 1000, 'available': false},
  ],
};

void main() {
  setUp(() {
    h.requests.clear();
    h.urls.clear();
    h.bodies.clear();
    h.forms.clear();
    h.overrides.clear();
    LocationPickerView.tileUrl = null;
  });

  group('Product variations', () {
    test('a variation is bought as its own item', () {
      final p = Product.fromJson(potatoJson);
      expect(p.hasVariants, isTrue);
      expect(p.priceFrom, 110);
      final kg = p.variants.first;
      expect(kg.variantId, 100);
      expect(kg.unit, '1 kg');
      expect(kg.finalPrice, 110);
      expect(kg.imageUrl, '/images/2');
      expect(p.variants[1].imageUrl, '/images/1', reason: 'falls back to the product picture');
      expect(kg.cartKey, '10:100');
      // Saved with the cart and read back.
      final again = Product.fromJson(p.toJson());
      expect(again.variants.map((v) => v.cartKey), ['10:100', '10:101', '10:102']);
      expect(Product.fromJson(kg.toJson()).cartKey, '10:100');
    });

    testWidgets('card shows "From" and Choose; each size is its own cart line; checkout sends it', (tester) async {
      h.overrides['GET /products'] = (200, [potatoJson]);
      final state = await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)),
          ProductListView(category: Category.fromJson({'id': 5, 'name': 'Root'})));
      await h.settle(tester);
      expect(find.text('From Rs. 110'), findsOneWidget);
      expect(state.addToCart(Product.fromJson(potatoJson)), isFalse, reason: 'must choose a size');

      await tester.tap(find.text('Choose'));
      await h.settle(tester);
      expect(find.text('Potato – Choose size'), findsOneWidget);
      final addButtons = find.descendant(of: find.byType(BottomSheet), matching: find.text('Add'));
      await tester.tap(addButtons.at(0)); // 1 kg
      await h.settle(tester);
      await tester.tap(addButtons.first); // 5 kg: the 1 kg Add became a stepper
      await h.settle(tester);
      expect(state.cartLines.map((l) => l.product.cartKey).toSet(), {'10:100', '10:101'});
      expect(state.cartEstimate, 110 + 550);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await h.settle(tester);
      expect(find.text('2 in cart'), findsOneWidget);

      h.overrides['/orders/quote'] = (200, {'lines': [], 'problems': [], 'subtotal': 0, 'discount_total': 0, 'delivery_charge': null, 'total': 0});
      MainShell.push(tester.element(find.byType(HomeView, skipOffstage: false)), const CheckoutView());
      await h.settle(tester);
      final items = h.bodies['POST /orders/quote']!.first['items'] as List;
      expect(items, containsAll([
        {'productId': 10, 'variantId': 100, 'qty': 1},
        {'productId': 10, 'variantId': 101, 'qty': 1},
      ]));
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });

    testWidgets('product page: picking a size changes price and stock', (tester) async {
      h.overrides['GET /products/10'] = (200, potatoJson);
      final state = await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)),
          ProductDetailView(product: Product.fromJson(potatoJson)));
      await h.settle(tester);
      expect(find.text('Choose size'), findsOneWidget);
      expect(find.text('Rs. 110'), findsOneWidget, reason: 'first available size');
      final page = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('In stock (5 left)'), 150, scrollable: page);
      expect(find.text('In stock (5 left)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('5 kg  •  Rs. 550'), -150, scrollable: page);
      await tester.tap(find.text('5 kg  •  Rs. 550'));
      await h.settle(tester);
      expect(find.text('Rs. 550'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('In stock'), 150, scrollable: page);
      expect(find.text('In stock'), findsOneWidget);
      await tester.tap(find.text('Add').last);
      await h.settle(tester);
      expect(state.cartLines.single.product.cartKey, '10:101');
      await h.stopApp(tester);
    });
  });

  group('Home', () {
    testWidgets('"Item not in the list" is the first Market Shopping tile; the bottom row is gone', (tester) async {
      await h.startApp(tester);
      final notInList = find.textContaining('Item not in the list');
      expect(notInList.hitTestable(), findsOneWidget, reason: 'visible without scrolling');
      expect(find.text('Quality Products'), findsNothing);
      expect(find.text('Cash on Delivery'), findsNothing);
      await tester.tap(notInList);
      await h.settle(tester);
      expect(find.byType(TextField), findsWidgets, reason: 'opens "add an item" form');
      await h.stopApp(tester);
    });
  });

  group('Market Shopping page', () {
    testWidgets('sub-categories are shown under their category and open it pre-selected', (tester) async {
      h.overrides['GET /categories'] = (200, [
        {
          'id': 3,
          'name': 'Dairy & Eggs',
          'display_group': 'market',
          'subcategories': [
            {'id': 31, 'name': 'Milk', 'parent_id': 3},
            {'id': 32, 'name': 'Eggs', 'parent_id': 3},
          ],
        }
      ]);
      h.overrides['GET /products'] = (200, []);
      await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)), const MarketView());
      await h.settle(tester);
      expect(find.text('Milk'), findsOneWidget);
      await tester.tap(find.text('Eggs'));
      await h.settle(tester);
      expect(find.byType(ProductListView), findsOneWidget);
      expect(h.urls.last.queryParameters['category'], '32');
      await h.stopApp(tester);
    });
  });

  group('Rider', () {
    test('newest assignment first', () {
      final sorted = newestFirstAssigned([
        {'id': 1, 'assigned_at': '2026-10-15T08:00:00Z'},
        {'id': 2, 'assigned_at': '2026-10-15T09:30:00Z'},
        {'id': 3, 'assigned_at': '2026-10-15T09:00:00Z'},
      ]);
      expect(sorted.map((o) => o['id']), [2, 3, 1]);
    });
  });

  group('Orders', () {
    testWidgets('"Call about this order" shows the order number; bill shows the distance', (tester) async {
      h.overrides['GET /orders/1'] = (200, {
        'id': 1,
        'tracking_number': 'GRZ000777',
        'status': 'Order Placed',
        'amount': 300,
        'delivery_charge': 100,
        'delivery_distance_km': 3.24,
        'branch_phone': '0300-1112223',
        'items': [],
      });
      await h.startApp(tester);
      MainShell.push(tester.element(find.byType(HomeView)), const OrderDetailView(orderId: 1));
      await h.settle(tester);
      await tester.scrollUntilVisible(find.text('Need help with this order?'), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Delivery charge (3.2 km)'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Call us'));
      await h.settle(tester);
      expect(find.text('Call about this order'), findsOneWidget);
      expect(find.text('GRZ000777'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await h.settle(tester);
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });

  group('Map', () {
    testWidgets('without a Google Maps key the picker still works (OpenStreetMap)', (tester) async {
      await h.startApp(tester);
      // Not awaited: push() only completes when the page is closed.
      Navigator.of(tester.element(find.byType(HomeView)), rootNavigator: true)
          .push(MaterialPageRoute(builder: (_) => const LocationPickerView()));
      await h.settle(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Confirm this location'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });

  group('Admin: sizes / weights', () {
    testWidgets('existing sizes are listed and a new one is saved with its price', (tester) async {
      h.overrides['GET /admin/products/10/variants'] = (200, [
        {'id': 100, 'name': '1 kg', 'price': 120, 'discount_price': 110, 'stock_qty': 5, 'is_available': 1},
      ]);
      h.overrides['POST /admin/products/10/variants'] = (201, {'id': 101});
      await h.startApp(tester, role: 'Admin', home: Scaffold(
        body: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => const ProductEditView(
                  product: {'id': 10, 'name': 'Potato', 'price': 100, 'is_available': 1}, categories: []))),
          child: const Text('open'))),
      ));
      await tester.tap(find.text('open'));
      await h.settle(tester);
      await tester.ensureVisible(find.text('Add size / weight'));
      await h.settle(tester);
      expect(find.text('1 kg'), findsOneWidget);
      expect(find.text('Rs. 120  •  now Rs. 110  •  Stock: 5'), findsOneWidget);

      await tester.tap(find.text('Add size / weight'));
      await h.settle(tester);
      expect(find.byType(VariantEditView), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Size / weight *'), '5 kg');
      await tester.enterText(find.widgetWithText(TextFormField, 'Price (Rs.) *'), '550');
      await tester.tap(find.text('SAVE'));
      await h.settle(tester);
      // Form fields arrive as: name="field" <blank line> value
      final form = h.forms['POST /admin/products/10/variants']!.replaceAll('\r', '');
      expect(form, contains('name="name"\n\n5 kg\n'));
      expect(form, contains('name="price"\n\n550.0\n'));
      expect(find.byType(VariantEditView), findsNothing, reason: 'saved and closed');
      expect(tester.takeException(), isNull);
      await h.stopApp(tester);
    });
  });
}
