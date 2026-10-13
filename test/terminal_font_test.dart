import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/terminal_font_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TerminalPrefs', () {
    test('defaults to the bundled Agave Nerd Font Mono', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await TerminalPrefs.load();
      expect(prefs.family, 'AgaveNerdFontMono');
      expect(prefs.size, 13);
      expect(prefs.isPreset, isTrue);
      expect(prefs.style.fontFamily, 'AgaveNerdFontMono');
      // 한글은 OS 한글 글꼴로 넘어간다.
      expect(prefs.style.fontFamilyFallback, contains('Malgun Gothic'));
    });

    test('a custom installed font is saved, still falls back to the bundled one', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await TerminalPrefs.load();
      await prefs.setFamily('  Fira Code ');
      await prefs.setSize(16);
      expect(prefs.family, 'Fira Code');
      expect(prefs.isPreset, isFalse);
      expect(prefs.style.fontFamilyFallback.first, 'AgaveNerdFontMono');

      final again = await TerminalPrefs.load(); // 다시 켜도 유지
      expect((again.family, again.size), ('Fira Code', 16));
    });

    test('size is clamped, blank names are ignored, reset restores defaults', () async {
      SharedPreferences.setMockInitialValues({'terminal_font_size': 99.0, 'terminal_font_family': '  '});
      final prefs = await TerminalPrefs.load();
      expect(prefs.size, TerminalPrefs.maxSize);
      expect(prefs.family, 'AgaveNerdFontMono');
      await prefs.setSize(1);
      expect(prefs.size, TerminalPrefs.minSize);
      await prefs.setFamily('   ');
      expect(prefs.family, 'AgaveNerdFontMono');
      await prefs.setFamily('Consolas');
      await prefs.reset();
      expect((prefs.family, prefs.size), ('AgaveNerdFontMono', 13));
      expect((await TerminalPrefs.load()).family, 'AgaveNerdFontMono');
    });
  });

  testWidgets('font dialog: pick a preset, type a custom name, change size, reset', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final prefs = await TerminalPrefs.load();
    await tester.pumpWidget(
      ChangeNotifierProvider<TerminalPrefs>.value(
        value: prefs,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showTerminalFontDialog(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Agave Nerd Font Mono (내장)'), findsOneWidget);

    // 목록에서 고르기
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consolas').last);
    await tester.pumpAndSettle();
    expect(prefs.family, 'Consolas');

    // 직접 입력
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력…').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '설치된 글꼴 이름'), 'JetBrains Mono');
    await tester.pump();
    expect(prefs.family, 'JetBrains Mono');
    expect(prefs.isPreset, isFalse);

    // 크기
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();
    expect(prefs.size, greaterThan(13));

    // 기본값으로
    await tester.tap(find.text('기본값으로'));
    await tester.pumpAndSettle();
    expect((prefs.family, prefs.size), ('AgaveNerdFontMono', 13));
    expect(tester.takeException(), isNull);
  });
}
