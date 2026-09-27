import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../info/help_view.dart';
import '../routing.dart';
import 'signup_view.dart';

class LoginView extends StatefulWidget {
  /// When true, a customer login pops back to the screen that asked for it.
  final bool returnOnSuccess;
  const LoginView({super.key, this.returnOnSuccess = false});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('fill_all'))));
      return;
    }
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final result = await state.login(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.ok) {
      final user = state.user!;
      if (user.isCustomer && widget.returnOnSuccess) {
        Navigator.pop(context, true);
      } else {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => homeFor(user)), (route) => false);
      }
    } else if (result.status == 403) {
      _showInactiveDialog(result.data?['message'] ?? '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(context, errorCode: result.errorCode, serverMessage: result.message)),
      ));
    }
  }

  void _showInactiveDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('account_inactive')),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('ok'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpView()));
            },
            child: Text(context.tr('contact_support')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', width: 120, height: 120),
                const SizedBox(height: 16),
                Text(context.tr('welcome_back'), style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 30),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: context.tr('email'), prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.tr('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(onPressed: _submit, child: Text(context.tr('sign_in'))),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const SignupView()));
                    if (created == true && context.mounted) {
                      if (widget.returnOnSuccess) {
                        Navigator.pop(context, true);
                      } else {
                        goToStoreHome(context);
                      }
                    }
                  },
                  child: Text(context.tr('no_account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
