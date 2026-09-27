double _toDouble(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
int? _toIntOrNull(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));

class Product {
  final int id;
  final String name;
  final String? nameUr;
  final String? description;
  final String? unit;
  final String? imageUrl;
  final int? categoryId;
  final double price;
  final double finalPrice;
  final int discountPercent;
  final int? stockQty;
  final int? maxPerOrder;
  final bool available;

  const Product({
    required this.id,
    required this.name,
    this.nameUr,
    this.description,
    this.unit,
    this.imageUrl,
    this.categoryId,
    required this.price,
    required this.finalPrice,
    this.discountPercent = 0,
    this.stockQty,
    this.maxPerOrder,
    this.available = true,
  });

  bool get hasDiscount => finalPrice < price;

  /// Most a customer can put in the cart right now (null = no limit).
  int? get maxQty {
    final limits = [stockQty, maxPerOrder].whereType<int>();
    return limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b);
  }

  String displayName(String lang) => lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;

  factory Product.fromJson(Map<String, dynamic> j) {
    final price = _toDouble(j['price']);
    return Product(
      id: _toIntOrNull(j['id']) ?? 0,
      name: (j['name'] ?? '').toString(),
      nameUr: j['name_ur']?.toString(),
      description: j['description']?.toString(),
      unit: j['unit']?.toString(),
      imageUrl: j['image_url']?.toString(),
      categoryId: _toIntOrNull(j['category_id']),
      price: price,
      finalPrice: j['final_price'] == null ? price : _toDouble(j['final_price']),
      discountPercent: _toIntOrNull(j['discount_percent']) ?? 0,
      stockQty: _toIntOrNull(j['stock_qty']),
      maxPerOrder: _toIntOrNull(j['max_per_order']),
      available: j['available'] == null ? true : j['available'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_ur': nameUr,
        'description': description,
        'unit': unit,
        'image_url': imageUrl,
        'category_id': categoryId,
        'price': price,
        'final_price': finalPrice,
        'discount_percent': discountPercent,
        'stock_qty': stockQty,
        'max_per_order': maxPerOrder,
        'available': available,
      };
}

class Category {
  final int id;
  final String name;
  final String? nameUr;
  final String? subtitle;
  final String? subtitleUr;
  final String? imageUrl;
  final String group; // 'featured' | 'market'
  final List<Product> products;

  const Category({
    required this.id,
    required this.name,
    this.nameUr,
    this.subtitle,
    this.subtitleUr,
    this.imageUrl,
    this.group = 'market',
    this.products = const [],
  });

  String displayName(String lang) => lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;
  String? displaySubtitle(String lang) => lang == 'ur' && (subtitleUr ?? '').isNotEmpty ? subtitleUr : subtitle;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _toIntOrNull(j['id']) ?? 0,
        name: (j['name'] ?? '').toString(),
        nameUr: j['name_ur']?.toString(),
        subtitle: j['subtitle']?.toString(),
        subtitleUr: j['subtitle_ur']?.toString(),
        imageUrl: j['image_url']?.toString(),
        group: (j['display_group'] ?? 'market').toString(),
        products: (j['products'] as List? ?? []).map((p) => Product.fromJson(p)).toList(),
      );
}
