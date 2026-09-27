import 'package:flutter_test/flutter_test.dart';
import 'package:grozo/models/order.dart';

// Shapes taken from real orders on the live server (numbers stored as text by
// older app versions, new server-priced orders, and staff list rows).
void main() {
  test('legacy order with text quantities and prices', () {
    final o = Order.fromJson({
      'id': 12,
      'tracking_number': 'TRK123',
      'status': 'Order Placed',
      'amount': '830.00',
      'manager_id': null,
      'items': [
        {'qty': '2', 'name': 'Fresh Milk 1L', 'price': '250.00'},
        {'qty': 1, 'name': 'Bread', 'price': 120},
        {'name': 'No qty or price'},
      ],
    });
    expect(o.items.length, 3);
    expect(o.items[0].qty, 2);
    expect(o.items[0].lineTotal, 500);
    expect(o.items[2].qty, 1);
    expect(o.amount, 830);
    expect(o.step, OrderStep.placed);
  });

  test('new server-priced order', () {
    final o = Order.fromJson({
      'id': 300,
      'tracking_number': 'GRZ000300',
      'status': 'Dispatched',
      'amount': '450.00',
      'delivery_charge': '50.00',
      'manager_id': 2,
      'order_type': 'catalog',
      'items': [
        {'product_id': 6, 'name': 'Mangoes', 'qty': 2, 'price': 200, 'original_price': 250, 'line_total': 400, 'unit': '1 kg'},
      ],
      'rider_location': {'latitude': '34.2', 'longitude': 73.24, 'at': '2026-09-27T10:00:00Z'},
    });
    expect(o.items.single.productId, 6);
    expect(o.deliveryCharge, 50);
    expect(o.riderLat, 34.2);
    expect(o.step, OrderStep.riderAssigned);
    expect(o.totalPending, isFalse);
  });

  test('staff list rows keep items in items_json (decoded list or JSON text)', () {
    expect(Order.parseItemsJson([{'qty': '3', 'name': 'Eggs'}]).length, 1);
    expect(Order.parseItemsJson('[{"qty":"1","name":"Eggs"}]').length, 1);
    expect(Order.parseItemsJson('not json'), isEmpty);
    expect(Order.parseItemsJson(null), isEmpty);
  });
}
