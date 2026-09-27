import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../services/api.dart';

/// Loads the public app settings (support contacts, legal text) once per app run.
class AppSettings {
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>?> load({bool refresh = false}) async {
    if (_cache != null && !refresh) return _cache;
    final res = await Api.get('/settings');
    if (res.ok && res.data is Map) _cache = Map<String, dynamic>.from(res.data);
    return _cache;
  }

  /// Urdu text when available and selected, otherwise English.
  static String? pick(Map<String, dynamic>? s, String key, String lang) {
    if (s == null) return null;
    final ur = s['${key}_ur']?.toString();
    if (lang == 'ur' && (ur ?? '').isNotEmpty) return ur;
    final en = s[key]?.toString();
    return (en ?? '').isEmpty ? null : en;
  }
}

/// About Us / Terms / Privacy: text managed by the admin.
class InfoPage extends StatelessWidget {
  final String titleKey;
  final String settingKey;
  const InfoPage({super.key, required this.titleKey, required this.settingKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(titleKey))),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: AppSettings.load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final text = AppSettings.pick(snap.data, settingKey, context.lang);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(text ?? context.tr('content_not_set'), style: const TextStyle(fontSize: 15, height: 1.5)),
          );
        },
      ),
    );
  }
}
