import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../models/user_model.dart';
import '../../services/api.dart';
import '../../state/app_state.dart';
import '../routing.dart';

/// Name and mobile, password change and account deletion.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final UserModel _user = context.read<AppState>().user!;
  late final _name = TextEditingController(text: _user.name);
  late final _mobile = TextEditingController(text: _user.mobile ?? '');
  bool _saving = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _toast(context.tr('fill_all'));
    setState(() => _saving = true);
    final res = await Api.put('/auth/me', {'name': _name.text.trim(), 'mobile': _mobile.text.trim()});
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.ok) {
      context.read<AppState>().setUser(UserModel.fromJson(Map<String, dynamic>.from(res.data)));
      _toast(context.tr('profile_saved'));
    } else {
      _toast(friendlyError(context, errorCode: res.errorCode, serverMessage: res.message));
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('change_password')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true, decoration: InputDecoration(labelText: context.tr('current_password'))),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: context.tr('new_password'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('save'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await Api.put('/auth/password', {'currentPassword': current.text, 'newPassword': next.text});
    if (!mounted) return;
    if (res.ok) {
      // The server signs out other devices and issues a fresh token for this one.
      await context.read<AppState>().replaceToken(res.data['token']);
      if (mounted) _toast(context.tr('password_changed'));
    } else {
      _toast(friendlyError(context, errorCode: res.errorCode, serverMessage: res.message));
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_account')),
        content: Text(context.tr('delete_account_q')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await Api.put('/admin/${_user.id}/deactivate');
    if (!mounted) return;
    if (!res.ok) return _toast(friendlyError(context, errorCode: res.errorCode));
    final messenger = ScaffoldMessenger.of(context);
    final message = context.tr('account_deleted');
    await context.read<AppState>().signOutLocally();
    if (!mounted) return;
    goToStoreHome(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: context.tr('full_name'))),
        const SizedBox(height: 12),
        TextField(
          controller: _mobile,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.tr('mobile'), hintText: '03XX-XXXXXXX'),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: context.tr('email'), enabled: false),
          child: Text(_user.email),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(onPressed: _saving ? null : _save, child: Text(context.tr('save'))),
        ),
        const SizedBox(height: 24),
        Text(context.tr('security'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: Text(context.tr('change_password')),
          onTap: _changePassword,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          title: Text(context.tr('delete_account'), style: const TextStyle(color: Colors.red)),
          onTap: _deleteAccount,
        ),
      ]),
    );
  }
}
