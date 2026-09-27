import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../account/addresses_view.dart';
import '../common/product_widgets.dart';
import 'order_confirmation_view.dart';

/// Checkout for the cart: catalogue products plus any extra market items
/// ("not in the list"), which are priced at delivery.
/// All amounts come from the server's quote; the order is only placed when the
/// customer presses Confirm, and the server re-checks the total at that moment.
class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _note = TextEditingController();

  Map<String, dynamic>? _address;
  bool _addressesLoaded = false;
  Map<String, dynamic>? _quote;
  String? _quoteError;
  String? _banner; // explains why the customer should review (prices/cart changed)
  bool _placing = false;

  /// Extra market items, written as the shopping list sent with the order.
  String get _extraText => context.read<AppState>().customItemsText;

  /// Only extra items, no catalogue products.
  bool get _isMarket => context.read<AppState>().cartLines.isEmpty;

  int? get _branchId => context.read<AppState>().selectedBranch?['id'] as int?;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    _name.text = user?.name ?? '';
    _mobile.text = user?.mobile ?? '';
    _loadAddresses();
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final res = await Api.get('/me/addresses');
    if (!mounted) return;
    final list = res.ok ? List<Map<String, dynamic>>.from(res.data) : <Map<String, dynamic>>[];
    setState(() {
      _addressesLoaded = true;
      _address = list.where((a) => a['is_default'] == 1 || a['is_default'] == true).firstOrNull ?? list.firstOrNull;
    });
    _requote();
  }

  List<Map<String, dynamic>> _cartItems() => context
      .read<AppState>()
      .cartLines
      .map((l) => {'productId': l.product.id, 'qty': l.qty})
      .toList();

  Future<void> _requote() async {
    setState(() => _quoteError = null);
    final res = await Api.post('/orders/quote', {
      'items': _cartItems(),
      'requestText': _extraText,
      'branchId': _branchId,
      'addressId': _address?['id'],
      'deliveryMethod': 'delivery',
    });
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        _quote = Map<String, dynamic>.from(res.data);
        final reasons = _problems.map((p) => p['reason']).toSet();
        if (reasons.contains('address_not_found')) {
          // The saved address was deleted elsewhere; ask for another one.
          _address = null;
          _quote!['problems'] = _problems.where((p) => p['reason'] != 'address_not_found').toList();
        }
        if (reasons.contains('empty_cart')) WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      } else {
        _quoteError = friendlyError(context, errorCode: res.errorCode);
      }
    });
  }

  Future<void> _chooseAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AddressesView(selectMode: true, selectedId: _address?['id'])),
    );
    if (picked != null) {
      setState(() => _address = picked);
      _requote();
    }
  }

  List<Map<String, dynamic>> get _problems => List<Map<String, dynamic>>.from(_quote?['problems'] ?? []);
  List<Map<String, dynamic>> get _itemProblems => _problems.where((p) => p['product_id'] != null).toList();
  bool get _outsideArea => _problems.any((p) => p['reason'] == 'outside_delivery_area');

  /// Applies the server's findings to the cart: removes unavailable items and
  /// lowers quantities to what is in stock.
  void _fixCart() {
    final state = context.read<AppState>();
    for (final p in _itemProblems) {
      final id = p['product_id'] as int;
      final avail = p['available_qty'] as int?;
      if (avail == null || avail <= 0) {
        state.removeFromCart(id);
      } else {
        state.setQty(id, avail);
      }
    }
    setState(() => _banner = null);
    if (state.cartLines.isEmpty) {
      Navigator.pop(context);
      return;
    }
    _requote();
  }

  String _problemText(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    switch (p['reason']) {
      case 'insufficient_stock':
        return '$name: ${context.trf('problem_stock', {'n': p['available_qty']})}';
      case 'max_per_order':
        return '$name: ${context.trf('problem_max', {'n': p['available_qty']})}';
      default:
        return '$name ${context.tr('problem_unavailable')}';
    }
  }

  Future<void> _confirm() async {
    if (_placing || _quote == null) return;
    if (_address == null) return _toast(context.tr('need_address'));
    if (_mobile.text.trim().isEmpty) return _toast(context.tr('need_mobile'));

    setState(() => _placing = true);
    final state = context.read<AppState>();
    final res = await Api.post('/orders', {
      'items': _cartItems(),
      'requestText': _extraText,
      'branchId': _branchId,
      'addressId': _address!['id'],
      'deliveryMethod': 'delivery',
      'paymentMethod': 'COD',
      'contactName': _name.text.trim(),
      'contactMobile': _mobile.text.trim(),
      'note': _note.text.trim(),
      'expectedTotal': _quote!['total'],
    });
    if (!mounted) return;
    setState(() => _placing = false);

    if (res.ok) {
      // Remember the mobile number on the profile if it was missing.
      if ((state.user?.mobile ?? '').isEmpty) {
        Api.put('/auth/me', {'mobile': _mobile.text.trim()}).then((_) => state.refreshProfile());
      }
      state.clearCart();
      state.ordersChanged();
      final order = Order.fromJson(Map<String, dynamic>.from(res.data['order']));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderConfirmationView(order: order)),
        (route) => route.isFirst,
      );
      return;
    }

    if (res.status == 409 && res.data is Map && res.data['quote'] != null) {
      setState(() {
        _quote = Map<String, dynamic>.from(res.data['quote']);
        _banner = context.tr(res.errorCode == 'prices_changed' ? 'prices_changed' : 'cart_changed');
      });
      return;
    }
    _toast(res.errorCode == 'network' ? context.tr('err_network') : context.tr('order_failed'));
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('checkout'))),
      body: !_addressesLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_banner != null) _notice(_banner!, Colors.orange),
                if (_itemProblems.isNotEmpty) _problemsCard(),
                _addressCard(),
                const SizedBox(height: 10),
                _detailsCard(),
                const SizedBox(height: 10),
                _paymentCard(),
                const SizedBox(height: 10),
                _summaryCard(),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
              onPressed: _placing || _quote == null || _problems.isNotEmpty || _address == null ? null : _confirm,
              child: _placing
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 12),
                      Text(context.tr('placing_order')),
                    ])
                  : Text(
                      _quote == null
                          ? context.tr('confirm_order')
                          : '${context.tr('confirm_order')}  •  Rs. ${money(_quote!['total'] as num)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, MaterialColor color) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.shade200)),
        child: Row(children: [
          Icon(Icons.info_outline, color: color.shade800),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color.shade900))),
        ]),
      );

  Widget _problemsCard() => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in _itemProblems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${_problemText(p)}', style: TextStyle(color: Colors.red.shade900)),
              ),
            const SizedBox(height: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: _fixCart,
              child: Text(context.tr('fix_cart')),
            ),
          ]),
        ),
      );

  Widget _section(String title, Widget child, {Widget? action}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              if (action != null) action,
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget _addressCard() {
    final a = _address;
    return _section(
      context.tr('delivery_address'),
      a == null
          ? ElevatedButton.icon(onPressed: _chooseAddress, icon: const Icon(Icons.add_location_alt_outlined), label: Text(context.tr('add_address')))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((a['label'] ?? '').toString().isNotEmpty) Text(a['label'], style: const TextStyle(fontWeight: FontWeight.w600)),
              Text([a['address_line'], a['city']].where((x) => (x ?? '').toString().isNotEmpty).join(', ')),
              if (_outsideArea)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(context.tr('outside_area'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
            ]),
      action: a == null ? null : TextButton(onPressed: _chooseAddress, child: Text(context.tr('change'))),
    );
  }

  Widget _detailsCard() => _section(
        context.tr('your_details'),
        Column(children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: context.tr('full_name'), isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: '${context.tr('mobile')} *', hintText: '03XX-XXXXXXX', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: context.tr('note_for_rider'), isDense: true)),
        ]),
      );

  Widget _paymentCard() => _section(
        context.tr('payment_method'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments_outlined, color: brandGreen),
          title: Text(context.tr('cod')),
          subtitle: Text(context.tr('cod_sub')),
          trailing: const Icon(Icons.radio_button_checked, color: brandGreen),
        ),
      );

  Widget _summaryCard() {
    if (_quoteError != null) {
      return _section(context.tr('order_summary'), Column(children: [
        Text(_quoteError!),
        TextButton(onPressed: _requote, child: Text(context.tr('retry'))),
      ]));
    }
    final q = _quote;
    if (q == null) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));

    final lang = context.lang;
    final lines = List<Map<String, dynamic>>.from(q['lines'] ?? []);
    final discount = (q['discount_total'] as num?) ?? 0;
    final delivery = q['delivery_charge'] as num?;

    Widget row(String label, String value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 16 : 14))),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 17 : 14, color: color)),
          ]),
        );

    return _section(
      context.tr('order_summary'),
      Column(children: [
        if (_extraText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: brandGreenLight, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('your_list'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_extraText),
              Text(context.tr('price_at_delivery'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${lang == 'ur' && (l['name_ur'] ?? '').toString().isNotEmpty ? l['name_ur'] : l['name']}'
                  '${(l['unit'] ?? '').toString().isNotEmpty ? ' (${l['unit']})' : ''}  × ${l['qty']}',
                ),
              ),
              Text('Rs. ${money(l['line_total'] as num)}'),
            ]),
          ),
        const Divider(),
        if (!_isMarket) row(context.tr('subtotal'), 'Rs. ${money(q['subtotal'] as num)}'),
        if (discount > 0) row(context.tr('discount'), '− Rs. ${money(discount)}', color: brandAccent),
        row(context.tr('delivery_charge'), delivery == null ? context.tr('to_be_confirmed') : 'Rs. ${money(delivery)}'),
        const Divider(),
        row(context.tr('total_payable'), 'Rs. ${money(q['total'] as num)}', bold: true, color: brandPrimary),
        if (_extraText.isNotEmpty || delivery == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.tr('final_bill_note'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }
}
