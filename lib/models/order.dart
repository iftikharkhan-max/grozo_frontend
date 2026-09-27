import 'dart:convert';

// Server data is lenient: older orders store numbers as text ("2", "250.00"),
// so every numeric field is parsed rather than cast.
double _d(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
double? _dn(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _in(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt());

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
      : productId = _in(j['product_id']),
        name = (j['name'] ?? '').toString(),
        nameUr = j['name_ur']?.toString(),
        unit = j['unit']?.toString(),
        imageUrl = j['image_url']?.toString(),
        qty = _in(j['qty']) ?? 1,
        price = _d(j['price']),
        originalPrice = j['original_price'] == null ? _d(j['price']) : _d(j['original_price']),
        lineTotal = j['line_total'] == null ? _d(j['price']) * (_in(j['qty']) ?? 1) : _d(j['line_total']);

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
  final String orderSource; // app | phone
  final bool isFavorite;
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
      : id = _in(j['id']) ?? 0,
        number = (j['tracking_number'] ?? '').toString(),
        status = (j['status'] ?? 'Order Placed').toString(),
        createdAt = DateTime.tryParse('${j['created_at']}')?.toLocal(),
        orderType = (j['order_type'] ?? 'catalog').toString(),
        orderSource = (j['order_source'] ?? 'app').toString(),
        isFavorite = _in(j['is_favorite']) == 1,
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
  bool get isPhoneOrder => orderSource == 'phone';

  /// Extra market items (one per line) that are priced at delivery.
  List<String> get extraItemLines =>
      (requestText ?? '').split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

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
  bool get totalPending =>
      step.index < OrderStep.delivered.index &&
      (isMarketRequest || extraItemLines.isNotEmpty || (deliveryCharge == null && deliveryMethod == 'delivery'));
}
