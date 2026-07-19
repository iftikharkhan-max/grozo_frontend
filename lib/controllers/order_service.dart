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
    } catch (_) {
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
    } catch (_) {}
    return false;
  }

  static Future<List<dynamic>> fetchUsersByRole(String role) async {
    try {
      print("DEBUG - fetchUsersByRole started for role: '$role'");

      // 1. Try fetching from /admin/users endpoint
      try {
        print("DEBUG - Attempting step 1: GET ${Config.baseUrl}/admin/users");
        final adminRes = await http.get(Uri.parse('${Config.baseUrl}/admin/users'));
        print("DEBUG - Step 1 status: ${adminRes.statusCode}");
        if (adminRes.statusCode == 200) {
          final List<dynamic> allUsers = jsonDecode(adminRes.body);
          final filtered = allUsers.where((u) {
            final userRole = (u['role'] ?? u['Role'] ?? '').toString().toLowerCase().trim();
            return userRole == role.toLowerCase().trim();
          }).toList();
          print("DEBUG - Step 1 filtered users count: ${filtered.length}");
          if (filtered.isNotEmpty) return filtered;
        }
      } catch (e) {
        print("DEBUG - Step 1 failed with error: $e");
      }

      // 2. Try fetching from /auth/users endpoint
      try {
        print("DEBUG - Attempting step 2: GET ${Config.baseUrl}/auth/users");
        final response = await http.get(Uri.parse('${Config.baseUrl}/auth/users'));
        print("DEBUG - Step 2 status: ${response.statusCode}");
        if (response.statusCode == 200) {
          final List<dynamic> allUsers = jsonDecode(response.body);
          final filtered = allUsers.where((u) {
            final userRole = (u['role'] ?? u['Role'] ?? '').toString().toLowerCase().trim();
            return userRole == role.toLowerCase().trim();
          }).toList();
          print("DEBUG - Step 2 filtered users count: ${filtered.length}");
          if (filtered.isNotEmpty) return filtered;
        }
      } catch (e) {
        print("DEBUG - Step 2 failed with error: $e");
      }

    } catch (globalError) {
      print("DEBUG - Global fetchUsersByRole error: $globalError");
    }

    print("DEBUG - fetchUsersByRole failed to find any users for: '$role'");
    return [];
  }
}