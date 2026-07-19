import 'package:flutter/material.dart';
import 'views/auth/login_view.dart';

void main() {
  runApp(const GrozoMVCApp());
}

class GrozoMVCApp extends StatelessWidget {
  const GrozoMVCApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. DEFINE YOUR LOGO COLORS HERE
    const Color brandPrimary = Color(0xFF045826);   // Main logo color
    const Color brandAccent = Color(0xFFD66006);    // Secondary logo color
    const Color brandBackground = Color(0xFFF4F6F7);// App background canvas
    const Color inputFillColor = Colors.white;

    return MaterialApp(
      title: 'Fast, Reliable -> Grozo',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
          primary: brandPrimary,
          secondary: brandAccent,
          surface: brandBackground,
        ),

        // FIXES THE INVISIBLE TAB TEXT CONTRAST ISSUE
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,            // Active tab text
          unselectedLabelColor: Colors.white60, // Inactive tab text
          indicatorColor: brandAccent,          // Match accent color
          indicatorSize: TabBarIndicatorSize.tab,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: brandPrimary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: brandPrimary.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: brandPrimary, width: 2),
          ),
        ),

        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: brandPrimary),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandPrimary),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),

      home: const LoginScreenWrapper(),
    );
  }
}

// 2. STATEFUL SPLASH SCREEN HANDLING YOUR LOGO ENTRANCE
class LoginScreenWrapper extends StatefulWidget {
  const LoginScreenWrapper({super.key});

  @override
  State<LoginScreenWrapper> createState() => _LoginScreenWrapperState();
}

class _LoginScreenWrapperState extends State<LoginScreenWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Hold splash screen for 2.5 seconds, then load login view
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 180,
                height: 180,
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const LoginView();
  }
}