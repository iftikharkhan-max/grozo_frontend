import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';

/// One product line while an order is being changed.
class EditLine {
  final int productId;
  final String name;
  final String? nameUr;
  final String? unit;

  /// Unit price shown to the person editing (the server works out the final bill).
  final double price;
  int qty;

  EditLine(
      {required this.productId,
      required this.name,
      this.nameUr,
      this.unit,
      required this.price,
      required this.qty});

  factory EditLine.fromOrderLine(OrderLine l) => EditLine(
      productId: l.productId!,
      name: l.name,
      nameUr: l.nameUr,
      unit: l.unit,
      price: l.price,
      qty: l.qty);

  factory EditLine.fromProduct(Product p) => EditLine(
      productId: p.id,
      name: p.name,
      nameUr: p.nameUr,
      unit: p.unit,
      price: p.finalPrice,
      qty: 1);

  String displayName(String lang) =>
      lang == 'ur' && (nameUr ?? '').isNotEmpty ? nameUr! : name;

  Map<String, dynamic> toJson() => {'productId': productId, 'qty': qty};
}

/// Lines of an order with − qty + steppers, remove, and "Add product".
/// Used by the customer's "Request change" and the manager's "Edit order".
class OrderItemsEditor extends StatelessWidget {
  final List<EditLine> lines;
  final VoidCallback onChanged;
  const OrderItemsEditor(
      {super.key, required this.lines, required this.onChanged});

  Future<void> _add(BuildContext context) async {
    final p = await Navigator.push<Product>(
        context, MaterialPageRoute(builder: (_) => const ProductPickerView()));
    if (p == null) return;
    final existing = lines.where((l) => l.productId == p.id).firstOrNull;
    if (existing != null) {
      existing.qty++;
    } else {
      lines.add(EditLine.fromProduct(p));
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (lines.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(context.tr('no_products_in_order'),
              style: const TextStyle(color: Colors.black54)),
        ),
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${l.displayName(lang)}${(l.unit ?? '').isNotEmpty ? ' (${l.unit})' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                        'Rs. ${money(l.price)} × ${l.qty} = Rs. ${money(l.price * l.qty)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black54)),
                  ]),
            ),
            IconButton(
              tooltip: context.tr('less'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                l.qty > 1 ? l.qty-- : lines.remove(l);
                onChanged();
              },
            ),
            Text('${l.qty}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              tooltip: context.tr('more_qty'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, color: brandGreen),
              onPressed: () {
                l.qty++;
                onChanged();
              },
            ),
            IconButton(
              tooltip: context.tr('remove'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                lines.remove(l);
                onChanged();
              },
            ),
          ]),
        ),
      const SizedBox(height: 4),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: Text(context.tr('add_product')),
        ),
      ),
    ]);
  }
}

/// Search the catalogue and pick one product.
class ProductPickerView extends StatefulWidget {
  const ProductPickerView({super.key});

  @override
  State<ProductPickerView> createState() => _ProductPickerViewState();
}

class _ProductPickerViewState extends State<ProductPickerView> {
  final _search = TextEditingController();
  List<Product>? _results;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final text = _search.text.trim();
    final res =
        await Api.get('/products', query: text.isEmpty ? null : {'q': text});
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = res.ok && res.data is List
          ? (res.data as List)
              .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('add_product'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.tr('search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward), onPressed: _run),
            ),
          ),
        ),
        Expanded(
          child: _loading && _results == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: [
                  for (final p in _results ?? <Product>[])
                    ListTile(
                      enabled: p.available,
                      leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: NetImage(p.imageUrl,
                              fallbackEmoji: categoryEmoji(p.name))),
                      title: Text(p.displayName(lang)),
                      subtitle: Text([
                        if ((p.unit ?? '').isNotEmpty) p.unit!,
                        'Rs. ${money(p.finalPrice)}',
                        if (!p.available) context.tr('out_of_stock'),
                      ].join('  •  ')),
                      trailing: const Icon(Icons.add_circle, color: brandGreen),
                      onTap: () => Navigator.pop(context, p),
                    ),
                  if ((_results ?? []).isEmpty && !_loading)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(context.tr('no_results')))),
                ]),
        ),
      ]),
    );
  }
}
