import '../utils/constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderService {
  static Future<bool> createOrder({
    required int customerId,
    required String address,
    required double amount,
    required List<dynamic> items,
    int? managerId, // Added optional managerId for phone orders
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${Config.baseUrl}/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerId': customerId,
          'managerId': managerId,
          'destination': address,
          'amount': amount,
          'items': items,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {}
    return false;
  }

  static Future<List<dynamic>> fetchOrdersByRole(String endpointSegment,
      int id) async {
    try {
      final res = await http.get(
          Uri.parse('${Config.baseUrl}/orders/$endpointSegment/$id'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> fetchGlobalPool() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/orders/pool'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  static Future<bool> claimOrder(int orderId, int managerId) async {
    final res = await http.put(
      Uri.parse('${Config.baseUrl}/orders/$orderId/claim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'managerId': managerId}),
    );
    return res.statusCode == 200;
  }

  static Future<bool> dispatchToRider(dynamic orderId, dynamic riderId) async {
    try {
      final res = await http.post(
        Uri.parse('${Config.baseUrl}/orders/$orderId/dispatch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'riderId': riderId}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateStatus(dynamic orderId, String status,
      {double? amount}) async {
    final res = await http.put(
      Uri.parse('${Config.baseUrl}/orders/$orderId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'amount': amount}),
    );
    return res.statusCode == 200;
  }

  static Future<bool> cancelOrder(dynamic orderId) async {
    try {
      final res = await http.delete(
        Uri.parse('${Config.baseUrl}/orders/$orderId'),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> editOrder({
    required dynamic orderId,
    required String address,
    required double amount,
    required List<dynamic> items,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('${Config.baseUrl}/orders/$orderId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'destination': address,
          'amount': amount,
          'items': items,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      // ignore error
    }
    return false;
  }

  static Future<List<dynamic>> fetchUsersByRole(String role) async {
    try {
      // 1. Try fetching from confirmed working /admin endpoint
      try {
        final res = await http.get(Uri.parse('${Config.baseUrl}/admin'));
        if (res.statusCode == 200) {
          final List<dynamic> users = jsonDecode(res.body);
          final filtered = users.where((u) {
            final userRole = (u['role'] ?? u['Role'] ?? '').toString().toLowerCase().trim();
            return userRole == role.toLowerCase().trim();
          }).toList();
          if (filtered.isNotEmpty) return filtered;
        }
      } catch (_) { }

      // 2. Try fetching from /users endpoint
      try {
        final res = await http.get(Uri.parse('${Config.baseUrl}/users?role=$role'));
        if (res.statusCode == 200) {
          final List<dynamic> users = jsonDecode(res.body);
          if (users.isNotEmpty) return users;
        }
      } catch (_) { }

      // 3. Try fetching from /admin/users endpoint
      try {
        final adminRes = await http.get(Uri.parse('${Config.baseUrl}/admin/users'));
        if (adminRes.statusCode == 200) {
          final List<dynamic> allUsers = jsonDecode(adminRes.body);
          final filtered = allUsers.where((u) {
            final userRole = (u['role'] ?? u['Role'] ?? '').toString().toLowerCase().trim();
            return userRole == role.toLowerCase().trim();
          }).toList();
          if (filtered.isNotEmpty) return filtered;
        }
      } catch (_) { }
    } catch (_) {
    }
    return [];
  }

  static Future<Map<String, dynamic>> fetchReports(int userId, String role) async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/orders/reports/$userId/$role'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {'count': 0, 'total': 0};
  }
}
