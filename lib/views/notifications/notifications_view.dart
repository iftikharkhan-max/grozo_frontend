import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../catalog/product_list_view.dart';
import '../common/product_widgets.dart';
import '../orders/order_detail_view.dart';

/// In-app inbox: order updates and promotions. Opening it marks everything read.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  List<Map<String, dynamic>>? _items;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/me/notifications');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) _items = List<Map<String, dynamic>>.from(res.data);
    });
    if (res.ok && _items!.any((n) => n['read_at'] == null)) {
      await Api.post('/me/notifications/read');
      if (mounted) context.read<AppState>().refreshUnread();
    }
  }

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return context.tr('just_now');
    if (d.inMinutes < 60) return context.trf('minutes_ago', {'n': d.inMinutes});
    if (d.inHours < 24) return context.trf('hours_ago', {'n': d.inHours});
    return formatDateTime(t);
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final orderId = n['order_id'];
    final linkId = n['link_id'];
    if (orderId != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailView(orderId: orderId as int)));
    } else if (n['link_type'] == 'product' && linkId != null) {
      final res = await Api.get('/products/$linkId');
      if (res.ok && mounted) {
        openProduct(
            context, Product.fromJson(Map<String, dynamic>.from(res.data)));
      }
    } else if (n['link_type'] == 'category' && linkId != null) {
      final res = await Api.get('/categories');
      if (!res.ok || !mounted) return;
      final c = (res.data as List)
          .map((c) => Category.fromJson(c))
          .where((c) => c.id == linkId)
          .firstOrNull;
      if (c != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductListView(category: c)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notifications'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items == null && _errorCode != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(friendlyError(context, errorCode: _errorCode)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(context.tr('retry'))),
        ]),
      );
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.tr('no_notifications'),
                  textAlign: TextAlign.center)));
    }
    final ur = context.lang == 'ur';
    String? pick(Map n, String key) {
      final v = ur && (n['${key}_ur'] ?? '').toString().isNotEmpty
          ? n['${key}_ur']
          : n[key];
      return (v ?? '').toString().isEmpty ? null : v.toString();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final n = _items![i];
          final unread = n['read_at'] == null;
          final isPromo = n['type'] == 'promo';
          return ListTile(
            tileColor: unread ? brandGreenLight : null,
            leading: CircleAvatar(
              backgroundColor:
                  (isPromo ? brandAccent : brandGreen).withValues(alpha: 0.15),
              child: Icon(isPromo ? Icons.local_offer : Icons.receipt_long,
                  color: isPromo ? brandAccent : brandGreen),
            ),
            title: Text(pick(n, 'title') ?? '',
                style: TextStyle(
                    fontWeight: unread ? FontWeight.bold : FontWeight.w500)),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (pick(n, 'body') != null) Text(pick(n, 'body')!),
              Text(_ago(DateTime.tryParse('${n['created_at']}')?.toLocal()),
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ]),
            onTap: () => _open(n),
          );
        },
      ),
    );
  }
}
