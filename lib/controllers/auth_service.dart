import 'dart:convert';
import 'package:http/http.dart' as http;
// Absolute package imports to resolve 'Config' and 'UserModel'
import 'package:grozo/utils/constants.dart';
import 'package:grozo/models/user_model.dart';

class AuthService {
  // Changed from 'static const' to 'static final' to support dynamic configurations safely
  static String get baseUrl => Config.baseUrl;

  static Future<UserModel?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
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
}