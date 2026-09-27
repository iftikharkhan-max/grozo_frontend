import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../utils/brand.dart';
import '../common/login_required.dart';
import '../common/more_menu.dart';
import '../info/branch_view.dart';
import '../info/help_view.dart';
import '../info/info_page.dart';
import '../shell/main_shell.dart';
import 'addresses_view.dart';
import 'profile_view.dart';

/// Simple list-based account page.
class AccountView extends StatelessWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Widget tile(IconData icon, String title, VoidCallback onTap, {String? subtitle, Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? brandPrimary),
          title: Text(title, style: TextStyle(color: color)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: color == null ? Icon(Icons.chevron_right, textDirection: Directionality.of(context)) : null,
          onTap: onTap,
        );

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('my_account')), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          Container(
            color: brandGreenLight,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: brandGreen,
                child: Text(user == null ? '?' : user.name.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: user == null
                    ? Text(context.tr('login_required_body'))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(user.email, style: const TextStyle(color: Colors.black54)),
                        if ((user.mobile ?? '').isNotEmpty) Text(user.mobile!, style: const TextStyle(color: Colors.black54)),
                      ]),
              ),
              if (user == null) ElevatedButton(onPressed: () => openLogin(context), child: Text(context.tr('login'))),
            ]),
          ),
          if (user != null) ...[
            section(context.tr('account')),
            tile(Icons.person_outline, context.tr('profile'), () => go(const ProfileView())),
            tile(Icons.location_on_outlined, context.tr('addresses'), () => go(const AddressesView())),
            tile(Icons.receipt_long_outlined, context.tr('my_orders'), () => MainShell.switchTab(context, MainShell.orders)),
            tile(Icons.favorite_border, context.tr('favorites'), () => MainShell.switchTab(context, MainShell.favorites)),
          ],
          section(context.tr('more')),
          tile(Icons.translate, context.tr('language'), () => showLanguagePicker(context),
              subtitle: state.isUrdu ? 'اردو' : 'English'),
          tile(Icons.location_on_outlined, context.tr('branch_location'), () => go(const BranchView())),
          tile(Icons.support_agent, context.tr('help_support'), () => go(const HelpView())),
          tile(Icons.info_outline, context.tr('about_us'), () => go(const InfoPage(titleKey: 'about_us', settingKey: 'about_us'))),
          tile(Icons.description_outlined, context.tr('terms'), () => go(const InfoPage(titleKey: 'terms', settingKey: 'terms'))),
          tile(Icons.privacy_tip_outlined, context.tr('privacy'), () => go(const InfoPage(titleKey: 'privacy', settingKey: 'privacy_policy'))),
          if (user != null) ...[
            const Divider(),
            tile(Icons.logout, context.tr('logout'), () => confirmLogout(context), color: Colors.red),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
