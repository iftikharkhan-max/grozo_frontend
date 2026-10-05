import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';
import 'admin_form.dart';

/// Categories: "Featured" ones are the big Vegetables/Fruits cards and product
/// strips on the home page; "Market" ones are the Market Shopping tiles.
class CategoriesAdminView extends StatefulWidget {
  const CategoriesAdminView({super.key});

  @override
  State<CategoriesAdminView> createState() => _CategoriesAdminViewState();
}

class _CategoriesAdminViewState extends State<CategoriesAdminView> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Api.get('/admin/categories');
    if (!mounted) return;
    if (res.ok) {
      setState(() => _items = List<Map<String, dynamic>>.from(res.data));
    } else {
      adminError(context, res);
    }
  }

  Future<void> _edit([Map<String, dynamic>? c]) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => CategoryEditView(category: c)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget group(String title, String key) {
      final list =
          (_items ?? []).where((c) => c['display_group'] == key).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: adminSection(title)),
        for (final c in list)
          ListTile(
            leading: SizedBox(
                width: 44,
                height: 44,
                child: NetImage(c['image_url'],
                    fallbackEmoji: categoryEmoji('${c['name']}'))),
            title: Text('${c['name']}  ${c['name_ur'] ?? ''}'),
            subtitle: Text(
                'Order: ${c['sort_order']}${truthy(c['is_active']) ? '' : '  •  Hidden'}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _edit(c),
          ),
      ]);
    }

    return Scaffold(
      appBar: adminAppBar('Categories'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: adminColor,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    group('Featured on home page (big cards + product strips)',
                        'featured'),
                    group('Market Shopping tiles', 'market'),
                  ]),
            ),
    );
  }
}

class CategoryEditView extends StatefulWidget {
  final Map<String, dynamic>? category;
  const CategoryEditView({super.key, this.category});

  @override
  State<CategoryEditView> createState() => _CategoryEditViewState();
}

class _CategoryEditViewState extends State<CategoryEditView> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> c = widget.category ?? {};
  late final _name = TextEditingController(text: c['name'] ?? '');
  late final _nameUr = TextEditingController(text: c['name_ur'] ?? '');
  late final _subtitle = TextEditingController(text: c['subtitle'] ?? '');
  late final _subtitleUr = TextEditingController(text: c['subtitle_ur'] ?? '');
  late final _order = TextEditingController(text: '${c['sort_order'] ?? 0}');
  late String _group = c['display_group'] ?? 'market';
  late bool _active = c.isEmpty ? true : truthy(c['is_active']);
  File? _image;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final isNew = widget.category == null;
    final res = await Api.sendForm(
      isNew ? 'POST' : 'PUT',
      isNew ? '/admin/categories' : '/admin/categories/${c['id']}',
      {
        'name': _name.text.trim(),
        'name_ur': blankToNull(_nameUr),
        'subtitle': blankToNull(_subtitle),
        'subtitle_ur': blankToNull(_subtitleUr),
        'display_group': _group,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar(
          widget.category == null ? 'Add category' : 'Edit category'),
      bottomNavigationBar: AdminSaveButton(busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AdminImagePicker(
              currentUrl: c['image_url'],
              picked: _image,
              onPicked: (f) => setState(() => _image = f)),
          adminText(_name, 'Name (English)', required: true),
          adminText(_nameUr, 'Name (Urdu)', direction: TextDirection.rtl),
          adminText(_subtitle, 'Short line (English)',
              hint: 'e.g. Fresh & Healthy'),
          adminText(_subtitleUr, 'Short line (Urdu)',
              direction: TextDirection.rtl),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              isExpanded:
                  true, // long names use the full width and never overflow
              initialValue: _group,
              decoration: const InputDecoration(labelText: 'Where it appears'),
              items: const [
                DropdownMenuItem(
                    value: 'featured',
                    child: Text('Featured (big card + product strip)')),
                DropdownMenuItem(
                    value: 'market', child: Text('Market Shopping tile')),
              ],
              onChanged: (v) => setState(() => _group = v!),
            ),
          ),
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
