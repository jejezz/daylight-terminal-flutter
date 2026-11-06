import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/ui_prefs.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/widgets/tab_bar_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UiPrefs', () {
    test('defaults to 100%, is clamped to 80–150% and snapped to 5% steps, saved and reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await UiPrefs.load();
      expect(prefs.scale, 1.0);

      await prefs.setScale(1.23);
      expect(prefs.scale, 1.25);
      await prefs.setScale(9);
      expect(prefs.scale, UiPrefs.maxScale);
      await prefs.setScale(0.1);
      expect(prefs.scale, UiPrefs.minScale);
      await prefs.setScale(1.15);
      expect((await UiPrefs.load()).scale, 1.15); // 다시 켜도 유지

      var notified = 0;
      prefs.addListener(() => notified++);
      await prefs.setScale(1.15); // 같은 값은 알리지 않는다
      expect(notified, 0);
      await prefs.reset();
      expect(prefs.scale, 1.0);
      expect(notified, 1);
      expect((await UiPrefs.load()).scale, 1.0);
    });

    test('a bad saved value is cleaned on load', () async {
      SharedPreferences.setMockInitialValues({'ui_text_scale': 7.0});
      expect((await UiPrefs.load()).scale, UiPrefs.maxScale);
    });
  });

  testWidgets('the tab bar grows with the text scale so two-line tabs still fit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = SessionsController(await ProfileStore.load());
    addTearDown(c.dispose);
    Future<double> barHeight(double scale) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionsController>.value(
          value: c,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: TabBarRow())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at scale $scale');
      return tester.getSize(find.byType(TabBarRow)).height;
    }

    expect(await barHeight(1.0), 48);
    expect(await barHeight(1.5), 72);
    expect(await barHeight(0.8), closeTo(38.4, 0.01));
  });
}
