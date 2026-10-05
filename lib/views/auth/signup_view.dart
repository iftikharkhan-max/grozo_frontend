import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// Customer registration. On success the customer is logged in straight away
/// and the screen pops with `true`.
class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _mobile = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _mobile]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _pass.text.isEmpty ||
        _mobile.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('fill_all'))));
      return;
    }
    setState(() => _loading = true);
    final res = await context.read<AppState>().register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _pass.text,
          mobile: _mobile.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(context,
            errorCode: res.errorCode, serverMessage: res.message)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(context.tr('create_account'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: AutofillGroup(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Icon(Icons.person_add_outlined,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                    labelText: context.tr('full_name'),
                    prefixIcon: const Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                    labelText: context.tr('mobile'),
                    hintText: '03XX-XXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                    labelText: context.tr('email'),
                    prefixIcon: const Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pass,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                    labelText: context.tr('password'),
                    prefixIcon: const Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(context.tr('create_account'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
