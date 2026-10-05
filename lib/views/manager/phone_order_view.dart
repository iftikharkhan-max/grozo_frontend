import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/api.dart';
import '../common/product_widgets.dart';

/// A manager takes an order over the phone. It becomes a normal, trackable
/// order (rider, status, notifications) marked as a phone order.
class PhoneOrderView extends StatefulWidget {
  const PhoneOrderView({super.key});

  @override
  State<PhoneOrderView> createState() => _PhoneOrderViewState();
}

class _PhoneOrderViewState extends State<PhoneOrderView> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _extra = TextEditingController();
  final _note = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>?
      _customer; // existing customer, or null for a new caller
  List<Product> _products = [];
  final Map<int, int> _qty = {};
  List<Map<String, dynamic>> _tiers = [];
  List<Map<String, dynamic>> _branches = [];
  double? _deliveryCharge;
  int? _branchId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      Api.get('/products'),
      Api.get('/delivery-charges'),
      Api.get('/branches')
    ]).then((r) {
      if (!mounted) return;
      setState(() {
        if (r[0].ok) {
          _products = (r[0].data as List)
              .map((p) => Product.fromJson(p))
              .where((p) => p.available)
              .toList();
        }
        if (r[1].ok) _tiers = List<Map<String, dynamic>>.from(r[1].data);
        if (r[2].ok) _branches = List<Map<String, dynamic>>.from(r[2].data);
        _branchId = _branches.firstOrNull?['id'] as int?;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_search, _name, _mobile, _address, _extra, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (text.trim().length < 2) {
        setState(() => _results = []);
        return;
      }
      final res = await Api.get('/staff/customers', query: {'q': text.trim()});
      if (mounted && res.ok) {
        setState(() => _results = List<Map<String, dynamic>>.from(res.data));
      }
    });
  }

  void _pickCustomer(Map<String, dynamic> c) {
    setState(() {
      _customer = c;
      _results = [];
      _search.clear();
      _name.text = c['name'] ?? '';
      _mobile.text = c['mobile'] ?? '';
      if (_address.text.trim().isEmpty &&
          (c['last_address'] ?? '').toString().isNotEmpty) {
        _address.text = c['last_address'];
      }
    });
  }

  double get _itemsTotal => _qty.entries.fold(0.0, (s, e) {
        final p = _products.where((p) => p.id == e.key).firstOrNull;
        return s + (p?.finalPrice ?? 0) * e.value;
      });

  Future<void> _pickProducts() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var filter = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final list = _products
              .where((p) =>
                  filter.isEmpty ||
                  p.name.toLowerCase().contains(filter.toLowerCase()))
              .toList();
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search products',
                      isDense: true),
                  onChanged: (v) => setSheet(() => filter = v),
                ),
              ),
              Expanded(
                child: ListView(children: [
                  for (final p in list)
                    ListTile(
                      leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: NetImage(p.imageUrl, fit: BoxFit.contain)),
                      title: Text(p.name),
                      subtitle: Text(
                          'Rs. ${money(p.finalPrice)}${(p.unit ?? '').isNotEmpty ? ' • ${p.unit}' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: (_qty[p.id] ?? 0) == 0
                              ? null
                              : () => setSheet(() => setState(() {
                                    final q = (_qty[p.id] ?? 0) - 1;
                                    q <= 0 ? _qty.remove(p.id) : _qty[p.id] = q;
                                  })),
                        ),
                        Text('${_qty[p.id] ?? 0}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setSheet(() => setState(() {
                                final q = (_qty[p.id] ?? 0) + 1;
                                if (p.maxQty == null || q <= p.maxQty!) {
                                  _qty[p.id] = q;
                                }
                              })),
                        ),
                      ]),
                    ),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'))),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  Future<void> _submit() async {
    if (_customer == null &&
        _mobile.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      return _toast('Enter the caller\'s mobile number.');
    }
    if (_address.text.trim().isEmpty) {
      return _toast('Enter the delivery address.');
    }
    if (_qty.isEmpty && _extra.text.trim().isEmpty) {
      return _toast('Add at least one product or item.');
    }

    setState(() => _busy = true);
    final res = await Api.post('/staff/phone-orders', {
      if (_customer != null) 'customerId': _customer!['id'],
      'name': _name.text.trim(),
      'mobile': _mobile.text.trim(),
      'address': _address.text.trim(),
      'items': [
        for (final e in _qty.entries) {'productId': e.key, 'qty': e.value}
      ],
      'requestText': _extra.text.trim(),
      'deliveryCharge': _deliveryCharge,
      'branchId': _branchId,
      'note': _note.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      _toast(res.data['message'] ?? 'Order created.');
      Navigator.pop(context, true);
    } else if (res.status == 409 && res.data is Map) {
      final problems =
          List<Map<String, dynamic>>.from(res.data['quote']?['problems'] ?? []);
      _toast(
          'Not available: ${problems.map((p) => p['name'] ?? '#${p['product_id']}').join(', ')}');
    } else {
      _toast(res.isNetworkError
          ? 'No internet connection.'
          : (res.message ?? 'Could not create the order.'));
    }
  }

  String _num(dynamic v) {
    final d = double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _qty.entries
        .map(
            (e) => (_products.where((p) => p.id == e.key).firstOrNull, e.value))
        .where((x) => x.$1 != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('New phone order')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Caller',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (_customer == null) ...[
          TextField(
            controller: _search,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_search),
                hintText: 'Find customer by name or phone'),
            onChanged: _onSearch,
          ),
          for (final c in _results)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person),
              title: Text('${c['name']}'),
              subtitle: Text([c['mobile'], c['last_address']]
                  .where((x) => (x ?? '').toString().isNotEmpty)
                  .join(' • ')),
              onTap: () => _pickCustomer(c),
            ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('…or a new caller:',
                  style: TextStyle(color: Colors.black54))),
        ] else
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.verified_user, color: Colors.green),
              title: Text('${_customer!['name']}'),
              subtitle: Text('${_customer!['mobile'] ?? ''}'),
              trailing: TextButton(
                  onPressed: () => setState(() => _customer = null),
                  child: const Text('Change')),
            ),
          ),
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 8),
        TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Mobile *', hintText: '03XX-XXXXXXX')),
        const SizedBox(height: 8),
        TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Delivery address *')),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(
              child: Text('Products',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          OutlinedButton.icon(
              onPressed: _pickProducts,
              icon: const Icon(Icons.add),
              label: const Text('Add products')),
        ]),
        for (final (p, q) in chosen)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
                '${p!.name}${(p.unit ?? '').isNotEmpty ? ' (${p.unit})' : ''} × $q'),
            trailing: Text('Rs. ${money(p.finalPrice * q)}'),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _extra,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Other items from the market (one per line)',
            hintText: 'e.g. Tapal tea 190g × 1',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<double?>(
          isExpanded: true, // long names use the full width and never overflow
          initialValue: _deliveryCharge,
          decoration: const InputDecoration(labelText: 'Delivery charge'),
          items: [
            const DropdownMenuItem<double?>(
                value: null, child: Text('Confirm at delivery')),
            for (final t in _tiers)
              DropdownMenuItem<double?>(
                value: double.tryParse('${t['charge']}'),
                child: Text(
                    '${_num(t['min_km'])}–${_num(t['max_km'])} km: Rs. ${_num(t['charge'])}'),
              ),
          ],
          onChanged: (v) => setState(() => _deliveryCharge = v),
        ),
        if (_branches.length > 1) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded:
                true, // long names use the full width and never overflow
            initialValue: _branchId,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: [
              for (final b in _branches)
                DropdownMenuItem(
                    value: b['id'] as int, child: Text('${b['name']}'))
            ],
            onChanged: (v) => setState(() => _branchId = v),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)')),
        const SizedBox(height: 16),
        Text(
          'Total: Rs. ${money(_itemsTotal + (_deliveryCharge ?? 0))}'
          '${_extra.text.trim().isNotEmpty || _deliveryCharge == null ? '  + items/charges confirmed at delivery' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Text('Payment: cash on delivery',
            style: TextStyle(color: Colors.black54)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.add_call),
              label: _busy
                  ? const CircularProgressIndicator()
                  : const Text('CREATE PHONE ORDER'),
            ),
          ),
        ),
      ),
    );
  }
}
