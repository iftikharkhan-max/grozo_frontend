import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import 'my_orders_view.dart';
import 'reorder.dart';
import '../shell/main_shell.dart';

class OrderDetailView extends StatefulWidget {
  final int orderId;
  const OrderDetailView({super.key, required this.orderId});

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  Order? _order;
  String? _errorCode;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // While the order is on its way, refresh status and rider location.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_order != null && _order!.isActive) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await Api.get('/orders/${widget.orderId}');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) _order = Order.fromJson(Map<String, dynamic>.from(res.data));
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(context.tr('cancel_order_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('keep_order'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('cancel_order'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await Api.post('/orders/${widget.orderId}/cancel');
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(res.ok
        ? context.tr('order_cancelled')
        : friendlyError(context,
            errorCode: res.errorCode, serverMessage: res.message));
    if (res.ok) context.read<AppState>().ordersChanged();
    _load();
  }

  Future<void> _markReceived() async {
    setState(() => _busy = true);
    final res = await Api.put(
        '/orders/${widget.orderId}/status', {'status': 'Complete'});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      context.read<AppState>().ordersChanged();
    } else {
      _toast(friendlyError(context, errorCode: res.errorCode));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return HidesOrderNowButton(
        child: Scaffold(
      appBar: AppBar(
        title: Text(o == null
            ? context.tr('order')
            : '${context.tr('order')} ${o.number}'),
        actions: [
          if (o != null)
            IconButton(
              tooltip: context.tr(o.isFavorite ? 'unstar_order' : 'star_order'),
              icon: Icon(o.isFavorite ? Icons.star : Icons.star_border,
                  color: o.isFavorite ? Colors.amber.shade700 : null),
              onPressed: () async {
                if (await setOrderFavorite(context, o, !o.isFavorite)) _load();
              },
            ),
        ],
      ),
      body: o == null
          ? Center(
              child: _errorCode == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(friendlyError(context, errorCode: _errorCode)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: Text(context.tr('retry'))),
                    ]),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                _timeline(o),
                if (o.step == OrderStep.riderAssigned ||
                    o.step == OrderStep.outForDelivery)
                  _riderCard(o),
                _itemsCard(o),
                _infoCard(o),
              ]),
            ),
      bottomNavigationBar: o == null ? null : _actions(o),
    ));
  }

  Widget? _actions(Order o) {
    final buttons = <Widget>[
      if (o.canMarkReceived)
        ElevatedButton.icon(
          onPressed: _busy ? null : _markReceived,
          icon: const Icon(Icons.check),
          label: Text(context.tr('mark_received')),
        ),
      if (!o.isActive &&
          (o.items.any((l) => l.productId != null) ||
              o.extraItemLines.isNotEmpty))
        ElevatedButton.icon(
          onPressed: _busy ? null : () => reorder(context, o),
          icon: const Icon(Icons.replay),
          label: Text(context.tr('reorder')),
        ),
      if (o.canCancel)
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _busy ? null : _cancel,
          child: Text(context.tr('cancel_order')),
        ),
    ];
    if (buttons.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: SizedBox(height: 48, child: b)),
          ],
        ]),
      ),
    );
  }

  Widget _timeline(Order o) {
    if (o.step == OrderStep.cancelled) {
      return Card(
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red),
          title: Text(context.tr('step_cancelled'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(formatDateTime(o.createdAt)),
        ),
      );
    }
    const steps = [
      OrderStep.placed,
      OrderStep.confirmed,
      OrderStep.riderAssigned,
      OrderStep.outForDelivery,
      OrderStep.delivered,
      OrderStep.completed
    ];
    final current = steps.indexOf(o.step);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          for (final (i, s) in steps.indexed)
            Row(children: [
              Column(children: [
                Icon(
                    i <= current
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: i <= current ? brandGreen : Colors.black26,
                    size: 22),
                if (i < steps.length - 1)
                  Container(
                      width: 2,
                      height: 18,
                      color: i < current ? brandGreen : Colors.black12),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(stepLabel(context, s),
                      style: TextStyle(
                        fontWeight:
                            i == current ? FontWeight.bold : FontWeight.normal,
                        color: i <= current ? Colors.black87 : Colors.black38,
                      )),
                ),
              ),
            ]),
        ]),
      ),
    );
  }

  Widget _riderCard(Order o) {
    final hasLocation = o.riderLat != null && o.riderLng != null;
    final minutes = o.riderAt == null
        ? null
        : DateTime.now().difference(o.riderAt!).inMinutes;
    return Card(
      color: brandYellowLight,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.delivery_dining, color: brandAccent, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${context.tr('rider')}: ${o.riderName ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if ((o.riderMobile ?? '').isNotEmpty)
              IconButton.filledTonal(
                tooltip: context.tr('call_rider'),
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: o.riderMobile)),
                icon: const Icon(Icons.call),
              ),
          ]),
          if (hasLocation) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/search/',
                    {'api': '1', 'query': '${o.riderLat},${o.riderLng}'}),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(context.tr('rider_on_map')),
            ),
            if (minutes != null)
              Text(
                  context.trf('rider_updated',
                      {'t': minutes < 1 ? '< 1 min' : '$minutes min'}),
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ]),
      ),
    );
  }

  Widget _itemsCard(Order o) {
    final lang = context.lang;
    Widget row(String l, String v, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style:
                        TextStyle(fontWeight: bold ? FontWeight.bold : null))),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: color)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('items'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          if (o.extraItemLines.isNotEmpty) ...[
            Text(context.tr('custom_items_section'),
                style: const TextStyle(
                    color: brandAccent, fontWeight: FontWeight.w600)),
            for (final line in o.extraItemLines) Text('• $line'),
            const SizedBox(height: 6),
          ],
          for (final l in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 40,
                    height: 40,
                    child: NetImage(l.imageUrl, fit: BoxFit.contain)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.displayName(lang)),
                        Text(
                            '${(l.unit ?? '').isNotEmpty ? '${l.unit} • ' : ''}Rs. ${money(l.price)} × ${l.qty}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ]),
                ),
                Text('Rs. ${money(l.lineTotal)}'),
              ]),
            ),
          const Divider(),
          if (o.subtotal != null && !o.isMarketRequest)
            row(context.tr('subtotal'), 'Rs. ${money(o.subtotal!)}'),
          if ((o.discountTotal ?? 0) > 0)
            row(context.tr('discount'), '− Rs. ${money(o.discountTotal!)}',
                color: brandAccent),
          if (o.deliveryMethod == 'delivery')
            row(
                context.tr('delivery_charge'),
                o.deliveryCharge == null
                    ? context.tr('to_be_confirmed')
                    : 'Rs. ${money(o.deliveryCharge!)}'),
          row(context.tr('total_payable'), 'Rs. ${money(o.amount)}',
              bold: true, color: brandPrimary),
          if (o.totalPending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.tr('final_bill_note'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
        ]),
      ),
    );
  }

  Widget _infoCard(Order o) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _info(Icons.calendar_today_outlined, context.tr('order_date'),
                formatDateTime(o.createdAt)),
            _info(Icons.location_on_outlined, context.tr('deliver_to'),
                o.destination ?? ''),
            if ((o.contactMobile ?? '').isNotEmpty)
              _info(
                  Icons.phone_outlined, context.tr('mobile'), o.contactMobile!),
            _info(Icons.payments_outlined, context.tr('payment_method'),
                context.tr('cod')),
            if ((o.note ?? '').isNotEmpty)
              _info(Icons.sticky_note_2_outlined, context.tr('note_for_rider'),
                  o.note!),
          ]),
        ),
      );

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(value),
            ]),
          ),
        ]),
      );
}
