import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order.dart';
import '../common/product_widgets.dart';

/// Order details for managers and riders: who, where, what, and how much.
class StaffOrderInfo extends StatelessWidget {
  final Map<String, dynamic> raw;
  const StaffOrderInfo(this.raw, {super.key});

  @override
  Widget build(BuildContext context) {
    final o = Order.fromJson(_withItems(raw));
    final phone = (raw['customer_mobile'] ?? o.contactMobile ?? '').toString();
    final lat = double.tryParse('${raw['address_latitude']}');
    final lng = double.tryParse('${raw['address_longitude']}');
    final destination = lat != null && lng != null ? '$lat,$lng' : (o.destination ?? '');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _line(Icons.person_outline, '${o.contactName ?? raw['customer_name'] ?? 'Customer'}'),
      if (phone.isNotEmpty)
        InkWell(
          onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
          child: _line(Icons.call, phone, color: Colors.blue),
        ),
      InkWell(
        onTap: destination.isEmpty
            ? null
            : () => launchUrl(Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination}),
                mode: LaunchMode.externalApplication),
        child: _line(Icons.location_on_outlined, o.destination ?? 'No address', color: destination.isEmpty ? null : Colors.blue),
      ),
      if (o.isMarketRequest)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MARKET SHOPPING – buy from market:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(o.requestText ?? ''),
          ]),
        ),
      if (o.items.isNotEmpty) ...[
        const SizedBox(height: 6),
        for (final l in o.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              Expanded(child: Text('• ${l.name}${(l.unit ?? '').isNotEmpty ? ' (${l.unit})' : ''}  × ${l.qty}')),
              if (l.price > 0) Text('Rs. ${money(l.lineTotal)}'),
            ]),
          ),
      ],
      if ((o.note ?? '').isNotEmpty) _line(Icons.sticky_note_2_outlined, 'Note: ${o.note}'),
      const SizedBox(height: 6),
      if (o.deliveryMethod == 'delivery' && raw['subtotal'] != null)
        Text(
          o.deliveryCharge == null
              ? 'Delivery charge: to be confirmed at delivery'
              : 'Delivery charge: Rs. ${money(o.deliveryCharge!)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      Text(
        o.totalPending
            ? 'Collect (COD): Rs. ${money(o.amount)} + items/charges confirmed at delivery'
            : 'Collect (COD): Rs. ${money(o.amount)}',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      ),
    ]);
  }

  /// Staff lists return items as a JSON string; the Order model expects a list.
  static Map<String, dynamic> _withItems(Map<String, dynamic> raw) {
    if (raw['items'] != null) return raw;
    return {...raw, 'items': Order.parseItemsJson(raw['items_json'])};
  }

  Widget _line(IconData icon, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color ?? Colors.black54),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ]),
      );
}
