import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../cart/cart_view.dart';

/// Puts an earlier order back in the cart with today's prices and stock, then
/// opens the cart. Extra market items come back as "not in the list" items.
Future<void> reorder(BuildContext context, Order o) async {
  final messenger = ScaffoldMessenger.of(context);
  final state = context.read<AppState>();
  final lang = context.lang;
  final ids = o.items.map((l) => l.productId).whereType<int>().toSet().toList();
  final results = await Future.wait(ids.map((id) => Api.get('/products/$id')));
  if (!context.mounted) return;

  var added = 0;
  final missing = <String>[];
  for (final l in o.items) {
    final i = ids.indexOf(l.productId ?? -1);
    final res = i >= 0 ? results[i] : null;
    if (res == null || !res.ok) {
      missing.add(l.displayName(lang));
      continue;
    }
    final p = Product.fromJson(Map<String, dynamic>.from(res.data));
    final qty = p.maxQty == null ? l.qty : l.qty.clamp(0, p.maxQty!);
    if (!p.available || qty == 0) {
      missing.add(p.displayName(lang));
      continue;
    }
    // Top the cart up to the ordered quantity (it may already hold some).
    final toAdd = qty - state.qtyInCart(p.id);
    if (toAdd > 0) state.addToCart(p, qty: toAdd);
    added++;
  }
  for (final line in o.extraItemLines) {
    // Lines were written as "name × qty"; older lists are free text.
    final m = RegExp(r'^(.*?)\s*[×x]\s*(\d+)$').firstMatch(line);
    state.addCustomItem(m?.group(1)?.trim().isNotEmpty == true ? m!.group(1)!.trim() : line, int.tryParse(m?.group(2) ?? '') ?? 1);
    added++;
  }

  messenger.showSnackBar(SnackBar(
    content: Text(missing.isNotEmpty
        ? context.trf('reorder_some_missing', {'names': missing.join(', ')})
        : context.trf('reorder_done', {'n': added})),
  ));
  if (added > 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const CartView()));
}

/// Stars / un-stars an order (Favorites tab in My Orders).
Future<bool> setOrderFavorite(BuildContext context, Order o, bool favorite) async {
  final res = await Api.put('/orders/${o.id}/favorite', {'favorite': favorite});
  if (res.ok && context.mounted) context.read<AppState>().ordersChanged();
  if (!res.ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(context, errorCode: res.errorCode))));
  }
  return res.ok;
}
