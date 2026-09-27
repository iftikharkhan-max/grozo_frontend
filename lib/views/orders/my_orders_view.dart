import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import 'order_detail_view.dart';
import 'reorder.dart';

/// "My Orders" footer tab: Current, History and Favorites (starred orders that
/// can be ordered again with one tap).
class MyOrdersView extends StatefulWidget {
  const MyOrdersView({super.key});

  @override
  State<MyOrdersView> createState() => _MyOrdersViewState();
}

class _MyOrdersViewState extends State<MyOrdersView> {
  List<Order>? _orders;
  String? _errorCode;
  late int _loadedRevision;

  @override
  void initState() {
    super.initState();
    _loadedRevision = context.read<AppState>().ordersRevision;
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/orders/mine');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) {
        _orders = (res.data as List).whereType<Map>().map((o) => Order.fromJson(Map<String, dynamic>.from(o))).toList();
      }
    });
  }

  Future<void> _open(Order o) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailView(orderId: o.id)));
    _load(); // status may have changed (cancelled, received, starred)
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.select<AppState, int>((s) => s.ordersRevision);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('my_orders')),
          automaticallyImplyLeading: false,
          actions: [IconButton(tooltip: context.tr('retry'), icon: const Icon(Icons.refresh), onPressed: _load)],
          bottom: TabBar(tabs: [
            Tab(text: context.tr('current_orders')),
            Tab(text: context.tr('history')),
            Tab(text: context.tr('favorite_orders')),
          ]),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_orders == null && _errorCode != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(friendlyError(context, errorCode: _errorCode)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(context.tr('retry'))),
        ]),
      );
    }
    if (_orders == null) return const Center(child: CircularProgressIndicator());
    return TabBarView(children: [
      _list(_orders!.where((o) => o.isActive).toList(), context.tr('no_current_orders')),
      _list(_orders!.where((o) => !o.isActive).toList(), context.tr('no_past_orders'), showReorder: true),
      _list(_orders!.where((o) => o.isFavorite).toList(), context.tr('no_favorite_orders'), showReorder: true),
    ]);
  }

  Widget _list(List<Order> orders, String emptyText, {bool showReorder = false}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: orders.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(emptyText, textAlign: TextAlign.center)),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _card(orders[i], showReorder),
            ),
    );
  }

  Widget _card(Order o, bool showReorder) {
    final lang = context.lang;
    final summary = [
      ...o.items.take(3).map((l) => '${l.displayName(lang)} × ${l.qty}'),
      ...o.extraItemLines.take(2),
    ].join(', ');
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(o),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${context.tr('order')} ${o.number}', style: const TextStyle(fontWeight: FontWeight.bold))),
              StatusChip(o),
              IconButton(
                tooltip: context.tr(o.isFavorite ? 'unstar_order' : 'star_order'),
                visualDensity: VisualDensity.compact,
                icon: Icon(o.isFavorite ? Icons.star : Icons.star_border, color: o.isFavorite ? Colors.amber.shade700 : Colors.black38),
                onPressed: () => setOrderFavorite(context, o, !o.isFavorite),
              ),
            ]),
            if (summary.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
              ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(formatDateTime(o.createdAt), style: const TextStyle(fontSize: 12.5))),
              Text(o.isMarketRequest && o.totalPending ? context.tr('price_at_delivery') : 'Rs. ${money(o.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
              if (showReorder && (o.items.any((l) => l.productId != null) || o.extraItemLines.isNotEmpty))
                TextButton.icon(
                  onPressed: () => reorder(context, o),
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(context.tr('reorder')),
                )
              else
                const SizedBox(width: 10),
            ]),
          ]),
        ),
      ),
    );
  }
}

String stepLabel(BuildContext context, OrderStep s) => context.tr(const {
      OrderStep.placed: 'step_placed',
      OrderStep.confirmed: 'step_confirmed',
      OrderStep.riderAssigned: 'step_rider',
      OrderStep.outForDelivery: 'step_out',
      OrderStep.delivered: 'step_delivered',
      OrderStep.completed: 'step_completed',
      OrderStep.cancelled: 'step_cancelled',
    }[s]!);

class StatusChip extends StatelessWidget {
  final Order order;
  const StatusChip(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = order.step;
    final color = switch (s) {
      OrderStep.cancelled => Colors.red,
      OrderStep.completed || OrderStep.delivered => brandGreen,
      OrderStep.outForDelivery || OrderStep.riderAssigned => brandAccent,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(stepLabel(context, s), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }
}
