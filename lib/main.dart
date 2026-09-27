import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'views/shell/main_shell.dart';
import 'views/auth/login_view.dart';
import 'views/auth/signup_view.dart';
import 'views/routing.dart';
import 'utils/brand.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const GrozoMVCApp(),
    ),
  );
}

final navigatorKey = GlobalKey<NavigatorState>();

class GrozoMVCApp extends StatelessWidget {
  const GrozoMVCApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color inputFillColor = Colors.white;
    final language = context.select<AppState, String>((s) => s.language);

    return MaterialApp(
      title: 'Fast, Reliable -> Grozo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // English / Urdu; Urdu switches the whole layout to right-to-left.
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPrimary,
          primary: brandPrimary,
          secondary: brandAccent,
          surface: brandBackground,
        ),

        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: brandAccent,
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

      home: const SplashGate(),

      routes: {
        '/storefront': (context) => const MainShell(),
        '/login': (context) => const LoginView(),
        '/signup': (context) => const SignupView(),
      },
    );
  }
}

/// Shows the logo while the saved session, language and cart are restored.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    Future.wait([
      state.load(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 180, height: 180),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      );
    }
    return homeFor(context.read<AppState>().user);
  }
}
