import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../common/product_widgets.dart';
import '../orders/order_editor.dart';

/// Manager: Edit order (spec 7.3). Opens with the customer's change request
/// applied (if there is one). Saving updates the order on the server, which
/// prices it, adjusts stock, keeps a history entry and tells the customer.
class EditOrderView extends StatefulWidget {
  final int orderId;
  const EditOrderView({super.key, required this.orderId});

  @override
  State<EditOrderView> createState() => _EditOrderViewState();
}

class _EditOrderViewState extends State<EditOrderView> {
  Order? _order;
  Map<String, dynamic>? _request; // pending change request
  List<Map<String, dynamic>> _events = [];
  final List<EditLine> _lines = [];
  final _extra = TextEditingController();
  final _note = TextEditingController();
  bool _applyAddress = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _extra.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load() async {
    final res = await Api.get('/orders/${widget.orderId}');
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _error = res.message ?? 'Could not load the order.');
      return;
    }
    final data = Map<String, dynamic>.from(res.data);
    final o = Order.fromJson(data);
    final req =
        o.changeRequest?['status'] == 'pending' ? o.changeRequest : null;

    // Start from the order, then apply what the customer asked for.
    final lines = <EditLine>[
      for (final l in o.items)
        if (l.productId != null) EditLine.fromOrderLine(l)
    ];
    final wanted = req?['items'];
    if (wanted is List) {
      final byId = {for (final l in lines) l.productId: l};
      final next = <EditLine>[];
      for (final w in wanted) {
        final id = (w['productId'] as num).toInt();
        final qty = (w['qty'] as num).toInt();
        var line = byId[id];
        if (line == null) {
          final p = await Api.get('/products/$id');
          if (!p.ok) continue;
          line = EditLine.fromProduct(
              Product.fromJson(Map<String, dynamic>.from(p.data)));
        }
        line.qty = qty;
        next.add(line);
      }
      lines
        ..clear()
        ..addAll(next);
    }
    if (!mounted) return;
    setState(() {
      _order = o;
      _request = req;
      _events = List<Map<String, dynamic>>.from(data['events'] ?? []);
      _lines
        ..clear()
        ..addAll(lines);
      _extra.text = o.requestText ?? '';
      _note.text = (req != null && req['note'] != null)
          ? '${req['note']}'
          : (o.note ?? '');
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty && _extra.text.trim().isEmpty) {
      return _toast(
          'An order needs at least one item. To drop everything, cancel the order.');
    }
    setState(() => _busy = true);
    final res = await Api.put('/orders/${widget.orderId}/items', {
      'items': [for (final l in _lines) l.toJson()],
      'requestText': _extra.text.trim(),
      'note': _note.text.trim(),
      if (_request != null && _request!['address_id'] != null && _applyAddress)
        'addressId': _request!['address_id'],
      if (_request != null) 'requestId': _request!['id'],
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      _toast('${res.data?['message'] ?? 'Order updated.'}');
      Navigator.pop(context, true);
    } else {
      _toast(res.message ?? 'Could not update the order.');
    }
  }

  Future<void> _reject() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline the request?'),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Reason for the customer (optional)',
              hintText: 'e.g. That item is out of stock today'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Decline', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await Api.post(
        '/orders/${widget.orderId}/change-request/${_request!['id']}/reject',
        {'reason': reason.text.trim()});
    reason.dispose();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(res.ok
        ? '${res.data?['message'] ?? 'Request declined.'}'
        : (res.message ?? 'Could not decline the request.'));
    if (res.ok) Navigator.pop(context, true);
  }

  double get _estimate => _lines.fold(0.0, (s, l) => s + l.price * l.qty);

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar:
          AppBar(title: Text(o == null ? 'Edit order' : 'Edit ${o.number}')),
      body: o == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : ListView(padding: const EdgeInsets.all(12), children: [
              if (!o.canRequestChange)
                _card(
                    'Editing closed',
                    Text(o.cancelBlockReason ??
                        'Orders can only be edited before they are dispatched.'),
                    color: Colors.grey.shade200),
              if (_request != null) _requestCard(_request!),
              _card(
                  'Products',
                  OrderItemsEditor(
                      lines: _lines, onChanged: () => setState(() {}))),
              _card(
                'Extra items (priced at delivery)',
                TextField(
                  controller: _extra,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      isDense: true, hintText: 'One item per line'),
                ),
              ),
              _card(
                'Note for rider',
                TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(isDense: true)),
              ),
              if (_events.isNotEmpty) _historyCard(),
            ]),
      bottomNavigationBar: o == null || !o.canRequestChange
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  if (_request != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red),
                          onPressed: _busy ? null : _reject,
                          child: const Text('Decline request'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: Text(
                            'Save  •  about Rs. ${money(_estimate)}${_extra.text.trim().isNotEmpty ? ' +' : ''}'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _card(String title, Widget child, {Color? color}) => Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget _requestCard(Map<String, dynamic> r) => _card(
        'Customer asked for a change',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ('${r['message'] ?? ''}'.isNotEmpty)
            Text('“${r['message']}”',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          if (r['items'] is List)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Their product changes are filled in below.'),
            ),
          if (r['address_id'] != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _applyAddress,
              onChanged: (v) => setState(() => _applyAddress = v ?? true),
              title: Text('Deliver to: ${r['new_address'] ?? 'new address'}'),
            ),
          if (r['note'] != null)
            const Text('Their new rider note is filled in below.'),
        ]),
        color: Colors.orange.shade50,
      );

  Widget _historyCard() => _card(
        'History',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in _events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(describeOrderEvent(e),
                  style: const TextStyle(fontSize: 12.5)),
            ),
        ]),
      );
}

/// One line of an order's history, e.g. "7/10 14:05 – Sara: rider changed
/// from Ali to Bilal".
String describeOrderEvent(Map<String, dynamic> e) {
  final d = e['details'] is Map ? e['details'] as Map : const {};
  final at = DateTime.tryParse('${e['created_at']}')?.toLocal();
  final when = at == null
      ? ''
      : '${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} – ';
  final who = e['actor_name'] ?? e['actor_role'] ?? 'System';
  final what = switch ('${e['event']}') {
    'rider_assigned' => 'rider ${d['to']?['name'] ?? ''} assigned',
    'rider_reassigned' =>
      'rider changed from ${d['from']?['name'] ?? '?'} to ${d['to']?['name'] ?? '?'}',
    'change_requested' =>
      'customer asked for a change${d['message'] != null ? ': “${d['message']}”' : ''}',
    'change_rejected' =>
      'change request declined${d['reason'] != null ? ': ${d['reason']}' : ''}',
    'edited' =>
      'order edited: ${(d['before']?['items'] as List?)?.join(', ') ?? ''} (Rs. ${d['before']?['total']}) → ${(d['after']?['items'] as List?)?.join(', ') ?? ''} (Rs. ${d['after']?['total']})',
    _ => '${e['event']}',
  };
  return '$when$who: $what';
}
