import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';
import 'admin_form.dart';

/// Offers, discounts and deals shown in the home-page banner area.
class BannersAdminView extends StatefulWidget {
  const BannersAdminView({super.key});

  @override
  State<BannersAdminView> createState() => _BannersAdminViewState();
}

class _BannersAdminViewState extends State<BannersAdminView> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/admin/banners');
    if (!mounted) return;
    if (res.ok) {
      setState(() => _items = List<Map<String, dynamic>>.from(res.data));
    } else {
      adminError(context, res);
    }
  }

  Future<void> _edit([Map<String, dynamic>? b]) async {
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => BannerEditView(banner: b)));
    if (saved == true) _load();
  }

  String _status(Map<String, dynamic> b) {
    if (!truthy(b['is_active'])) return 'Hidden';
    final now = DateTime.now();
    final starts = parseServerDate(b['starts_at']);
    final ends = parseServerDate(b['ends_at']);
    if (starts != null && starts.isAfter(now)) {
      return 'Starts ${starts.day}/${starts.month}';
    }
    if (ends != null && ends.isBefore(now)) return 'Expired';
    return ends == null ? 'Showing' : 'Showing until ${ends.day}/${ends.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Offers & Deals'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add banner'),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : _items!.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No banners yet. The home page shows the built-in "Order Anything" card until you add one.',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final b in _items!)
                          ListTile(
                            leading: SizedBox(
                                width: 64,
                                height: 40,
                                child: NetImage(b['image_url'],
                                    fallbackEmoji: '🏷️')),
                            title: Text('${b['title']}'),
                            subtitle: Text(
                                '${'${b['kind']}'.toUpperCase()} • ${_status(b)}'),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => _edit(b),
                          ),
                      ]),
                ),
    );
  }
}

class BannerEditView extends StatefulWidget {
  final Map<String, dynamic>? banner;
  const BannerEditView({super.key, this.banner});

  @override
  State<BannerEditView> createState() => _BannerEditViewState();
}

class _BannerEditViewState extends State<BannerEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> b = widget.banner ?? {};
  late final _title = TextEditingController(text: b['title'] ?? '');
  late final _titleUr = TextEditingController(text: b['title_ur'] ?? '');
  late final _subtitle = TextEditingController(text: b['subtitle'] ?? '');
  late final _subtitleUr = TextEditingController(text: b['subtitle_ur'] ?? '');
  late final _terms = TextEditingController(text: b['terms'] ?? '');
  late final _order = TextEditingController(text: '${b['sort_order'] ?? 0}');
  late String _kind = b['kind'] ?? 'offer';
  late String _linkType = b['link_type'] ?? 'none';
  late int? _linkId = b['link_id'] as int?;
  late DateTime? _starts = parseServerDate(b['starts_at']);
  late DateTime? _ends = parseServerDate(b['ends_at']);
  late bool _active = b.isEmpty ? true : truthy(b['is_active']);
  File? _image;
  bool _busy = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    Future.wait([Api.get('/admin/categories'), Api.get('/products')]).then((r) {
      if (!mounted) return;
      setState(() {
        if (r[0].ok) _categories = List<Map<String, dynamic>>.from(r[0].data);
        if (r[1].ok) _products = List<Map<String, dynamic>>.from(r[1].data);
      });
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_linkType != 'none' && _linkId == null) {
      adminToast(context,
          'Choose which ${_linkType == 'category' ? 'category' : 'product'} the banner opens.');
      return;
    }
    setState(() => _busy = true);
    final isNew = widget.banner == null;
    final res = await Api.sendForm(
      isNew ? 'POST' : 'PUT',
      isNew ? '/admin/banners' : '/admin/banners/${b['id']}',
      {
        'kind': _kind,
        'title': _title.text.trim(),
        'title_ur': blankToNull(_titleUr),
        'subtitle': blankToNull(_subtitle),
        'subtitle_ur': blankToNull(_subtitleUr),
        'terms': blankToNull(_terms),
        'link_type': _linkType,
        'link_id': _linkType == 'none' ? null : _linkId,
        'starts_at': sqlDate(_starts == null
            ? null
            : DateTime(_starts!.year, _starts!.month, _starts!.day)),
        'ends_at': sqlDate(_ends),
        'sort_order': int.tryParse(_order.text.trim()) ?? 0,
        'is_active': _active ? 1 : 0,
      },
      image: _image,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      adminError(context, res);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Delete this banner?'),
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
    final res = await Api.delete('/admin/banners/${b['id']}');
    if (!mounted) return;
    res.ok ? Navigator.pop(context, true) : adminError(context, res);
  }

  @override
  Widget build(BuildContext context) {
    final targets = _linkType == 'category' ? _categories : _products;
    return Scaffold(
      appBar: adminAppBar(widget.banner == null ? 'Add banner' : 'Edit banner',
          actions: [
            if (widget.banner != null)
              IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete),
          ]),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'Recommended image size: 1200 × 520 (wide). Without an image, the title and text are shown on a coloured card.',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          AdminImagePicker(
              currentUrl: b['image_url'],
              picked: _image,
              onPicked: (f) => setState(() => _image = f)),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'offer', label: Text('Offer')),
                ButtonSegment(value: 'discount', label: Text('Discount')),
                ButtonSegment(value: 'deal', label: Text('Deal')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
          adminText(_title, 'Title (English)',
              required: true, hint: 'e.g. 20% off all fruits'),
          adminText(_titleUr, 'Title (Urdu)', direction: TextDirection.rtl),
          adminText(_subtitle, 'Details (English)', maxLines: 2),
          adminText(_subtitleUr, 'Details (Urdu)',
              maxLines: 2, direction: TextDirection.rtl),
          adminSection('When tapped, open'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              isExpanded:
                  true, // long names use the full width and never overflow
              initialValue: _linkType,
              items: const [
                DropdownMenuItem(
                    value: 'none',
                    child: Text('Offer details (title, validity, terms)')),
                DropdownMenuItem(value: 'category', child: Text('A category')),
                DropdownMenuItem(value: 'product', child: Text('A product')),
              ],
              onChanged: (v) => setState(() {
                _linkType = v!;
                _linkId = null;
              }),
            ),
          ),
          if (_linkType != 'none')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                isExpanded:
                    true, // long names use the full width and never overflow
                initialValue:
                    targets.any((t) => t['id'] == _linkId) ? _linkId : null,
                decoration: InputDecoration(
                    labelText:
                        _linkType == 'category' ? 'Category' : 'Product'),
                items: [
                  for (final t in targets)
                    DropdownMenuItem(
                        value: t['id'] as int, child: Text('${t['name']}'))
                ],
                onChanged: (v) => setState(() => _linkId = v),
              ),
            ),
          adminSection('Validity'),
          AdminDateField(
              label: 'Starts on (optional)',
              value: _starts,
              onChanged: (d) => setState(() => _starts = d)),
          AdminDateField(
              label: 'Ends on (optional)',
              value: _ends,
              onChanged: (d) => setState(() => _ends = d)),
          adminText(_terms, 'Terms & conditions (optional)', maxLines: 3),
          adminNumber(_order, 'Display order',
              hint: 'Smaller numbers appear first', decimal: false),
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
