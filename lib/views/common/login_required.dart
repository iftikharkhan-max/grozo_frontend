import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../utils/brand.dart';
import '../auth/login_view.dart';

/// Shown in place of a screen that needs the customer to be logged in.
class LoginRequired extends StatelessWidget {
  final String titleKey;
  const LoginRequired({super.key, required this.titleKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(titleKey)), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: brandGreen),
              const SizedBox(height: 16),
              Text(context.tr('login_required_title'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(context.tr('login_required_body'), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openLogin(context),
                child: Text(context.tr('login')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the login screen. Returns true if the customer logged in.
Future<bool> openLogin(BuildContext context) async {
  final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginView(returnOnSuccess: true)));
  return result == true;
}
