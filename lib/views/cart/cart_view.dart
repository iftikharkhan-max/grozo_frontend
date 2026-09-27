import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/login_required.dart';
import '../common/product_widgets.dart';
import '../checkout/checkout_view.dart';

/// Cart with quantity controls. The total shown here is an estimate from the
/// last known prices; checkout gets the confirmed total from the server.
class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = state.cartLines;
    final lang = context.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('cart')),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: Text(context.tr('clear_cart_q')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('clear'), style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (ok == true) state.clearCart();
              },
              child: Text(context.tr('clear'), style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: lines.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.black26),
                const SizedBox(height: 12),
                Text(context.tr('cart_empty')),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('start_shopping'))),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final l = lines[i];
                final p = l.product;
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      SizedBox(width: 64, height: 64, child: NetImage(p.imageUrl, fit: BoxFit.contain)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.displayName(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                          if ((p.unit ?? '').isNotEmpty) Text(p.unit!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          PriceText(p),
                          const SizedBox(height: 6),
                          SizedBox(width: 130, child: AddToCartControl(p)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        IconButton(
                          tooltip: context.tr('remove'),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => state.removeFromCart(p.id),
                        ),
                        Text('Rs. ${money(p.finalPrice * l.qty)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),
                );
              },
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(context.tr('items_total'), style: const TextStyle(fontSize: 16)),
                    Text('Rs. ${money(state.cartEstimate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPrimary)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(context.tr('delivery_added_at_checkout'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!state.isLoggedIn && !await openLogin(context)) return;
                        if (!context.mounted) return;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutView()));
                      },
                      child: Text(context.tr('proceed_checkout')),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
