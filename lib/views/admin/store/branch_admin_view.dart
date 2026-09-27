import 'package:flutter/material.dart';
import '../../../services/api.dart';
import 'admin_form.dart';

/// Edits the branch shown in the app. Its map location is also used to
/// work out delivery charges by distance.
class BranchAdminView extends StatefulWidget {
  const BranchAdminView({super.key});

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
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.get('/branches').then((res) {
      if (!mounted) return;
      final list = res.ok ? List<Map<String, dynamic>>.from(res.data) : <Map<String, dynamic>>[];
      if (list.isNotEmpty) {
        final b = list.first;
        _id = b['id'];
        _name.text = b['name'] ?? '';
        _nameUr.text = b['name_ur'] ?? '';
        _address.text = b['address'] ?? '';
        _phone.text = b['phone'] ?? '';
        _hours.text = b['opening_hours'] ?? '';
        _lat.text = b['latitude']?.toString() ?? '';
        _lng.text = b['longitude']?.toString() ?? '';
      }
      setState(() => _loading = false);
    });
  }

  /// Pulls "lat,lng" out of a pasted Google Maps link or coordinates.
  void _applyMapsLink(String text) {
    final m = RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)').firstMatch(text);
    if (m == null) {
      adminToast(context, 'No coordinates found. In Google Maps, long-press the shop and copy the numbers shown.');
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
    };
    final res = _id == null ? await Api.post('/admin/branches', body) : await Api.put('/admin/branches/$_id', body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      _id ??= res.data['id'];
      adminToast(context, 'Branch saved.');
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Branch'),
      bottomNavigationBar: _loading ? null : AdminSaveButton(busy: _busy, onPressed: _save),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                adminText(_name, 'Branch name (English)', required: true),
                adminText(_nameUr, 'Branch name (Urdu)', direction: TextDirection.rtl),
                adminText(_address, 'Address', maxLines: 2),
                adminText(_phone, 'Phone', keyboard: TextInputType.phone),
                adminText(_hours, 'Opening hours', hint: 'e.g. 7:00 AM – 11:00 PM'),
                adminSection('Map location (used for directions and delivery charges)'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _mapsLink,
                      decoration: const InputDecoration(labelText: 'Paste Google Maps coordinates or link'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _applyMapsLink(_mapsLink.text), child: const Text('Use')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: adminNumber(_lat, 'Latitude')),
                  const SizedBox(width: 8),
                  Expanded(child: adminNumber(_lng, 'Longitude')),
                ]),
              ]),
            ),
    );
  }
}
