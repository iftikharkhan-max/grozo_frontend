import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../info/branch_view.dart';
import '../info/help_view.dart';
import '../info/info_page.dart';
import '../routing.dart';
import '../shell/main_shell.dart';
import 'login_required.dart';

/// Header "More" (⋮) menu.
void showMoreMenu(BuildContext context) {
  final state = context.read<AppState>();
  void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      Widget item(IconData icon, String key, VoidCallback onTap, {Color? color}) => ListTile(
            leading: Icon(icon, color: color ?? brandPrimary),
            title: Text(context.tr(key), style: TextStyle(color: color)),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            item(Icons.translate, 'language', () => showLanguagePicker(context)),
            item(Icons.location_on_outlined, 'branch_location', () => go(const BranchView())),
            item(Icons.person_outline, 'account', () => MainShell.switchTab(context, MainShell.account)),
            item(Icons.support_agent, 'help_support', () => go(const HelpView())),
            item(Icons.info_outline, 'about_us', () => go(const InfoPage(titleKey: 'about_us', settingKey: 'about_us'))),
            item(Icons.description_outlined, 'terms', () => go(const InfoPage(titleKey: 'terms', settingKey: 'terms'))),
            item(Icons.privacy_tip_outlined, 'privacy', () => go(const InfoPage(titleKey: 'privacy', settingKey: 'privacy_policy'))),
            const Divider(),
            if (state.isLoggedIn)
              item(Icons.logout, 'logout', () => confirmLogout(context), color: Colors.red)
            else
              item(Icons.login, 'login', () => openLogin(context)),
          ]),
        ),
      );
    },
  );
}

void showLanguagePicker(BuildContext context) {
  final state = context.read<AppState>();
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(context.tr('language')),
      children: [
        for (final (code, label) in [('en', 'English'), ('ur', 'اردو')])
          ListTile(
            leading: Icon(state.language == code ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: brandPrimary),
            title: Text(label),
            onTap: () {
              state.setLanguage(code);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
}

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(context.tr('logout_confirm')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('logout'), style: const TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final message = context.tr('logged_out');
  await context.read<AppState>().logout();
  if (!context.mounted) return;
  goToStoreHome(context);
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
