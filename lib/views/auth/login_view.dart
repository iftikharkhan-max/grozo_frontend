import 'package:flutter/material.dart';
import 'package:grozo/controllers/auth_service.dart';
import 'signup_view.dart';
import '../customer/customer_dashboard.dart';
import '../manager/manager_dashboard.dart';
import '../rider/rider_dashboard.dart';
import '../admin/add_user_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  void _submit() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) return;
    setState(() => _loading = true);
    final user = await AuthService.login(_email.text, _pass.text);
    setState(() => _loading = false);

    if (!mounted) return;

    if (user != null) {
      Widget dest;
      if (user.role == 'Admin') {
        dest = const AddUserView();
      } else if (user.role == 'Manager') {
        dest = ManagerDashboard(user: user);
      } else if (user.role == 'Rider') {
        dest = RiderDashboard(user: user);
      } else {
        dest = CustomerDashboard(user: user);
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid user matching profiles')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // Matches your brand background
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. ADD YOUR LOGO HERE AT THE TOP OF THE CARD
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 16),

            // Your title text styled using your global primary color
            Text(
              'GROZO LOGISTICS',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
            const SizedBox(height: 16), // Added spacing between text fields

            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),

            _loading
                ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary))
                : SizedBox(
              width: double.infinity, // Makes button span beautifully across the screen
              child: ElevatedButton(onPressed: _submit, child: const Text('SIGN IN')),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupView())),
              child: const Text('Create Customer Account'),
            )
          ],
        ),
      ),
    );
  }
}