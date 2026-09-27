import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grozo/state/app_state.dart';
import 'package:grozo/views/shell/order_options.dart';

void main() {
  Widget app(String lang) => ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          locale: Locale(lang),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showOrderOptions(context, open: (_) {}),
                  child: const Text('ORDER NOW'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('Order Now asks how to order, in both languages, with three options', (tester) async {
    await tester.pumpWidget(app('en'));
    await tester.tap(find.text('ORDER NOW'));
    await tester.pumpAndSettle();

    expect(find.text('How would you like to order?'), findsOneWidget);
    expect(find.text('آپ کس طرح آرڈر کرنا چاہتے ہیں؟'), findsOneWidget);
    expect(find.text('🛒 Online Order'), findsOneWidget);
    expect(find.text('📞 Call'), findsOneWidget);
    expect(find.text('🟢 WhatsApp'), findsOneWidget);
  });

  testWidgets('Order options are translated in Urdu', (tester) async {
    await tester.pumpWidget(app('ur'));
    await tester.tap(find.text('ORDER NOW'));
    await tester.pumpAndSettle();

    expect(find.text('🛒 آن لائن آرڈر'), findsOneWidget);
    expect(find.text('🟢 واٹس ایپ'), findsOneWidget);
  });
}
