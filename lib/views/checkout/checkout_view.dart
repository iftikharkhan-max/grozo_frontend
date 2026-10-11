import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../../utils/opening_hours.dart';
import '../account/addresses_view.dart';
import '../account/location_picker_view.dart';
import '../common/product_widgets.dart';
import 'order_confirmation_view.dart';
import '../shell/main_shell.dart';

/// Checkout for the cart: catalogue products plus any extra market items
/// ("not in the list"), which are priced at delivery.
/// Steps, top to bottom: branch → delivery address → charges → review → confirm.
/// The branch is never chosen silently: with several branches the customer
/// picks one here (or already did in the header) before Confirm is enabled.
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
  String?
      _banner; // explains why the customer should review (prices/cart changed)
  bool _placing = false;

  /// Extra market items, written as the shopping list sent with the order.
  String get _extraText => context.read<AppState>().customItemsText;

  /// Only extra items, no catalogue products.
  bool get _isMarket => context.read<AppState>().cartLines.isEmpty;

  /// The branch that will fulfil the order; null until the customer picks one.
  int? _branchId;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final user = state.user;
    _name.text = user?.name ?? '';
    _mobile.text = user?.mobile ?? '';
    _preselectBranch();
    if (state.branches.isEmpty) {
      state.loadBranches().then((_) {
        if (!mounted || _branchId != null) return;
        setState(_preselectBranch);
        if (_branchId != null) _requote();
      });
    }
    _loadAddresses();
  }

  /// Only one branch: nothing to choose. Several: keep the one the customer
  /// already picked in the header; otherwise they must choose below.
  void _preselectBranch() {
    final state = context.read<AppState>();
    if (state.branches.length == 1) {
      _branchId = state.branches.first['id'] as int?;
    } else if (state.hasChosenBranch) {
      _branchId = state.selectedBranch?['id'] as int?;
    }
  }

  /// Branches with distance and delivery charge to the chosen address (from
  /// the quote), or the plain list until the first quote arrives.
  List<Map<String, dynamic>> get _branchOptions {
    final fromQuote = _quote?['branch_options'];
    if (fromQuote is List) return List<Map<String, dynamic>>.from(fromQuote);
    return context.read<AppState>().branches;
  }

  bool get _needsBranch => _branchId == null && _branchOptions.isNotEmpty;

  void _selectBranch(int id) {
    setState(() {
      _branchId = id;
      if (_banner == context.tr('branch_unavailable')) _banner = null;
    });
    context.read<AppState>().selectBranch(id);
    _requote();
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
    final list = res.ok
        ? List<Map<String, dynamic>>.from(res.data)
        : <Map<String, dynamic>>[];
    setState(() {
      _addressesLoaded = true;
      _address = list
              .where((a) => a['is_default'] == 1 || a['is_default'] == true)
              .firstOrNull ??
          list.firstOrNull;
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
        if (reasons.contains('branch_unavailable')) {
          // The chosen branch closed for orders; let the customer pick again.
          _branchId = null;
          _banner = context.tr('branch_unavailable');
          context.read<AppState>().loadBranches();
        }
        if (_branchId == null) {
          // Charges and delivery area are only meaningful for a chosen branch.
          _quote!['problems'] = _problems
              .where((p) =>
                  p['reason'] != 'branch_unavailable' &&
                  p['reason'] != 'outside_delivery_area')
              .toList();
        }
        if (reasons.contains('address_not_found')) {
          // The saved address was deleted elsewhere; ask for another one.
          _address = null;
          _quote!['problems'] = _problems
              .where((p) => p['reason'] != 'address_not_found')
              .toList();
        }
        if (reasons.contains('empty_cart')) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.pop(context));
        }
      } else {
        _quoteError = friendlyError(context, errorCode: res.errorCode);
      }
    });
  }

  /// Spec 17: the delivery point is shown before confirming and can be
  /// moved on the map; the saved address is updated and charges recalculated.
  Future<void> _adjustPin() async {
    final a = _address;
    if (a == null) return;
    final picked = await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<PickedLocation>(
            builder: (_) => LocationPickerView(
                latitude: double.tryParse('${a['latitude']}'),
                longitude: double.tryParse('${a['longitude']}'))));
    if (picked == null || !mounted) return;
    final res = await Api.put('/me/addresses/${a['id']}', {
      'label': a['label'],
      'address_line': a['address_line'],
      'city': a['city'],
      'latitude': picked.latitude,
      'longitude': picked.longitude,
    });
    if (!mounted) return;
    if (res.ok && res.data is Map) {
      setState(() => _address = Map<String, dynamic>.from(res.data));
      _requote();
    } else {
      _toast(friendlyError(context,
          errorCode: res.errorCode, serverMessage: res.message));
    }
  }

  Future<void> _chooseAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddressesView(selectMode: true, selectedId: _address?['id'])),
    );
    if (picked != null) {
      setState(() => _address = picked);
      _requote();
    }
  }

  List<Map<String, dynamic>> get _problems =>
      List<Map<String, dynamic>>.from(_quote?['problems'] ?? []);
  List<Map<String, dynamic>> get _itemProblems =>
      _problems.where((p) => p['product_id'] != null).toList();
  bool get _outsideArea =>
      _problems.any((p) => p['reason'] == 'outside_delivery_area');

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
        return '$name: ${context.trf('problem_stock', {
              'n': p['available_qty']
            })}';
      case 'max_per_order':
        return '$name: ${context.trf('problem_max', {
              'n': p['available_qty']
            })}';
      default:
        return '$name ${context.tr('problem_unavailable')}';
    }
  }

  Future<void> _confirm() async {
    if (_placing || _quote == null) return;
    if (_needsBranch) return _toast(context.tr('need_branch'));
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
        Api.put('/auth/me', {'mobile': _mobile.text.trim()})
            .then((_) => state.refreshProfile());
      }
      state.clearCart();
      state.ordersChanged();
      final order =
          Order.fromJson(Map<String, dynamic>.from(res.data['order']));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderConfirmationView(order: order)),
        (route) => route.isFirst,
      );
      return;
    }

    if (res.status == 409 && res.data is Map && res.data['quote'] != null) {
      final quote = Map<String, dynamic>.from(res.data['quote']);
      final branchGone = List.from(quote['problems'] ?? [])
          .any((p) => p is Map && p['reason'] == 'branch_unavailable');
      if (branchGone) {
        setState(() => _branchId = null);
        _requote(); // shows the "choose another branch" notice
        return;
      }
      setState(() {
        _quote = quote;
        _banner = context.tr(res.errorCode == 'prices_changed'
            ? 'prices_changed'
            : 'cart_changed');
      });
      return;
    }
    _toast(res.errorCode == 'network'
        ? context.tr('err_network')
        : context.tr('order_failed'));
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return HidesOrderNowButton(
        child: Scaffold(
      appBar: AppBar(title: Text(context.tr('checkout'))),
      body: !_addressesLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_banner != null) _notice(_banner!, Colors.orange),
                if (_itemProblems.isNotEmpty) _problemsCard(),
                _branchCard(),
                const SizedBox(height: 10),
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
              onPressed: _placing ||
                      _quote == null ||
                      _problems.isNotEmpty ||
                      _needsBranch ||
                      _address == null
                  ? null
                  : _confirm,
              child: _placing
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 12),
                      Text(context.tr('placing_order')),
                    ])
                  : Text(
                      _needsBranch
                          ? context.tr('select_branch')
                          : _quote == null
                              ? context.tr('confirm_order')
                              : '${context.tr('confirm_order')}  •  Rs. ${money(_quote!['total'] as num)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _notice(String text, MaterialColor color) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.shade200)),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in _itemProblems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${_problemText(p)}',
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            const SizedBox(height: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: _fixCart,
              child: Text(context.tr('fix_cart')),
            ),
          ]),
        ),
      );

  Widget _section(String title, Widget child, {Widget? action}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15))),
              if (action != null) action,
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget _branchCard() {
    final options = _branchOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    final lang = context.lang;
    final now = DateTime.now();
    final hasDistances = options.any((b) => b['distance_km'] != null);

    Widget option(Map<String, dynamic> b) {
      final id = b['id'] as int;
      final selected = id == _branchId;
      final name = (lang == 'ur' && (b['name_ur'] ?? '').toString().isNotEmpty
              ? b['name_ur']
              : b['name'])
          .toString();
      final open = isOpenAt(b['opening_hours']?.toString(), now);
      final km = b['distance_km'] as num?;
      final charge = b['delivery_charge'] as num?;
      final outside = b['outside_delivery_area'] == true;
      final facts = <Widget>[
        if (km != null)
          Text(context.trf('km_away', {'km': km.toStringAsFixed(1)})),
        if (open != null)
          Text(context.tr(open ? 'open_now' : 'closed_now'),
              style: TextStyle(
                  color: open ? brandGreen : Colors.red.shade700,
                  fontWeight: FontWeight.w600)),
        if (outside)
          Text(context.tr('branch_outside_area'),
              style: TextStyle(color: Colors.red.shade700))
        else if (charge != null)
          Text(context.trf('delivery_rs', {'n': money(charge)})),
      ];
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: selected ? brandGreenLight : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: selected ? brandGreen : Colors.black12,
                  width: selected ? 2 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: selected ? null : () => _selectBranch(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: brandGreen),
                ),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        if ((b['address'] ?? '').toString().isNotEmpty)
                          Text('${b['address']}',
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.black54)),
                        if (open == null &&
                            (b['opening_hours'] ?? '').toString().isNotEmpty)
                          Text('${b['opening_hours']}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        if (facts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(fontSize: 12.5),
                              child: Wrap(
                                  spacing: 12, runSpacing: 2, children: facts),
                            ),
                          ),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return _section(
      context.tr('select_branch'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_branchId == null)
          Text(context.tr('branch_choose_hint'),
              style: TextStyle(color: Colors.orange.shade900)),
        for (final b in options) option(b),
        if (!hasDistances && _address != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.tr('branch_distance_hint'),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }

  Widget _addressCard() {
    final a = _address;
    return _section(
      context.tr('delivery_address'),
      a == null
          ? ElevatedButton.icon(
              onPressed: _chooseAddress,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(context.tr('add_address')))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((a['label'] ?? '').toString().isNotEmpty)
                Text(a['label'],
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              Text([a['address_line'], a['city']]
                  .where((x) => (x ?? '').toString().isNotEmpty)
                  .join(', ')),
              _pinRow(a),
              if (_outsideArea)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(context.tr('outside_area'),
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                ),
            ]),
      action: a == null
          ? null
          : TextButton(
              onPressed: _chooseAddress, child: Text(context.tr('change'))),
    );
  }

  Widget _pinRow(Map<String, dynamic> a) {
    final pinned = a['latitude'] != null && a['longitude'] != null;
    return Row(children: [
      Icon(pinned ? Icons.location_on : Icons.location_off_outlined,
          size: 18, color: pinned ? brandGreen : Colors.orange.shade800),
      const SizedBox(width: 4),
      Expanded(
        child: Text(context.tr(pinned ? 'pin_set' : 'pin_missing'),
            style: TextStyle(
                fontSize: 12.5,
                color: pinned ? brandGreen : Colors.orange.shade900)),
      ),
      TextButton(
          onPressed: _adjustPin,
          child: Text(context.tr(pinned ? 'adjust_pin' : 'pick_on_map'))),
    ]);
  }

  Widget _detailsCard() => _section(
        context.tr('your_details'),
        Column(children: [
          TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: context.tr('full_name'), isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: '${context.tr('mobile')} *',
                hintText: '03XX-XXXXXXX',
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: context.tr('note_for_rider'), isDense: true)),
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
      return _section(
          context.tr('order_summary'),
          Column(children: [
            Text(_quoteError!),
            TextButton(onPressed: _requote, child: Text(context.tr('retry'))),
          ]));
    }
    final q = _quote;
    if (q == null) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()));
    }

    final lang = context.lang;
    final lines = List<Map<String, dynamic>>.from(q['lines'] ?? []);
    final discount = (q['discount_total'] as num?) ?? 0;
    final delivery = q['delivery_charge'] as num?;
    // Until a branch is chosen the charge (and so the total) isn't known yet.
    final itemsOnly = _needsBranch;
    final total =
        itemsOnly ? (q['total'] as num) - (delivery ?? 0) : q['total'] as num;

    Widget row(String label, String value, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: bold ? FontWeight.bold : null,
                        fontSize: bold ? 16 : 14))),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    fontSize: bold ? 17 : 14,
                    color: color)),
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
            decoration: BoxDecoration(
                color: brandGreenLight, borderRadius: BorderRadius.circular(8)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('your_list'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_extraText),
              Text(context.tr('price_at_delivery'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        if (!_isMarket)
          row(context.tr('subtotal'), 'Rs. ${money(q['subtotal'] as num)}'),
        if (discount > 0)
          row(context.tr('discount'), '− Rs. ${money(discount)}',
              color: brandAccent),
        row(
            context.tr('delivery_charge'),
            itemsOnly
                ? context.tr('after_branch')
                : delivery == null
                    ? context.tr('to_be_confirmed')
                    : 'Rs. ${money(delivery)}'),
        const Divider(),
        row(context.tr('total_payable'), 'Rs. ${money(total)}',
            bold: true, color: brandPrimary),
        if (_extraText.isNotEmpty || delivery == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.tr('final_bill_note'),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }
}
