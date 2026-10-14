import 'package:daylight_terminal/help/help_mode.dart';
import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HelpModeController help;
  var pressed = 0;

  setUp(() {
    help = HelpModeController();
    pressed = 0;
  });

  Future<void> pumpApp(WidgetTester tester, {Locale locale = const Locale('ko')}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: HelpModeScope(
          controller: help,
          child: Stack(
            children: [
              Positioned.fill(
                child: Scaffold(
                  appBar: AppBar(actions: const [HelpModeButton()]),
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () {
                          pressed++;
                          showDialog<void>(
                            context: context,
                            builder: (_) => const AlertDialog(content: Text('dlg')),
                          );
                        },
                        child: const Text('target'),
                      ).help(HelpId.settings),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: help,
                builder: (context, _) =>
                    help.active ? Positioned.fill(child: HelpModeOverlay(controller: help)) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<TestGesture> hover(WidgetTester tester, Offset at) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(at);
    await tester.pump();
    return g;
  }

  testWidgets('? 버튼으로 들어가 마우스를 올리면 설명이 나오고, 클릭하면 끝난다 (아래 버튼은 눌리지 않는다)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pump();
    expect(help.active, isTrue);

    await hover(tester, tester.getCenter(find.text('target')));
    expect(find.text('설정'), findsOneWidget);
    expect(find.textContaining('터미널 글꼴'), findsOneWidget);

    await tester.tap(find.text('target'), warnIfMissed: false);
    await tester.pump();
    expect(help.active, isFalse);
    expect(pressed, 0);
    expect(find.text('dlg'), findsNothing);
  });

  testWidgets('영문 설정이면 영문 설명이 나온다', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    help.start();
    await tester.pump();
    await hover(tester, tester.getCenter(find.text('target')));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('terminal font'), findsOneWidget);
  });

  testWidgets('Esc로 끝난다', (tester) async {
    await pumpApp(tester);
    help.start();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(help.active, isFalse);
  });

  testWidgets('다이얼로그가 떠 있으면 ? 버튼이 꺼져 있다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('target'));
    await tester.pumpAndSettle();
    expect(find.text('dlg'), findsOneWidget);

    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
    expect(help.active, isFalse);
  });
}
