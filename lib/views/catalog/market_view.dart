import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import 'product_list_view.dart';

/// Market Shopping: every market category with its items (managed by the admin
/// as products), plus "Item not in the list? Add it" for anything else.
class MarketView extends StatefulWidget {
  const MarketView({super.key});

  @override
  State<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends State<MarketView> {
  List<Category>? _categories;
  Map<int, List<Product>> _byCategory = {};
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([Api.get('/categories'), Api.get('/products')]);
    if (!mounted) return;
    setState(() {
      if (!r[0].ok || !r[1].ok) {
        _errorCode = r[0].errorCode ?? r[1].errorCode ?? 'generic';
        return;
      }
      _errorCode = null;
      _categories = (r[0].data as List)
          .map((c) => Category.fromJson(c))
          .where((c) => c.group == 'market')
          .toList();
      final products = (r[1].data as List).map((p) => Product.fromJson(p));
      _byCategory = {};
      for (final p in products) {
        if (p.categoryId != null) (_byCategory[p.categoryId!] ??= []).add(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('market_shopping'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_custom_item',
        backgroundColor: brandAccent,
        foregroundColor: Colors.white,
        onPressed: () => showAddCustomItem(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('not_in_list')),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_categories == null) {
      return Center(
        child: _errorCode == null
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(friendlyError(context, errorCode: _errorCode)),
                ElevatedButton(
                    onPressed: _load, child: Text(context.tr('retry'))),
              ]),
      );
    }
    final lang = context.lang;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: brandGreenLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(context.tr('market_shopping_sub')),
            ),
            for (final c in _categories!) ...[
              const SizedBox(height: 14),
              Row(children: [
                Text(categoryEmoji(c.name),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(c.displayName(lang),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: brandPrimary))),
                if ((_byCategory[c.id] ?? []).isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductListView(category: c))),
                    child: Text(context.tr('view_all')),
                  ),
              ]),
              if ((_byCategory[c.id] ?? []).isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.tr('no_products_yet'),
                      style: const TextStyle(color: Colors.black45)),
                )
              else
                SizedBox(
                  height: 216,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _byCategory[c.id]!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (ctx, i) => ProductCard(_byCategory[c.id]![i],
                        fallbackEmoji: categoryEmoji(c.name)),
                  ),
                ),
            ],
          ]),
    );
  }
}

/// Dialog to add a market item that isn't in the catalogue to the cart.
Future<void> showAddCustomItem(BuildContext context) async {
  final name = TextEditingController();
  var qty = 1;
  final added = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(context.tr('not_in_list')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: context.tr('custom_item_name'),
                hintText: 'e.g. Tapal Danedar 190g'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text(context.tr('quantity')),
            const Spacer(),
            IconButton(
                onPressed: qty > 1 ? () => setD(() => qty--) : null,
                icon: const Icon(Icons.remove_circle_outline)),
            Text('$qty',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: () => setD(() => qty++),
                icon: const Icon(Icons.add_circle_outline)),
          ]),
          Text(context.tr('price_at_delivery'),
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty),
              child: Text(context.tr('add'))),
        ],
      ),
    ),
  );
  if (added == true && context.mounted) {
    context.read<AppState>().addCustomItem(name.text.trim(), qty);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('custom_item_added'))));
  }
}
