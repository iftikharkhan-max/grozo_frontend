import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:grozo/services/api.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';

class ProductService {
  static Future<List<dynamic>> fetchCatalog() async {
    try {
      final res = await Api.client.get(Uri.parse('${Config.baseUrl}/products'), headers: Api.authHeaders);
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
        request.headers.addAll(Api.authHeaders);
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
        var response = await Api.client.send(request);
        return response.statusCode == 201 || response.statusCode == 200;
      } else {
        final res = await Api.client.post(
          Uri.parse('${Config.baseUrl}/products'),
          headers: Api.jsonHeaders,
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
