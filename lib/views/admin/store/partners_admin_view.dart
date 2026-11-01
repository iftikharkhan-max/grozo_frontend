import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../account/location_picker_view.dart';
import '../../common/product_widgets.dart';
import 'admin_form.dart';
import 'products_admin_view.dart';

/// Partners: shops and restaurants (e.g. Faridullah Fish) shown on the home
/// page under "Order from our partners". Their items are products with
/// "Sold by" set to the partner; a partner's items are always ordered
/// separately, and the rider collects them at the partner's map location.
class PartnersAdminView extends StatefulWidget {
  const PartnersAdminView({super.key});

  @override
  State<PartnersAdminView> createState() => _PartnersAdminViewState();
}

class _PartnersAdminViewState extends State<PartnersAdminView> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/admin/partners');
    if (!mounted) return;
    if (res.ok) {
      setState(() => _items = List<Map<String, dynamic>>.from(res.data));
    } else {
      adminError(context, res);
    }
  }

  Future<void> _edit([Map<String, dynamic>? p]) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => PartnerEditView(partner: p)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Partners'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add partner'),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : _items!.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'No partners yet. Add a shop or restaurant, then add its items with "Sold by" set to it.',
                      textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final p in _items!)
                          ListTile(
                            leading: SizedBox(
                                width: 48,
                                height: 48,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: NetImage(p['logo_url'],
                                        fallbackEmoji: '🏪'))),
                            title: Text('${p['name']}'),
                            subtitle: Text([
                              p['kind'],
                              '${p['product_count'] ?? 0} item(s)',
                              if (truthy(p['coming_soon'])) 'Coming soon',
                              if (!truthy(p['is_active'])) 'Hidden',
                              if (p['latitude'] == null) 'No map location!',
                            ]
                                .where((x) => (x ?? '').toString().isNotEmpty)
                                .join(' • ')),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => _edit(p),
                          ),
                      ]),
                ),
    );
  }
}

/// Add or edit one partner.
class PartnerEditView extends StatefulWidget {
  final Map<String, dynamic>? partner;
  const PartnerEditView({super.key, this.partner});

  @override
  State<PartnerEditView> createState() => _PartnerEditViewState();
}

class _PartnerEditViewState extends State<PartnerEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> p = widget.partner ?? {};
  late final _name = TextEditingController(text: p['name'] ?? '');
  late final _nameUr = TextEditingController(text: p['name_ur'] ?? '');
  late final _kind = TextEditingController(text: p['kind'] ?? '');
  late final _kindUr = TextEditingController(text: p['kind_ur'] ?? '');
  late final _phone = TextEditingController(text: p['phone'] ?? '');
  late final _address = TextEditingController(text: p['address'] ?? '');
  late final _sort = TextEditingController(text: numText(p['sort_order']));
  late double? _lat = double.tryParse('${p['latitude']}');
  late double? _lng = double.tryParse('${p['longitude']}');
  late bool _comingSoon = truthy(p['coming_soon']);
  late bool _active = p.isEmpty ? true : truthy(p['is_active']);
  File? _logo;
  bool _busy = false;

  bool get _isNew => widget.partner == null;

  @override
  void dispose() {
    for (final c in [_name, _nameUr, _kind, _kindUr, _phone, _address, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<PickedLocation>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                LocationPickerView(latitude: _lat, longitude: _lng)));
    if (picked == null || !mounted) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
      if (_address.text.trim().isEmpty && picked.address != null) {
        _address.text = picked.address!;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lat == null && !_comingSoon) {
      adminToast(context,
          'Set the shop\'s map location: the rider collects orders there and the delivery charge uses it.');
      return;
    }
    setState(() => _busy = true);
    final fields = {
      'name': _name.text.trim(),
      'name_ur': blankToNull(_nameUr),
      'kind': blankToNull(_kind),
      'kind_ur': blankToNull(_kindUr),
      'phone': blankToNull(_phone),
      'address': blankToNull(_address),
      'latitude': _lat,
      'longitude': _lng,
      'coming_soon': _comingSoon ? 1 : 0,
      'is_active': _active ? 1 : 0,
      'sort_order': blankToNull(_sort) ?? 0,
    };
    final res = await Api.sendForm(_isNew ? 'POST' : 'PUT',
        _isNew ? '/admin/partners' : '/admin/partners/${p['id']}', fields,
        image: _logo);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, 'Partner saved.');
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Delete ${p['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await Api.delete('/admin/partners/${p['id']}');
    if (!mounted) return;
    if (res.ok) {
      adminToast(context, 'Partner deleted.');
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar(_isNew ? 'Add partner' : 'Edit partner', actions: [
        if (!_isNew)
          IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete),
      ]),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AdminImagePicker(
              currentUrl: p['logo_url'],
              picked: _logo,
              onPicked: (f) => setState(() => _logo = f)),
          adminText(_name, 'Name (English)',
              required: true, hint: 'e.g. Faridullah Fish'),
          adminText(_nameUr, 'Name (Urdu)', direction: TextDirection.rtl),
          adminText(_kind, 'Type (English)',
              hint: 'e.g. Restaurant, Fish, Bakery'),
          adminText(_kindUr, 'Type (Urdu)', direction: TextDirection.rtl),
          adminText(_phone, 'Phone', keyboard: TextInputType.phone),
          adminSection('Shop location (rider collects orders here)'),
          adminText(_address, 'Address', maxLines: 2),
          Row(children: [
            Icon(_lat == null ? Icons.location_off_outlined : Icons.location_on,
                color: _lat == null ? Colors.orange.shade800 : Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_lat == null
                  ? 'Not on the map yet'
                  : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
            ),
            TextButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: Text(_lat == null ? 'Pick on map' : 'Change')),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Coming soon'),
            subtitle: const Text(
                'Shown on the home page with a "Coming soon" label; no orders yet'),
            value: _comingSoon,
            onChanged: (v) => setState(() => _comingSoon = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible in the app'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          adminNumber(_sort, 'Order on the home page',
              decimal: false, hint: 'Smaller numbers come first'),
          if (!_isNew) ...[
            adminSection('Items'),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductsAdminView(
                          partnerId: p['id'] as int,
                          title: '${p['name']} – items'))),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text('Manage items (${p['product_count'] ?? 0})'),
            ),
          ],
        ]),
      ),
    );
  }
}
