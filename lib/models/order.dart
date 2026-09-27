import 'dart:convert';

double _d(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
double? _dn(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

class OrderLine {
  final int? productId;
  final String name;
  final String? nameUr;
  final String? unit;
  final String? imageUrl;
  final int qty;
  final double price; // unit price charged
  final double originalPrice;
  final double lineTotal;

  OrderLine.fromJson(Map<String, dynamic> j)
      : productId = j['product_id'] is int ? j['product_id'] : int.tryParse('${j['product_id']}'),
        name = (j['name'] ?? '').toString(),
        nameUr = j['name_ur']?.toString(),
        unit = j['unit']?.toString(),
        imageUrl = j['image_url']?.toString(),
        qty = (j['qty'] is int ? j['qty'] : int.tryParse('${j['qty']}')) ?? 1,
        price = _d(j['price']),
        originalPrice = j['original_price'] == null ? _d(j['price']) : _d(j['original_price']),
        lineTotal = j['line_total'] == null ? _d(j['price']) * ((j['qty'] as num?) ?? 1) : _d(j['line_total']);

  String displayName(String lang) => lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;
}

/// Customer-facing progress steps, derived from the staff workflow statuses.
enum OrderStep { placed, confirmed, riderAssigned, outForDelivery, delivered, completed, cancelled }

class Order {
  final int id;
  final String number;
  final String status;
  final DateTime? createdAt;
  final String orderType; // catalog | market_request
  final List<OrderLine> items;
  final String? requestText;
  final String? note;
  final double amount;
  final double? subtotal;
  final double? discountTotal;
  final double? deliveryCharge;
  final String paymentMethod;
  final String deliveryMethod;
  final String? destination;
  final String? contactName;
  final String? contactMobile;
  final bool claimedByManager;
  final String? riderName;
  final String? riderMobile;
  final double? riderLat;
  final double? riderLng;
  final DateTime? riderAt;

  Order.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        number = (j['tracking_number'] ?? '').toString(),
        status = (j['status'] ?? 'Order Placed').toString(),
        createdAt = DateTime.tryParse('${j['created_at']}')?.toLocal(),
        orderType = (j['order_type'] ?? 'catalog').toString(),
        items = (j['items'] as List? ?? []).whereType<Map>().map((l) => OrderLine.fromJson(Map<String, dynamic>.from(l))).toList(),
        requestText = j['request_text']?.toString(),
        note = j['customer_note']?.toString(),
        amount = _d(j['amount']),
        subtotal = _dn(j['subtotal']),
        discountTotal = _dn(j['discount_total']),
        deliveryCharge = _dn(j['delivery_charge']),
        paymentMethod = (j['payment_method'] ?? 'COD').toString(),
        deliveryMethod = (j['delivery_method'] ?? 'delivery').toString(),
        destination = j['destination']?.toString(),
        contactName = j['contact_name']?.toString(),
        contactMobile = j['contact_mobile']?.toString(),
        claimedByManager = j['manager_id'] != null,
        riderName = j['rider_name']?.toString(),
        riderMobile = j['rider_mobile']?.toString(),
        riderLat = _dn(j['rider_location']?['latitude']),
        riderLng = _dn(j['rider_location']?['longitude']),
        riderAt = DateTime.tryParse('${j['rider_location']?['at']}')?.toLocal();

  bool get isMarketRequest => orderType == 'market_request';

  /// Items as stored by the server (`items_json`). Old orders may use other shapes.
  static List<dynamic> parseItemsJson(dynamic itemsJson) {
    try {
      final decoded = itemsJson is String ? jsonDecode(itemsJson) : itemsJson;
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  OrderStep get step {
    switch (status.toLowerCase()) {
      case 'cancelled':
        return OrderStep.cancelled;
      case 'complete':
      case 'completed':
        return OrderStep.completed;
      case 'delivered':
        return OrderStep.delivered;
      case 'in the way':
        return OrderStep.outForDelivery;
      case 'dispatched':
        return OrderStep.riderAssigned;
      default:
        return claimedByManager ? OrderStep.confirmed : OrderStep.placed;
    }
  }

  bool get isActive => ![OrderStep.completed, OrderStep.cancelled].contains(step);
  bool get canCancel => status == 'Order Placed';
  bool get canMarkReceived => step == OrderStep.delivered;

  /// True when the final bill is confirmed on delivery (market request, or no map location for the charge).
  bool get totalPending => isMarketRequest && step.index < OrderStep.delivered.index || deliveryCharge == null && deliveryMethod == 'delivery' && step.index < OrderStep.delivered.index;
}
