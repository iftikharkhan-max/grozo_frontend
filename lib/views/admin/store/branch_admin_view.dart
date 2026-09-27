import 'package:flutter/material.dart';
import '../../../services/api.dart';
import 'admin_form.dart';

/// All branches (including hidden ones). Customers pick one from the app
/// header; its map location is used for directions and delivery charges.
class BranchesAdminView extends StatefulWidget {
  const BranchesAdminView({super.key});

  @override
  State<BranchesAdminView> createState() => _BranchesAdminViewState();
}

class _BranchesAdminViewState extends State<BranchesAdminView> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/admin/branches');
    if (!mounted) return;
    if (res.ok) {
      setState(() => _items = List<Map<String, dynamic>>.from(res.data));
    } else {
      adminError(context, res);
    }
  }

  Future<void> _edit([Map<String, dynamic>? b]) async {
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => BranchAdminView(branch: b)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Branches'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add branch'),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : _items!.isEmpty
              ? const Center(child: Text('No branches yet.'))
              : ListView(padding: const EdgeInsets.only(bottom: 88), children: [
                  for (final b in _items!)
                    ListTile(
                      leading: Icon(Icons.storefront,
                          color: truthy(b['is_active'])
                              ? adminColor
                              : Colors.grey),
                      title: Text('${b['name']}'),
                      subtitle: Text([
                        b['address'],
                        if (!truthy(b['is_active'])) 'Hidden'
                      ]
                          .where((x) => (x ?? '').toString().isNotEmpty)
                          .join(' • ')),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(b),
                    ),
                ]),
    );
  }
}

/// Add or edit one branch.
class BranchAdminView extends StatefulWidget {
  final Map<String, dynamic>? branch;
  const BranchAdminView({super.key, this.branch});

  @override
  State<BranchAdminView> createState() => _BranchAdminViewState();
}

class _BranchAdminViewState extends State<BranchAdminView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameUr = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _mapsLink = TextEditingController();
  int? _id;
  bool _active = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    if (b != null) {
      _id = b['id'];
      _active = truthy(b['is_active']);
      _name.text = b['name'] ?? '';
      _nameUr.text = b['name_ur'] ?? '';
      _address.text = b['address'] ?? '';
      _phone.text = b['phone'] ?? '';
      _hours.text = b['opening_hours'] ?? '';
      _lat.text = b['latitude']?.toString() ?? '';
      _lng.text = b['longitude']?.toString() ?? '';
    }
  }

  /// Pulls "lat,lng" out of a pasted Google Maps link or coordinates.
  void _applyMapsLink(String text) {
    final m =
        RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)').firstMatch(text);
    if (m == null) {
      adminToast(context,
          'No coordinates found. In Google Maps, long-press the shop and copy the numbers shown.');
      return;
    }
    setState(() {
      _lat.text = m.group(1)!;
      _lng.text = m.group(2)!;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      'name_ur': blankToNull(_nameUr),
      'address': blankToNull(_address),
      'phone': blankToNull(_phone),
      'opening_hours': blankToNull(_hours),
      'latitude': double.tryParse(_lat.text.trim()),
      'longitude': double.tryParse(_lng.text.trim()),
      'is_active': _active ? 1 : 0,
    };
    final res = _id == null
        ? await Api.post('/admin/branches', body)
        : await Api.put('/admin/branches/$_id', body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, 'Branch saved.');
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar(_id == null ? 'Add branch' : 'Edit branch'),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          adminText(_name, 'Branch name (English)',
              required: true,
              hint: 'Short – shown in the app header, e.g. Mandian Road'),
          adminText(_nameUr, 'Branch name (Urdu)',
              direction: TextDirection.rtl),
          adminText(_address, 'Address', maxLines: 2),
          adminText(_phone, 'Phone', keyboard: TextInputType.phone),
          adminText(_hours, 'Opening hours', hint: 'e.g. 7:00 AM – 11:00 PM'),
          adminSection(
              'Map location (used for directions and delivery charges)'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _mapsLink,
                decoration: const InputDecoration(
                    labelText: 'Paste Google Maps coordinates or link'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: () => _applyMapsLink(_mapsLink.text),
                child: const Text('Use')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: adminNumber(_lat, 'Latitude')),
            const SizedBox(width: 8),
            Expanded(child: adminNumber(_lng, 'Longitude')),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible in the app'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ]),
      ),
    );
  }
}
