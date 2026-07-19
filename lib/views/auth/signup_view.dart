import '../../controllers/auth_service.dart';
import 'package:flutter/material.dart';


class SignupView extends StatelessWidget {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final mobile = TextEditingController();
    final cnic = TextEditingController();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Customer Signup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.person_add_outlined, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 30),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mobile,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cnic,
              decoration: const InputDecoration(
                labelText: 'CNIC (NNNNN-NNNNNNN-N)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (name.text.isEmpty || email.text.isEmpty || pass.text.isEmpty || mobile.text.isEmpty || cnic.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }
                  bool success = await AuthService.signupCustomer(
                    name: name.text,
                    email: email.text,
                    password: pass.text,
                    mobile: mobile.text,
                    cnic: cnic.text,
                  );
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account created successfully! Please login.')),
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signup failed. Email might already be in use.')),
                      );
                    }
                  }
                },
                child: const Text('REGISTER ACCOUNT'),
              ),
            )
          ],
        ),
      ),
    );
  }
}