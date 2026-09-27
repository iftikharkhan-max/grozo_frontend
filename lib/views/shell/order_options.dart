import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../cart/cart_view.dart';
import '../catalog/shop_view.dart';
import '../common/contact.dart';

/// "Order Now" is the entry point, not an ordering method: it asks how the
/// customer wants to order — online, by phone call or on WhatsApp.
void showOrderOptions(BuildContext context, {required void Function(Widget page) open}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      Widget option(IconData icon, Color color, String title, String sub, VoidCallback onTap) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(sub),
              trailing: Icon(Icons.chevron_right, textDirection: Directionality.of(context)),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
          );

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Asked in both languages, as in the approved design.
            Text(context.tr('how_to_order_en'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(context.tr('how_to_order_ur'), style: const TextStyle(fontSize: 17, color: brandPrimary), textDirection: TextDirection.rtl),
            const SizedBox(height: 10),
            option(Icons.shopping_cart_outlined, brandGreen, '🛒 ${context.tr('online_order')}', context.tr('online_order_sub'), () {
              final empty = context.read<AppState>().cartIsEmpty;
              open(empty ? const ShopView() : const CartView());
            }),
            option(Icons.call, Colors.blue, '📞 ${context.tr('call_order')}', context.tr('call_order_sub'), () => callToOrder(context)),
            option(Icons.chat, const Color(0xFF25D366), '🟢 ${context.tr('whatsapp_order')}', context.tr('whatsapp_order_sub'),
                () => whatsappToOrder(context)),
          ]),
        ),
      );
    },
  );
}
