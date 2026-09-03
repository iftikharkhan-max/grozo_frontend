import 'dart:convert';
import 'package:http/http.dart' as http;
// Absolute package imports to resolve 'Config' and 'UserModel'
import 'package:grozo/utils/constants.dart';
import 'package:grozo/models/user_model.dart';

class AuthService {
  // Changed from 'static const' to 'static final' to support dynamic configurations safely
  static String get baseUrl => Config.baseUrl;

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': UserModel.fromJson(data)};
      } else if (response.statusCode == 403) {
        return {'success': false, 'error': 'inactive', 'message': data['message'] ?? 'Account inactive.'};
      } else {
        return {'success': false, 'error': 'failed', 'message': data['error'] ?? 'Login failed.'};
      }
    } catch (e) {
      return {'success': false, 'error': 'network', 'message': 'Network error.'};
    }
  }

  // Add this method inside your existing class AuthService { ... }
  static Future<String?> adminAddStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    required String cnic,
    required String mobile,
    required String address, // <-- 1. Added address parameter here
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/admin/add-user'), // Hits your admin MVC route
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'cnic': cnic,
          'mobile': mobile,
          'address':address,
        }),
      );

      if (response.statusCode == 201) {
        return null; // Return null if successful (no error message)
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Failed to provision staff account.';
      }
    } catch (e) {
      return 'Network error connecting to backend engine.';
    }
  }

  static Future<bool> signupCustomer({
    required String name,
    required String email,
    required String password,
    required String mobile,
    required String cnic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'mobile': mobile,
          'cnic': cnic,
          'role': 'Customer',
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/admin/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // NEW: Soft Delete (Deactivate) User
  static Future<bool> deleteUser(int id) async {
    try {
      // 1. Notice we changed http.delete to http.put
      // 2. Notice we added /deactivate to the end of the URL
      final res = await http.put(
        Uri.parse('${Config.baseUrl}/admin/$id/deactivate'),
        headers: {'Content-Type': 'application/json'},
      );

      // If the backend returns a 200 OK, the deactivation was successful
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteAccount(int id) async {
    try {
      // Deactivating customer account
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/admin/$id/deactivate'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
