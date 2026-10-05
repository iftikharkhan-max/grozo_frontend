import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../l10n/strings.dart';
import '../../services/api.dart';
import '../../utils/brand.dart';
import '../shell/main_shell.dart';

/// Saved delivery addresses. With [selectMode], tapping an address returns it.
class AddressesView extends StatefulWidget {
  final bool selectMode;
  final int? selectedId;
  const AddressesView({super.key, this.selectMode = false, this.selectedId});

  @override
  State<AddressesView> createState() => _AddressesViewState();
}

class _AddressesViewState extends State<AddressesView> {
  List<Map<String, dynamic>>? _items;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/me/addresses');
    if (!mounted) return;
    setState(() {
      _errorCode = res.ok ? null : (res.errorCode ?? 'generic');
      if (res.ok) _items = List<Map<String, dynamic>>.from(res.data);
    });
  }

  Future<void> _edit([Map<String, dynamic>? a]) async {
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AddressEditView(address: a)),
    );
    if (saved == null) return;
    // A newly added address in select mode is chosen straight away.
    if (widget.selectMode && a == null && mounted) {
      Navigator.pop(context, saved);
      return;
    }
    _load();
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(context.tr('delete_address_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('delete'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await Api.delete('/me/addresses/${a['id']}');
    if (!mounted) return;
    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(context, errorCode: res.errorCode))));
    }
    _load();
  }

  Future<void> _makeDefault(Map<String, dynamic> a) async {
    await Api.put('/me/addresses/${a['id']}/default');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('addresses'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(context.tr('add_address')),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items == null && _errorCode != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(friendlyError(context, errorCode: _errorCode)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: Text(context.tr('retry'))),
        ]),
      );
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) return Center(child: Text(context.tr('no_addresses')));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        for (final a in _items!)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: widget.selectMode && a['id'] == widget.selectedId
                      ? brandGreen
                      : Colors.transparent,
                  width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.selectMode
                  ? () => Navigator.pop(context, a)
                  : () => _edit(a),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                            a['label']?.toString().toLowerCase() == 'office'
                                ? Icons.work_outline
                                : Icons.home_outlined,
                            color: brandPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                a['label'] ?? context.tr('delivery_address'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        if (a['is_default'] == 1 || a['is_default'] == true)
                          Chip(
                              label: Text(context.tr('default_address')),
                              visualDensity: VisualDensity.compact),
                      ]),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            start: 32, top: 4, end: 8),
                        child: Text([a['address_line'], a['city']]
                            .where((x) => (x ?? '').toString().isNotEmpty)
                            .join(', ')),
                      ),
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 32, top: 4),
                        child: Text(
                          a['latitude'] != null
                              ? context.tr('location_saved')
                              : context.tr('location_missing'),
                          style: TextStyle(
                              fontSize: 11.5,
                              color: a['latitude'] != null
                                  ? brandGreen
                                  : Colors.orange.shade800),
                        ),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (!(a['is_default'] == 1 || a['is_default'] == true))
                          TextButton(
                              onPressed: () => _makeDefault(a),
                              child: Text(context.tr('make_default'))),
                        TextButton(
                            onPressed: () => _edit(a),
                            child: Text(context.tr('edit'))),
                        TextButton(
                            onPressed: () => _delete(a),
                            child: Text(context.tr('delete'),
                                style: const TextStyle(color: Colors.red))),
                      ]),
                    ]),
              ),
            ),
          ),
      ],
    );
  }
}

class AddressEditView extends StatefulWidget {
  final Map<String, dynamic>? address;
  const AddressEditView({super.key, this.address});

  @override
  State<AddressEditView> createState() => _AddressEditViewState();
}

class _AddressEditViewState extends State<AddressEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> a = widget.address ?? {};
  late final _label = TextEditingController(text: a['label'] ?? '');
  late final _line = TextEditingController(text: a['address_line'] ?? '');
  late final _city = TextEditingController(text: a['city'] ?? 'Abbottabad');
  late double? _lat = double.tryParse('${a['latitude']}');
  late double? _lng = double.tryParse('${a['longitude']}');
  late bool _isDefault = a['is_default'] == 1 || a['is_default'] == true;
  bool _locating = false;
  bool _saving = false;

  Future<void> _useLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    String msg(String key) => context.tr(key);
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(SnackBar(content: Text(msg('location_off'))));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(SnackBar(content: Text(msg('location_denied'))));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(msg('err_generic'))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'label': _label.text.trim(),
      'address_line': _line.text.trim(),
      'city': _city.text.trim(),
      'latitude': _lat,
      'longitude': _lng,
      'is_default': _isDefault,
    };
    final res = widget.address == null
        ? await Api.post('/me/addresses', body)
        : await Api.put('/me/addresses/${a['id']}', body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.ok) {
      Navigator.pop(context, Map<String, dynamic>.from(res.data));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(context,
              errorCode: res.errorCode, serverMessage: res.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _lat != null && _lng != null;
    return HidesOrderNowButton(
        child: Scaffold(
      appBar: AppBar(
          title: Text(widget.address == null
              ? context.tr('add_address')
              : context.tr('edit'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: _label,
              decoration:
                  InputDecoration(labelText: context.tr('address_label'))),
          const SizedBox(height: 12),
          TextFormField(
            controller: _line,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
                labelText: '${context.tr('address_line')} *',
                alignLabelWithHint: true),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? context.tr('fill_all') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: _city,
              decoration: InputDecoration(labelText: context.tr('city'))),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(hasLocation ? Icons.check_circle : Icons.my_location,
                    color: hasLocation ? brandGreen : null),
            label: Text(context.tr('use_my_location')),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hasLocation
                  ? context.tr('location_saved')
                  : context.tr('location_missing'),
              style: TextStyle(
                  fontSize: 12,
                  color: hasLocation ? brandGreen : Colors.orange.shade800),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('make_default')),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(context.tr('save')),
            ),
          ),
        ),
      ),
    ));
  }
}
