import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../common/product_widgets.dart';

class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late Product _p = widget.product;

  @override
  void initState() {
    super.initState();
    // Refresh price and availability; the card may have been stale.
    Api.get('/products/${_p.id}').then((res) {
      if (res.ok && mounted) setState(() => _p = Product.fromJson(res.data));
    });
  }


  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(_p.displayName(lang)),
        actions: [
          FavoriteButton(_p.id, idleColor: Colors.white, size: 26),
          IconButton(
            tooltip: context.tr('cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartView())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(color: Colors.white, child: NetImage(_p.imageUrl, fit: BoxFit.contain)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_p.displayName(lang), style: Theme.of(context).textTheme.headlineSmall),
          if ((_p.unit ?? '').isNotEmpty) Text(_p.unit!, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(children: [
            PriceText(_p, fontSize: 22),
            if (_p.hasDiscount) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: brandAccent, borderRadius: BorderRadius.circular(6)),
                child: Text('${_p.discountPercent}% ${context.tr('off')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(_p.available ? Icons.check_circle : Icons.cancel, color: _p.available ? brandGreen : Colors.red, size: 18),
            const SizedBox(width: 6),
            Text(
              !_p.available
                  ? context.tr('out_of_stock')
                  : _p.stockQty != null && _p.stockQty! <= 10
                      ? 'In stock (${_p.stockQty} left)'
                      : 'In stock',
              style: TextStyle(color: _p.available ? brandGreen : Colors.red, fontWeight: FontWeight.w600),
            ),
          ]),
          if ((_p.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_p.description!, style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AddToCartControl(_p, compact: false),
        ),
      ),
    );
  }
}
