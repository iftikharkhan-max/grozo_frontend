import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import '../cart/cart_view.dart';

/// Products of one category, or product search when [searchMode] is true.
class ProductListView extends StatefulWidget {
  final Category? category;
  final bool searchMode;
  const ProductListView({super.key, this.category, this.searchMode = false});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Product> _products = [];
  bool _loading = false;
  String? _errorCode;
  int _requestId = 0;

  /// Sub-category chosen from the tiles at the top; null shows everything
  /// in the main category.
  Category? _sub;

  @override
  void initState() {
    super.initState();
    if (!widget.searchMode) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final query = <String, String>{
      if (widget.category != null)
        'category': '${(_sub ?? widget.category!).id}',
      if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
    };
    if (widget.searchMode && query['q'] == null) {
      setState(() => _products = []);
      return;
    }
    final id = ++_requestId;
    setState(() => _loading = true);
    final res = await Api.get('/products', query: query);
    if (!mounted || id != _requestId) {
      return; // a newer search replaced this one
    }
    setState(() {
      _loading = false;
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) {
        _products = (res.data as List).map((p) => Product.fromJson(p)).toList();
      }
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final emoji =
        widget.category == null ? '🛒' : categoryEmoji(widget.category!.name);

    return Scaffold(
      appBar: AppBar(
        title: widget.searchMode
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: context.tr('search_hint'),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _load();
                    },
                  ),
                ),
              )
            : Text(widget.category?.displayName(lang) ?? ''),
        actions: [
          IconButton(
            tooltip: context.tr('cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartView())),
          ),
        ],
      ),
      body: (widget.category?.subcategories ?? const []).isEmpty
          ? _body(emoji)
          : Column(children: [
              _subcategoryBar(widget.category!.subcategories),
              Expanded(child: _body(emoji)),
            ]),
    );
  }

  /// "All" plus one tile per sub-category, each with its picture.
  Widget _subcategoryBar(List<Category> subs) {
    final lang = context.lang;
    Widget tile(Category? c) {
      final selected = c?.id == _sub?.id;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _sub = c;
              _products = [];
            });
            _load();
          },
          child: Container(
            width: 78,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: selected ? brandGreenLight : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? brandGreen : Colors.black12,
                  width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Expanded(
                child: c == null
                    ? const Icon(Icons.apps, color: brandPrimary, size: 28)
                    : NetImage(c.imageUrl,
                        fit: BoxFit.contain,
                        fallbackEmoji: categoryEmoji(c.name)),
              ),
              Text(c == null ? context.tr('all') : c.displayName(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    return Container(
      height: 86,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
      child: ListView(
          scrollDirection: Axis.horizontal,
          children: [tile(null), for (final c in subs) tile(c)]),
    );
  }

  Widget _body(String emoji) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCode != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(friendlyError(context, errorCode: _errorCode)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(context.tr('retry'))),
        ]),
      );
    }
    if (_products.isEmpty) {
      final text = widget.searchMode
          ? (_search.text.trim().isEmpty
              ? context.tr('search_hint')
              : 'No products found matching your search.')
          : context.tr('no_products_yet');
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(text, textAlign: TextAlign.center)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, mainAxisExtent: 240),
        itemCount: _products.length,
        itemBuilder: (ctx, i) => ProductCard(_products[i],
            width: double.infinity, fallbackEmoji: emoji),
      ),
    );
  }
}
