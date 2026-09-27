import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../catalog/product_detail_view.dart';
import 'login_required.dart';

/// Network image with a placeholder and an emoji/icon fallback.
class NetImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String fallbackEmoji;

  const NetImage(this.path, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.fallbackEmoji = '🛒'});

  @override
  Widget build(BuildContext context) {
    final url = Api.imageUrl(path);
    final fallback = SizedBox(
      width: width,
      height: height,
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(fallbackEmoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width != null ? (width! * MediaQuery.devicePixelRatioOf(context)).round() : null,
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : SizedBox(width: width, height: height, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (ctx, err, stack) => fallback,
    );
  }
}

String money(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Price with the original price struck through when discounted.
class PriceText extends StatelessWidget {
  final Product product;
  final double fontSize;
  const PriceText(this.product, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text('Rs. ${money(product.finalPrice)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize, color: brandPrimary)),
        if (product.hasDiscount)
          Text('Rs. ${money(product.price)}',
              style: TextStyle(
                  fontSize: fontSize - 3, color: Colors.black45, decoration: TextDecoration.lineThrough)),
      ],
    );
  }
}

/// Add button that becomes a − qty + stepper once the item is in the cart.
class AddToCartControl extends StatelessWidget {
  final Product product;
  final bool compact;
  const AddToCartControl(this.product, {super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final qty = state.qtyInCart(product.id);

    if (!product.available) {
      return Text(context.tr('out_of_stock'),
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12));
    }

    if (qty == 0) {
      return SizedBox(
        height: compact ? 32 : 44,
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandGreen,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => addWithFeedback(context, product),
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.tr('add'), style: const TextStyle(fontSize: 13)),
        ),
      );
    }

    return Container(
      height: compact ? 32 : 44,
      decoration: BoxDecoration(color: brandGreenLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: brandGreen)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(icon: Icons.remove, label: 'Decrease quantity', onTap: () => state.setQty(product.id, qty - 1)),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          _StepButton(icon: Icons.add, label: 'Increase quantity', onTap: () => addWithFeedback(context, product, quiet: true)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 40, height: double.infinity, child: Icon(icon, size: 18, color: brandPrimary)),
        ),
      );
}

void addWithFeedback(BuildContext context, Product p, {bool quiet = false}) {
  final added = context.read<AppState>().addToCart(p);
  final messenger = ScaffoldMessenger.of(context);
  if (!added) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(context.tr('max_qty_reached'))));
  } else if (!quiet) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(context.tr('added_to_cart')), duration: const Duration(seconds: 1)));
  }
}

/// ♡ toggle. Asks the customer to log in first if needed.
class FavoriteButton extends StatelessWidget {
  final int productId;
  final Color idleColor;
  final double size;
  const FavoriteButton(this.productId, {super.key, this.idleColor = Colors.black45, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final fav = context.select<AppState, bool>((s) => s.isFavorite(productId));
    return IconButton(
      tooltip: context.tr(fav ? 'remove_favorite' : 'add_favorite'),
      visualDensity: VisualDensity.compact,
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.redAccent : idleColor, size: size),
      onPressed: () async {
        final state = context.read<AppState>();
        if (!state.isLoggedIn && !await openLogin(context)) return;
        final ok = await state.toggleFavorite(productId);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('favorite_failed'))));
        }
      },
    );
  }
}

void openProduct(BuildContext context, Product p) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailView(product: p)));

/// Compact product card used in horizontal strips and grids.
class ProductCard extends StatelessWidget {
  final Product product;
  final double width;
  final String fallbackEmoji;
  const ProductCard(this.product, {super.key, this.width = 140, this.fallbackEmoji = '🛒'});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => openProduct(context, product),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: NetImage(product.imageUrl, fit: BoxFit.contain, fallbackEmoji: fallbackEmoji),
                        ),
                      ),
                      if (product.hasDiscount)
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: brandAccent, borderRadius: BorderRadius.circular(6)),
                            child: Text('${product.discountPercent}% ${context.tr('off')}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      PositionedDirectional(
                        top: -8,
                        end: -8,
                        child: FavoriteButton(product.id, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(product.displayName(lang),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((product.unit ?? '').isNotEmpty)
                  Text(product.unit!, maxLines: 1, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                PriceText(product, fontSize: 13),
                const SizedBox(height: 6),
                AddToCartControl(product),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Emoji used when a category has no uploaded image yet.
String categoryEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('veg')) return '🥦';
  if (n.contains('fruit')) return '🍎';
  if (n.contains('dairy') || n.contains('egg')) return '🥛';
  if (n.contains('bak')) return '🍞';
  if (n.contains('bever') || n.contains('drink')) return '🥤';
  if (n.contains('baby')) return '🍼';
  if (n.contains('home')) return '🧴';
  if (n.contains('personal')) return '🧼';
  if (n.contains('grocer')) return '🛒';
  if (n.contains('meat') || n.contains('chicken')) return '🍗';
  return '🛍️';
}
