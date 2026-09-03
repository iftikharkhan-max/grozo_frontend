import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';

class ProductService {
  static Future<List<dynamic>> fetchCatalog() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/products'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createProduct({
    required String name,
    required double price,
    File? imageFile,
    String? imageUrl,
  }) async {
    try {
      if (imageFile != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Config.baseUrl}/products'),
        );
        request.fields['name'] = name;
        request.fields['price'] = price.toString();
        
        var stream = http.ByteStream(imageFile.openRead());
        var length = await imageFile.length();
        
        var multipartFile = http.MultipartFile(
          'image', // Standard field name for images
          stream,
          length,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );
        
        request.files.add(multipartFile);
        var response = await request.send();
        return response.statusCode == 201 || response.statusCode == 200;
      } else {
        final res = await http.post(
          Uri.parse('${Config.baseUrl}/products'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'price': price,
            'image_url': imageUrl,
          }),
        );
        return res.statusCode == 201 || res.statusCode == 200;
      }
    } catch (e) {
      return false;
    }
  }
}
