import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../utils/brand.dart';
import '../common/product_widgets.dart';
import '../orders/order_detail_view.dart';

class OrderConfirmationView extends StatelessWidget {
  final Order order;
  const OrderConfirmationView({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('order_placed_title')), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.check_circle, color: brandGreen, size: 88),
          const SizedBox(height: 12),
          Text(context.tr('order_placed_title'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(context.tr('order_placed_body'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row(context.tr('order_number'), order.number, bold: true),
                _row(context.tr('order_date'), formatDateTime(order.createdAt)),
                _row(context.tr('status'), context.tr('step_placed')),
                _row(context.tr('payment_method'), context.tr('cod')),
                const Divider(),
                Text(context.tr('deliver_to'), style: const TextStyle(color: Colors.black54)),
                Text(order.destination ?? ''),
                const Divider(),
                if (order.extraItemLines.isNotEmpty) ...[
                  Text(context.tr('custom_items_section'), style: const TextStyle(color: Colors.black54)),
                  for (final line in order.extraItemLines) Text('• $line'),
                ],
                for (final l in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text('${l.displayName(lang)} × ${l.qty}')),
                      Text('Rs. ${money(l.lineTotal)}'),
                    ]),
                  ),
                const Divider(),
                _row(context.tr('total_payable'), 'Rs. ${money(order.amount)}', bold: true),
                if (order.totalPending)
                  Text(context.tr('final_bill_note'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(context.tr('continue_shopping')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailView(orderId: order.id)),
                ),
                child: Text(context.tr('view_order')),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 16 : 14)),
        ]),
      );
}
