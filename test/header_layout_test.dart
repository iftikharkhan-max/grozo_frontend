import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grozo/state/app_state.dart';
import 'package:grozo/views/shell/grozo_header.dart';

// The header packs location, logo, language, cart and menu into one row.
// Render it at small-phone widths to catch overflow.
void main() {
  for (final lang in ['en', 'ur']) {
    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('header fits at ${width.toInt()}px ($lang)', (tester) async {
        tester.view.physicalSize = Size(width, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final state = AppState()
          ..branches = [
            {'id': 1, 'name': 'Grozo Store - Where you can buy every thing easily', 'name_ur': null},
          ];
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            locale: Locale(lang),
            supportedLocales: const [Locale('en'), Locale('ur')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: Column(children: [GrozoHeader(onOpen: (_) {})])),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
