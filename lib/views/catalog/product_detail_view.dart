import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../common/product_widgets.dart';
import '../shell/main_shell.dart';

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

  /// Chosen size/weight when the product has variations.
  Product? _choice;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    // Picture, price, stock and Add follow the chosen variation.
    final shown = _p.hasVariants
        ? (_p.variants
                .where((v) => v.variantId == _choice?.variantId)
                .firstOrNull ??
            _p.variants.firstWhere((v) => v.available,
                orElse: () => _p.variants.first))
        : _p;

    return HidesOrderNowButton(
        child: Scaffold(
      appBar: AppBar(
        title: Text(_p.displayName(lang)),
        actions: [
          FavoriteButton(_p.id, idleColor: brandPrimary, size: 26),
          IconButton(
            tooltip: context.tr('cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartView())),
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
              child: Container(
                  color: Colors.white,
                  child: NetImage(shown.imageUrl, fit: BoxFit.contain)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_p.displayName(lang),
              style: Theme.of(context).textTheme.headlineSmall),
          if (_p.hasVariants) ...[
            const SizedBox(height: 8),
            Text(context.tr('choose_option'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final v in _p.variants)
                ChoiceChip(
                  label: Text('${v.unit}  •  Rs. ${money(v.finalPrice)}'),
                  selected: v.variantId == shown.variantId,
                  onSelected:
                      v.available ? (_) => setState(() => _choice = v) : null,
                ),
            ]),
          ] else if ((_p.unit ?? '').isNotEmpty)
            Text(_p.unit!, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(children: [
            Flexible(child: PriceText(shown, fontSize: 22)),
            if (shown.hasDiscount) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: brandAccent, borderRadius: BorderRadius.circular(6)),
                child: Text('${shown.discountPercent}% ${context.tr('off')}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(shown.available ? Icons.check_circle : Icons.cancel,
                color: shown.available ? brandGreen : Colors.red, size: 18),
            const SizedBox(width: 6),
            Text(
              !shown.available
                  ? context.tr('out_of_stock')
                  : shown.stockQty != null && shown.stockQty! <= 10
                      ? 'In stock (${shown.stockQty} left)'
                      : 'In stock',
              style: TextStyle(
                  color: shown.available ? brandGreen : Colors.red,
                  fontWeight: FontWeight.w600),
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
          child: AddToCartControl(shown, compact: false),
        ),
      ),
    ));
  }
}
