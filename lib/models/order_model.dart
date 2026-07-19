import 'dart:convert';

class OrderModel {
  final int id;
  final String trackingNumber;
  final String status;
  final String? destination;
  final double amount;
  final String createdAt;
  final List<dynamic> items;

  OrderModel({
    required this.id, required this.trackingNumber, required this.status,
    this.destination, required this.amount, required this.createdAt, required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedItems = [];
    try {
      if (json['items_json'] != null) parsedItems = jsonDecode(json['items_json']);
    } catch (_) {}

    return OrderModel(
      id: json['id'] ?? 0,
      trackingNumber: json['tracking_number'] ?? 'PENDING',
      status: json['status'] ?? 'Order Placed',
      destination: json['destination'],
      amount: json['amount'] != null ? double.parse(json['amount'].toString()) : 0.0,
      createdAt: json['created_at'] ?? '',
      items: parsedItems,
    );
  }
}