import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import 'order_detail_view.dart';

/// "My Orders" footer tab: current and past orders.
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
      if (res.ok) _orders = (res.data as List).map((o) => Order.fromJson(Map<String, dynamic>.from(o))).toList();
    });
  }

  Future<void> _open(Order o) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailView(orderId: o.id)));
    _load(); // status may have changed (cancelled, received)
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.select<AppState, int>((s) => s.ordersRevision);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('my_orders')),
          automaticallyImplyLeading: false,
          actions: [IconButton(tooltip: context.tr('retry'), icon: const Icon(Icons.refresh), onPressed: _load)],
          bottom: TabBar(tabs: [Tab(text: context.tr('current_orders')), Tab(text: context.tr('past_orders'))]),
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
      _list(_orders!.where((o) => !o.isActive).toList(), context.tr('no_past_orders')),
    ]);
  }

  Widget _list(List<Order> orders, String emptyText) {
    return RefreshIndicator(
      onRefresh: _load,
      child: orders.isEmpty
          ? ListView(children: [const SizedBox(height: 140), Center(child: Text(emptyText))])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final o = orders[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () => _open(o),
                    title: Row(children: [
                      Expanded(child: Text('${context.tr('order')} ${o.number}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      StatusChip(o),
                    ]),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Expanded(child: Text(formatDateTime(o.createdAt))),
                        Text(o.isMarketRequest && o.totalPending ? context.tr('market_shopping') : 'Rs. ${money(o.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                      ]),
                    ),
                  ),
                );
              },
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
