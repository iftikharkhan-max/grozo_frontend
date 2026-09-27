import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../info/info_page.dart';

/// Phone numbers for ordering: the admin's support numbers, falling back to the
/// selected branch's phone.
Future<(String?, String?)> _numbers(BuildContext context) async {
  final settings = await AppSettings.load();
  if (!context.mounted) return (null, null);
  final branchPhone = context.read<AppState>().selectedBranch?['phone']?.toString();
  String? pick(String? a, String? b) => (a ?? '').trim().isNotEmpty ? a!.trim() : ((b ?? '').trim().isNotEmpty ? b!.trim() : null);
  final phone = pick(settings?['support_phone']?.toString(), branchPhone);
  final whatsapp = pick(settings?['support_whatsapp']?.toString(), phone);
  return (phone, whatsapp);
}

/// 03XX-XXXXXXX -> 923XXXXXXXXX for WhatsApp links.
String whatsappNumber(String n) => n.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '92');

Future<void> callToOrder(BuildContext context) async {
  final (phone, _) = await _numbers(context);
  if (!context.mounted) return;
  if (phone == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('no_contact_number'))));
    return;
  }
  await launchUrl(Uri(scheme: 'tel', path: phone));
}

/// Opens WhatsApp with a greeting and, if the cart has items, the list.
Future<void> whatsappToOrder(BuildContext context) async {
  final (_, number) = await _numbers(context);
  if (!context.mounted) return;
  if (number == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('no_contact_number'))));
    return;
  }
  final state = context.read<AppState>();
  final lang = context.lang;
  final lines = [
    for (final l in state.cartLines) '• ${l.product.displayName(lang)}${(l.product.unit ?? '').isNotEmpty ? ' (${l.product.unit})' : ''} × ${l.qty}',
    for (final c in state.customItems) '• ${c.line}',
  ];
  final text = [context.tr('whatsapp_greeting'), if (lines.isNotEmpty) '', ...lines].join('\n');
  await launchUrl(
    Uri.https('wa.me', '/${whatsappNumber(number)}', {'text': text}),
    mode: LaunchMode.externalApplication,
  );
}
