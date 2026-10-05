import 'package:flutter/material.dart';
import '../../../services/api.dart';
import 'admin_form.dart';

/// Sends a promotion to every customer who allows offers & deals.
class BroadcastAdminView extends StatefulWidget {
  const BroadcastAdminView({super.key});

  @override
  State<BroadcastAdminView> createState() => _BroadcastAdminViewState();
}

class _BroadcastAdminViewState extends State<BroadcastAdminView> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _titleUr = TextEditingController();
  final _body = TextEditingController();
  final _bodyUr = TextEditingController();
  String _linkType = 'none';
  int? _linkId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  bool _busy = false;

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

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (_linkType != 'none' && _linkId == null) {
      return adminToast(context, 'Choose what the notification opens.');
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to all customers?'),
        content: const Text(
            'Every customer who allows offers & deals will receive this. It cannot be recalled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final res = await Api.post('/admin/notifications/broadcast', {
      'title': _title.text.trim(),
      'title_ur': blankToNull(_titleUr),
      'body': blankToNull(_body),
      'body_ur': blankToNull(_bodyUr),
      'link_type': _linkType == 'none' ? null : _linkType,
      'link_id': _linkType == 'none' ? null : _linkId,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      adminToast(context, res.data['message'] ?? 'Sent.');
      Navigator.pop(context);
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = _linkType == 'category' ? _categories : _products;
    return Scaffold(
      appBar: adminAppBar('Send notification'),
      bottomNavigationBar:
          AdminSaveButton(busy: _busy, onPressed: _send, label: 'SEND'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Customers see this in the app under 🔔 Notifications.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          adminText(_title, 'Title (English)',
              required: true, hint: 'e.g. Mango season is here!'),
          adminText(_titleUr, 'Title (Urdu)', direction: TextDirection.rtl),
          adminText(_body, 'Message (English)', maxLines: 3),
          adminText(_bodyUr, 'Message (Urdu)',
              maxLines: 3, direction: TextDirection.rtl),
          adminSection('When tapped, open'),
          DropdownButtonFormField<String>(
            isExpanded:
                true, // long names use the full width and never overflow
            initialValue: _linkType,
            items: const [
              DropdownMenuItem(
                  value: 'none', child: Text('Nothing (message only)')),
              DropdownMenuItem(value: 'category', child: Text('A category')),
              DropdownMenuItem(value: 'product', child: Text('A product')),
            ],
            onChanged: (v) => setState(() {
              _linkType = v!;
              _linkId = null;
            }),
          ),
          if (_linkType != 'none')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<int>(
                isExpanded:
                    true, // long names use the full width and never overflow
                initialValue: _linkId,
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
        ]),
      ),
    );
  }
}
