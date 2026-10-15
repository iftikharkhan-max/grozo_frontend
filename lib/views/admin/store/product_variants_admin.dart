import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';
import 'admin_form.dart';

/// "Sizes / weights" on the product edit page: each variation (e.g. 500 g,
/// 1 kg, 5 kg) has its own price, discount, picture and stock. When a product
/// has visible variations, customers choose one of them.
class ProductVariationsSection extends StatefulWidget {
  final int productId;
  const ProductVariationsSection({super.key, required this.productId});

  @override
  State<ProductVariationsSection> createState() =>
      _ProductVariationsSectionState();
}

class _ProductVariationsSectionState extends State<ProductVariationsSection> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/admin/products/${widget.productId}/variants');
    if (!mounted) return;
    setState(() =>
        _items = res.ok ? List<Map<String, dynamic>>.from(res.data) : const []);
  }

  Future<void> _edit([Map<String, dynamic>? v]) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                VariantEditView(productId: widget.productId, variant: v)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text(
          'Optional. Add sizes or weights (e.g. 500 g, 1 kg, 5 kg), each with '
          'its own price and picture. Customers then choose one; the price '
          'above is no longer used.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      if (items == null)
        const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()))
      else
        for (final v in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
                width: 44,
                height: 44,
                child: NetImage(v['image_url'], fallbackEmoji: '📦')),
            title: Text(
                '${v['name']}${truthy(v['is_available']) ? '' : '  (hidden)'}'),
            subtitle: Text([
              'Rs. ${numText(v['price'])}',
              if (v['discount_price'] != null)
                'now Rs. ${numText(v['discount_price'])}',
              if (v['stock_qty'] != null) 'Stock: ${v['stock_qty']}',
            ].join('  •  ')),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _edit(v),
          ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add size / weight'),
        ),
      ),
    ]);
  }
}

class VariantEditView extends StatefulWidget {
  final int productId;
  final Map<String, dynamic>? variant;
  const VariantEditView({super.key, required this.productId, this.variant});

  @override
  State<VariantEditView> createState() => _VariantEditViewState();
}

class _VariantEditViewState extends State<VariantEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> v = widget.variant ?? {};
  late final _name = TextEditingController(text: v['name'] ?? '');
  late final _nameUr = TextEditingController(text: v['name_ur'] ?? '');
  late final _price = TextEditingController(text: numText(v['price']));
  late final _discount =
      TextEditingController(text: numText(v['discount_price']));
  late final _stock = TextEditingController(text: numText(v['stock_qty']));
  late final _order = TextEditingController(text: '${v['sort_order'] ?? 0}');
  late bool _available = v.isEmpty ? true : truthy(v['is_available']);
  File? _image;
  bool _busy = false;

  bool get _isNew => widget.variant == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final price = double.parse(_price.text.trim());
    final discount = double.tryParse(_discount.text.trim());
    if (discount != null && discount >= price) {
      adminToast(
          context, 'Discounted price must be lower than the normal price.');
      return;
    }
    setState(() => _busy = true);
    final res = await Api.sendForm(
      _isNew ? 'POST' : 'PUT',
      _isNew
          ? '/admin/products/${widget.productId}/variants'
          : '/admin/variants/${v['id']}',
      {
        'name': _name.text.trim(),
        'name_ur': blankToNull(_nameUr),
        'price': price,
        'discount_price': discount,
        'stock_qty': blankToNull(_stock),
        'sort_order': int.tryParse(_order.text.trim()) ?? 0,
        'is_available': _available ? 1 : 0,
      },
      image: _image,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
            'Delete the size "${v['name']}"? Past orders are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await Api.delete('/admin/variants/${v['id']}');
    if (!mounted) return;
    res.ok ? Navigator.pop(context, true) : adminError(context, res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar(_isNew ? 'Add size / weight' : 'Edit size / weight',
          actions: [
            if (!_isNew)
              IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : _delete),
          ]),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AdminImagePicker(
              currentUrl: v['image_url'],
              picked: _image,
              onPicked: (f) => setState(() => _image = f)),
          const Text('No picture: the product\'s picture is shown.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          adminText(_name, 'Size / weight',
              required: true, hint: 'e.g. 1 kg, 500 g, Large, 12 pcs'),
          adminText(_nameUr, 'Size / weight (Urdu)',
              direction: TextDirection.rtl),
          adminNumber(_price, 'Price (Rs.)', required: true),
          adminNumber(_discount, 'Discounted price (Rs.)',
              hint: 'Leave empty for no discount'),
          adminNumber(_stock, 'Quantity in stock',
              hint: 'Leave empty if you don\'t count stock', decimal: false),
          adminNumber(_order, 'Display order',
              hint: 'Smaller numbers appear first', decimal: false),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available for sale'),
            value: _available,
            onChanged: (x) => setState(() => _available = x),
          ),
        ]),
      ),
    );
  }
}
