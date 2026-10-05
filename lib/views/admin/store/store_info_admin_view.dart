import 'package:flutter/material.dart';
import '../../../services/api.dart';
import '../../info/info_page.dart';
import 'admin_form.dart';

/// Support contacts and the text pages (About, Terms, Privacy, FAQ).
class StoreInfoAdminView extends StatefulWidget {
  const StoreInfoAdminView({super.key});

  @override
  State<StoreInfoAdminView> createState() => _StoreInfoAdminViewState();
}

class _StoreInfoAdminViewState extends State<StoreInfoAdminView> {
  static const _keys = [
    'support_phone',
    'support_whatsapp',
    'support_email',
    'about_us',
    'about_us_ur',
    'terms',
    'terms_ur',
    'privacy_policy',
    'privacy_policy_ur',
    'faq',
    'faq_ur',
  ];
  final Map<String, TextEditingController> _c = {
    for (final k in _keys) k: TextEditingController()
  };
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppSettings.load(refresh: true).then((s) {
      if (!mounted) return;
      for (final k in _keys) {
        _c[k]!.text = s?[k]?.toString() ?? '';
      }
      setState(() => _loading = false);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final res = await Api.put(
        '/admin/settings', {for (final k in _keys) k: blankToNull(_c[k]!)});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      AppSettings.load(refresh: true);
      adminToast(context, 'Store information saved.');
    } else {
      adminError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pair(String title, String key) => ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_c[key]!.text.isEmpty ? 'Not set' : 'Set',
              style: TextStyle(
                  color: _c[key]!.text.isEmpty ? Colors.orange : Colors.green)),
          children: [
            adminText(_c[key]!, 'English', maxLines: 12),
            adminText(_c['${key}_ur']!, 'Urdu',
                maxLines: 12, direction: TextDirection.rtl),
          ],
        );

    return Scaffold(
      appBar: adminAppBar('Store information'),
      bottomNavigationBar:
          _loading ? null : AdminSaveButton(busy: _busy, onPressed: _save),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              adminSection('Help & Support contacts'),
              adminText(_c['support_phone']!, 'Support phone',
                  keyboard: TextInputType.phone),
              adminText(_c['support_whatsapp']!, 'WhatsApp number',
                  keyboard: TextInputType.phone),
              adminText(_c['support_email']!, 'Support email',
                  keyboard: TextInputType.emailAddress),
              adminSection('Pages'),
              pair('About Us', 'about_us'),
              pair('Terms & Conditions', 'terms'),
              pair('Privacy Policy', 'privacy_policy'),
              pair('Frequently Asked Questions', 'faq'),
            ]),
    );
  }
}
