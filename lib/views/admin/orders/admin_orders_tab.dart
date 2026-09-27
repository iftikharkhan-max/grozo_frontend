import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/strings.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';
import '../../staff/order_info.dart';
import '../store/admin_form.dart';

const _filters = [
  ('active', 'Active'),
  ('Order Placed', 'Placed'),
  ('Dispatched', 'Rider assigned'),
  ('In the way', 'Out for delivery'),
  ('Delivered', 'Delivered'),
  ('Complete', 'Completed'),
  ('Cancelled', 'Cancelled'),
  ('all', 'All'),
];

/// Admin "Orders" tab: today's summary, low stock, and every order with search.
class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _orders;
  String _filter = 'active';
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Api.get('/admin/summary'),
      Api.get('/admin/orders', query: {'status': _filter, if (_search.text.trim().isNotEmpty) 'q': _search.text.trim()}),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0].ok) _summary = Map<String, dynamic>.from(results[0].data);
      if (results[1].ok) _orders = List<Map<String, dynamic>>.from(results[1].data);
    });
    if (!results[1].ok) adminError(context, results[1]);
  }

  Future<void> _open(Map<String, dynamic> o) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminOrderView(order: o)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_summary != null) _summaryCards(_summary!),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Order number, customer name, email or phone',
                isDense: true,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final (key, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == key,
                      onSelected: (_) {
                        setState(() => _filter = key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_orders == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_orders!.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No orders found.')))
          else
            for (final o in _orders!) _orderTile(o),
        ],
      ),
    );
  }

  Widget _summaryCards(Map<String, dynamic> s) {
    Widget card(String label, String value, IconData icon, Color color) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
          ),
        );
    final low = List<Map<String, dynamic>>.from(s['low_stock'] ?? []);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(children: [
        Row(children: [
          card('Orders today', '${s['today_orders']}', Icons.today, adminColor),
          card('Delivered today', 'Rs. ${money(s['today_delivered_value'] as num)}', Icons.payments_outlined, Colors.green),
        ]),
        Row(children: [
          card('Not yet claimed', '${s['unclaimed_orders']}', Icons.inbox_outlined, Colors.orange),
          card('In progress', '${s['active_orders']}', Icons.local_shipping_outlined, Colors.blue),
        ]),
        if (low.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.orange.shade800),
              title: const Text('Low stock'),
              subtitle: Text(low.map((p) => '${p['name']} (${p['stock_qty']})').join(', ')),
            ),
          ),
      ]),
    );
  }

  Widget _orderTile(Map<String, dynamic> o) {
    final status = '${o['status']}';
    final color = switch (status) {
      'Cancelled' => Colors.red,
      'Complete' || 'Delivered' => Colors.green,
      'Dispatched' || 'In the way' => Colors.deepOrange,
      _ => Colors.blueGrey,
    };
    final placed = DateTime.tryParse('${o['created_at']}')?.toLocal();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => _open(o),
        title: Row(children: [
          Expanded(
            child: Text('${o['tracking_number']}${o['order_type'] == 'market_request' ? '  •  MARKET' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        subtitle: Text(
          '${o['customer_name'] ?? ''}  •  ${formatDateTime(placed)}\n'
          'Rs. ${money(double.tryParse('${o['amount']}') ?? 0)}'
          '${o['manager_name'] != null ? '  •  Mgr: ${o['manager_name']}' : ''}'
          '${o['rider_name'] != null ? '  •  Rider: ${o['rider_name']}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// One order for the admin: full details plus rider assignment, status and cancel.
class AdminOrderView extends StatefulWidget {
  final Map<String, dynamic> order;
  const AdminOrderView({super.key, required this.order});

  @override
  State<AdminOrderView> createState() => _AdminOrderViewState();
}

class _AdminOrderViewState extends State<AdminOrderView> {
  late final Map<String, dynamic> o = widget.order;
  List<Map<String, dynamic>> _riders = [];
  int? _riderId;
  final _amount = TextEditingController();
  bool _busy = false;

  String get _status => '${o['status']}';

  @override
  void initState() {
    super.initState();
    _riderId = o['delivery_agent_id'] as int?;
    _amount.text = '${double.tryParse('${o['amount']}')?.round() ?? ''}';
    Api.get('/admin').then((res) {
      if (!mounted || !res.ok) return;
      setState(() => _riders = List<Map<String, dynamic>>.from(res.data).where((u) => u['role'] == 'Rider').toList());
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ApiResult> Function() action, String done) async {
    setState(() => _busy = true);
    final res = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, done);
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('Reserved stock is returned and the customer is notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) _run(() => Api.post('/admin/orders/${o['id']}/cancel'), 'Order cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final open = !['Complete', 'Cancelled'].contains(_status);
    return Scaffold(
      appBar: adminAppBar('${o['tracking_number']}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text('Placed: ${formatDateTime(DateTime.tryParse('${o['created_at']}')?.toLocal())}'),
        if (o['manager_name'] != null) Text('Manager: ${o['manager_name']}'),
        const Divider(height: 24),
        StaffOrderInfo(o),
        if (open) ...[
          const Divider(height: 32),
          if (['Order Placed', 'Dispatched'].contains(_status)) ...[
            adminSection(_status == 'Dispatched' ? 'Change rider' : 'Assign rider'),
            DropdownButtonFormField<int>(
              initialValue: _riders.any((r) => r['id'] == _riderId) ? _riderId : null,
              decoration: const InputDecoration(labelText: 'Rider'),
              items: [for (final r in _riders) DropdownMenuItem(value: r['id'] as int, child: Text('${r['name']} (${r['mobile'] ?? ''})'))],
              onChanged: (v) => setState(() => _riderId = v),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy || _riderId == null
                  ? null
                  : () => _run(() => Api.post('/orders/${o['id']}/dispatch', {'riderId': _riderId}), 'Rider assigned.'),
              child: const Text('Dispatch to rider'),
            ),
          ],
          if (_status == 'Dispatched')
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => Api.put('/orders/${o['id']}/status', {'status': 'In the way'}), 'Marked out for delivery.'),
              child: const Text('Mark out for delivery'),
            ),
          if (['Dispatched', 'In the way'].contains(_status)) ...[
            adminSection('Delivered'),
            adminNumber(_amount, 'Cash collected (Rs.)', required: true),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      final amount = double.tryParse(_amount.text.trim());
                      if (amount == null) return adminToast(context, 'Enter the cash collected.');
                      _run(() => Api.put('/orders/${o['id']}/status', {'status': 'Delivered', 'amount': amount}), 'Marked delivered.');
                    },
              child: const Text('Mark delivered'),
            ),
          ],
          if (_status == 'Delivered')
            ElevatedButton(
              onPressed: _busy ? null : () => _run(() => Api.put('/orders/${o['id']}/status', {'status': 'Complete'}), 'Order completed.'),
              child: const Text('Mark completed'),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _busy ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel order'),
          ),
        ],
      ]),
    );
  }
}
