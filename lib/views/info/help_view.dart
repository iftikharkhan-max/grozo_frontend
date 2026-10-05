import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../utils/brand.dart';
import 'info_page.dart';

/// Help & Support: contact options and FAQ, all managed by the admin.
class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('help_support'))),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: AppSettings.load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          final phone = s?['support_phone']?.toString() ?? '';
          final whatsapp = s?['support_whatsapp']?.toString() ?? '';
          final email = s?['support_email']?.toString() ?? '';
          final faq = AppSettings.pick(s, 'faq', context.lang);
          final nothing =
              phone.isEmpty && whatsapp.isEmpty && email.isEmpty && faq == null;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (nothing)
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(context.tr('content_not_set'))),
              if (phone.isNotEmpty)
                _ContactTile(
                    icon: Icons.call,
                    label: context.tr('call_us'),
                    value: phone,
                    uri: Uri(scheme: 'tel', path: phone)),
              if (whatsapp.isNotEmpty)
                _ContactTile(
                  icon: Icons.chat,
                  label: context.tr('whatsapp_us'),
                  value: whatsapp,
                  uri: Uri.parse(
                      'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '92')}'),
                ),
              if (email.isNotEmpty)
                _ContactTile(
                    icon: Icons.email_outlined,
                    label: context.tr('email_us'),
                    value: email,
                    uri: Uri(scheme: 'mailto', path: email)),
              if (faq != null) ...[
                const SizedBox(height: 16),
                Text(context.tr('faq'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(faq, style: const TextStyle(height: 1.5)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Uri uri;
  const _ContactTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.uri});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: brandGreen),
          title: Text(label),
          subtitle: Text(value, textDirection: TextDirection.ltr),
          trailing: Icon(Icons.chevron_right,
              textDirection: Directionality.of(context)),
          onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      );
}
