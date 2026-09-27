import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';
import 'admin_form.dart';

/// All products (including unavailable ones) with search; tap to edit.
class ProductsAdminView extends StatefulWidget {
  const ProductsAdminView({super.key});

  @override
  State<ProductsAdminView> createState() => _ProductsAdminViewState();
}

class _ProductsAdminViewState extends State<ProductsAdminView> {
  List<Map<String, dynamic>>? _products;
  List<Category> _categories = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([Api.get('/products'), Api.get('/admin/categories')]);
    if (!mounted) return;
    setState(() {
      if (results[0].ok) _products = List<Map<String, dynamic>>.from(results[0].data);
      if (results[1].ok) _categories = (results[1].data as List).map((c) => Category.fromJson(c)).toList();
    });
    if (!results[0].ok && mounted) adminError(context, results[0]);
  }

  Future<void> _edit([Map<String, dynamic>? product]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductEditView(product: product, categories: _categories)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final f = _filter.toLowerCase();
    final list = (_products ?? []).where((p) => f.isEmpty || '${p['name']} ${p['name_ur'] ?? ''}'.toLowerCase().contains(f)).toList();
    final uncategorised = (_products ?? []).where((p) => p['category_id'] == null).length;

    return Scaffold(
      appBar: adminAppBar('Products'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: _products == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  if (uncategorised > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('$uncategorised product(s) have no category and will not appear in any category on the home page.',
                          style: TextStyle(color: Colors.orange.shade900)),
                    ),
                  for (final p in list) _tile(p),
                ],
              ),
            ),
    );
  }

  Widget _tile(Map<String, dynamic> p) {
    final cat = _categories.where((c) => c.id == p['category_id']).firstOrNull;
    final available = p['available'] == true;
    final details = [
      cat?.name ?? 'No category',
      if ((p['unit'] ?? '').toString().isNotEmpty) p['unit'],
      if (p['stock_qty'] != null) 'Stock: ${p['stock_qty']}',
    ].join(' • ');
    return ListTile(
      leading: SizedBox(width: 48, height: 48, child: NetImage(p['image_url'], fit: BoxFit.contain)),
      title: Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cat == null ? Colors.orange.shade800 : null)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Rs. ${numText(p['final_price'] ?? p['price'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (!available) const Text('Unavailable', style: TextStyle(color: Colors.red, fontSize: 11)),
        if (p['has_discount'] == true) Text('${p['discount_percent']}% off', style: const TextStyle(color: Colors.deepOrange, fontSize: 11)),
      ]),
      onTap: () => _edit(p),
    );
  }
}

class ProductEditView extends StatefulWidget {
  final Map<String, dynamic>? product;
  final List<Category> categories;
  const ProductEditView({super.key, this.product, required this.categories});

  @override
  State<ProductEditView> createState() => _ProductEditViewState();
}

class _ProductEditViewState extends State<ProductEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> p = widget.product ?? {};
  late final _name = TextEditingController(text: p['name'] ?? '');
  late final _nameUr = TextEditingController(text: p['name_ur'] ?? '');
  late final _unit = TextEditingController(text: p['unit'] ?? '');
  late final _price = TextEditingController(text: numText(p['price']));
  late final _discount = TextEditingController(text: numText(p['discount_price']));
  late final _stock = TextEditingController(text: numText(p['stock_qty']));
  late final _maxPerOrder = TextEditingController(text: numText(p['max_per_order']));
  late final _description = TextEditingController(text: p['description'] ?? '');
  late int? _categoryId = p['category_id'] as int?;
  late bool _isAvailable = p.isEmpty ? true : truthy(p['is_available']);
  late bool _isFeatured = truthy(p['is_featured']);
  late DateTime? _discountEnds = parseServerDate(p['discount_ends_at']);
  File? _image;
  bool _busy = false;

  bool get _isNew => widget.product == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final price = double.parse(_price.text.trim());
    final discount = double.tryParse(_discount.text.trim());
    if (discount != null && discount >= price) {
      adminToast(context, 'Discounted price must be lower than the normal price.');
      return;
    }
    setState(() => _busy = true);
    final fields = {
      'name': _name.text.trim(),
      'name_ur': blankToNull(_nameUr),
      'unit': blankToNull(_unit),
      'price': price,
      'discount_price': discount,
      'discount_ends_at': discount == null ? null : sqlDate(_discountEnds),
      'stock_qty': blankToNull(_stock),
      'max_per_order': blankToNull(_maxPerOrder),
      'description': blankToNull(_description),
      'category_id': _categoryId,
      'is_available': _isAvailable ? 1 : 0,
      'is_featured': _isFeatured ? 1 : 0,
    };
    final res = await Api.sendForm(_isNew ? 'POST' : 'PUT', _isNew ? '/products' : '/products/${p['id']}', fields, image: _image);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, _isNew ? 'Product added.' : 'Product saved.');
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar(_isNew ? 'Add product' : 'Edit product'),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminImagePicker(currentUrl: p['image_url'], picked: _image, onPicked: (f) => setState(() => _image = f)),
            adminText(_name, 'Name (English)', required: true, hint: 'e.g. Fresh Milk'),
            adminText(_nameUr, 'Name (Urdu)', hint: 'e.g. تازہ دودھ', direction: TextDirection.rtl),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int?>(
                initialValue: widget.categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— No category —')),
                  for (final c in widget.categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            adminText(_unit, 'Unit / size', hint: 'e.g. 1 kg, 1 litre, 1 dozen, 500 g'),
            adminSection('Price'),
            adminNumber(_price, 'Normal price (Rs.)', required: true),
            adminNumber(_discount, 'Discounted price (Rs.)', hint: 'Leave empty for no discount'),
            AdminDateField(label: 'Discount ends on (optional)', value: _discountEnds, onChanged: (d) => setState(() => _discountEnds = d)),
            adminSection('Stock'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for sale'),
              subtitle: const Text('Turn off to show the product as "Out of stock"'),
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            adminNumber(_stock, 'Quantity in stock', hint: 'Leave empty if you don\'t count stock', decimal: false),
            adminNumber(_maxPerOrder, 'Maximum per order', hint: 'Leave empty for no limit', decimal: false),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Featured'),
              subtitle: const Text('Shown first in "Our Fruits" / "Our Vegetables" on the home page'),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
            ),
            adminSection('Details'),
            adminText(_description, 'Description (optional)', maxLines: 4),
          ],
        ),
      ),
    );
  }
}
