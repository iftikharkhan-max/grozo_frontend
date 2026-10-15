double _toDouble(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
int? _toIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : int.tryParse(v.toString()));

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

  /// Set when this is one variation of a product (e.g. Potato 1 kg); [unit]
  /// then holds the variation's name and the price, picture and stock are its own.
  final int? variantId;

  /// The product's variations (only on the product itself).
  final List<Product> variants;

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
    this.variantId,
    this.variants = const [],
  });

  bool get hasDiscount => finalPrice < price;

  /// The customer must pick a variation before adding it to the cart.
  bool get hasVariants => variantId == null && variants.isNotEmpty;

  /// Lowest price, for "from Rs. …" on products with variations.
  double get priceFrom => hasVariants
      ? variants.map((v) => v.finalPrice).reduce((a, b) => a < b ? a : b)
      : finalPrice;

  /// Cart key: "12", or "12:100" for variation 100 of product 12.
  String get cartKey => variantId == null ? '$id' : '$id:$variantId';

  /// One variation of this product as a buyable item.
  Product _variant(Map<String, dynamic> v) {
    final vPrice = _toDouble(v['price']);
    return Product(
      id: id,
      name: name,
      nameUr: nameUr,
      description: description,
      unit: (v['name'] ?? '').toString(),
      imageUrl: (v['image_url'] ?? '').toString().isNotEmpty
          ? v['image_url'].toString()
          : imageUrl,
      categoryId: categoryId,
      price: vPrice,
      finalPrice: v['final_price'] == null ? vPrice : _toDouble(v['final_price']),
      discountPercent: _toIntOrNull(v['discount_percent']) ?? 0,
      stockQty: _toIntOrNull(v['stock_qty']),
      maxPerOrder: maxPerOrder,
      available: v['available'] == null ? true : v['available'] == true,
      variantId: _toIntOrNull(v['id']),
    );
  }

  /// Most a customer can put in the cart right now (null = no limit).
  int? get maxQty {
    final limits = [stockQty, maxPerOrder].whereType<int>();
    return limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b);
  }

  String displayName(String lang) =>
      lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;

  factory Product.fromJson(Map<String, dynamic> j) {
    final price = _toDouble(j['price']);
    final base = Product(
      id: _toIntOrNull(j['id']) ?? 0,
      name: (j['name'] ?? '').toString(),
      nameUr: j['name_ur']?.toString(),
      description: j['description']?.toString(),
      unit: j['unit']?.toString(),
      imageUrl: j['image_url']?.toString(),
      categoryId: _toIntOrNull(j['category_id']),
      price: price,
      finalPrice:
          j['final_price'] == null ? price : _toDouble(j['final_price']),
      discountPercent: _toIntOrNull(j['discount_percent']) ?? 0,
      stockQty: _toIntOrNull(j['stock_qty']),
      maxPerOrder: _toIntOrNull(j['max_per_order']),
      available: j['available'] == null ? true : j['available'] == true,
      variantId: _toIntOrNull(j['variant_id']),
    );
    final raw = j['variants'];
    if (raw is! List || raw.isEmpty) return base;
    return Product(
      id: base.id,
      name: base.name,
      nameUr: base.nameUr,
      description: base.description,
      unit: base.unit,
      imageUrl: base.imageUrl,
      categoryId: base.categoryId,
      price: base.price,
      finalPrice: base.finalPrice,
      discountPercent: base.discountPercent,
      stockQty: base.stockQty,
      maxPerOrder: base.maxPerOrder,
      available: base.available,
      // Server rows carry product_id; rows saved with the cart are products.
      variants: [
        for (final v in raw.whereType<Map>())
          v.containsKey('product_id')
              ? base._variant(Map<String, dynamic>.from(v))
              : Product.fromJson(Map<String, dynamic>.from(v)),
      ],
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
        'variant_id': variantId,
        if (variants.isNotEmpty)
          'variants': [for (final v in variants) v.toJson()],
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

  /// Main category this one belongs to; null for a main category.
  final int? parentId;

  /// Visible sub-categories of a main category.
  final List<Category> subcategories;

  const Category({
    required this.id,
    required this.name,
    this.nameUr,
    this.subtitle,
    this.subtitleUr,
    this.imageUrl,
    this.group = 'market',
    this.products = const [],
    this.parentId,
    this.subcategories = const [],
  });

  String displayName(String lang) =>
      lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;
  String? displaySubtitle(String lang) =>
      lang == 'ur' && (subtitleUr ?? '').isNotEmpty ? subtitleUr : subtitle;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _toIntOrNull(j['id']) ?? 0,
        name: (j['name'] ?? '').toString(),
        nameUr: j['name_ur']?.toString(),
        subtitle: j['subtitle']?.toString(),
        subtitleUr: j['subtitle_ur']?.toString(),
        imageUrl: j['image_url']?.toString(),
        group: (j['display_group'] ?? 'market').toString(),
        products: (j['products'] as List? ?? [])
            .map((p) => Product.fromJson(p))
            .toList(),
        parentId: _toIntOrNull(j['parent_id']),
        subcategories: (j['subcategories'] as List? ?? [])
            .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );
}
