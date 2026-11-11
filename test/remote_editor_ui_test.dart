import 'dart:convert';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/remote_editor_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/remote_editor_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_remote_fs.dart';

void main() {
  late FakeRemoteFs fs;
  late RemoteEditorController controller;
  late TerminalPrefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await TerminalPrefs.load();
    fs = FakeRemoteFs()
      ..put('/etc/app.conf', utf8.encode('port=22\n'))
      ..put('/etc/other.conf', utf8.encode('x=1\n'));
    controller = RemoteEditorController(() => fs);
  });

  tearDown(() => controller.dispose());

  Future<void> pumpPane(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ChangeNotifierProvider<TerminalPrefs>.value(
        value: prefs,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => Row(
                children: [
                  TextButton(onPressed: () => controller.open('/etc/app.conf'), child: const Text('open-app')),
                  TextButton(onPressed: () => controller.open('/etc/other.conf'), child: const Text('open-other')),
                  SizedBox(width: 500, child: RemoteEditorPane(controller: controller)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 가짜 파일 시스템은 메모리 안이라 바로 끝나지만, 위젯 테스트의 가짜 시계 밖에서 비동기 작업을 돌린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('opening a file shows its name and content; typing marks it modified', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('open-app'));
    await settle(tester);

    expect(find.text('app.conf'), findsWidgets);
    expect(find.text('port=22\n'), findsOneWidget);
    expect(find.textContaining('(modified)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'port=2222\n');
    await tester.pump();
    expect(find.textContaining('● app.conf'), findsOneWidget);
    expect(find.textContaining('(modified)'), findsOneWidget);
  });

  testWidgets('Ctrl+S writes the file to the server and clears the modified mark', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('open-app'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'port=2222\n');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    expect(utf8.decode(fs.files['/etc/app.conf']!), 'port=2222\n');
    expect(find.textContaining('(modified)'), findsNothing);
  });

  testWidgets('a change on the server asks before overwriting', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('open-app'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'mine\n');
    await tester.pump();
    fs.touchExternally('/etc/app.conf', utf8.encode('theirs\n'));

    // 저장 버튼은 Phosphor 아이콘이라 툴팁으로 찾는다.
    await tester.tap(find.byTooltip('Save (Ctrl+S)'));
    await settle(tester);

    expect(find.text('The file changed on the server'), findsOneWidget);
    expect(utf8.decode(fs.files['/etc/app.conf']!), 'theirs\n');

    await tester.tap(find.text('Overwrite'));
    await settle(tester);
    expect(utf8.decode(fs.files['/etc/app.conf']!), 'mine\n');
  });

  testWidgets('closing a modified file asks; Cancel keeps it, Discard closes it', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('open-app'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'changed\n');
    await tester.pump();

    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.documents.length, 1);

    await tester.tap(find.byTooltip('Close file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(controller.documents, isEmpty);
  });

  testWidgets('two files keep their own text when switching tabs', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('open-app'));
    await settle(tester);
    await tester.tap(find.text('open-other'));
    await settle(tester);

    expect(controller.documents.length, 2);
    expect(controller.current!.path, '/etc/other.conf');
    await tester.tap(find.text('app.conf'));
    await tester.pump();
    expect(controller.current!.path, '/etc/app.conf');
    expect(find.text('port=22\n'), findsOneWidget);
  });

  Text gutter(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('editor-line-numbers')));

  testWidgets('line numbers follow the number of lines, including an empty last line', (tester) async {
    fs.put('/etc/lines.txt', utf8.encode('a\nb\nc\n'));
    await pumpPane(tester);
    await tester.runAsync(() => controller.open('/etc/lines.txt'));
    await tester.pump();
    expect(gutter(tester).data, '1\n2\n3\n4');

    await tester.enterText(find.byType(TextField), 'only one line');
    await tester.pump();
    expect(gutter(tester).data, '1');
  });

  testWidgets('a long line is not wrapped: the field gets wider than the pane and scrolls sideways', (tester) async {
    fs.put('/etc/long.txt', utf8.encode('${'x' * 600}\nshort\n'));
    await pumpPane(tester);
    await tester.runAsync(() => controller.open('/etc/long.txt'));
    await tester.pump();

    // 500px 칸보다 넓은 본문 → 가로 스크롤. 줄이 넘어가지 않으니 줄 번호와 줄이 1:1이다.
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(500));
    expect(gutter(tester).data, '1\n2\n3');
  });

  testWidgets('line numbers scroll together with the text', (tester) async {
    fs.put('/etc/many.txt', utf8.encode([for (var i = 0; i < 200; i++) 'line $i'].join('\n')));
    await pumpPane(tester);
    await tester.runAsync(() => controller.open('/etc/many.txt'));
    await tester.pump();

    final numbersScroll = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .firstWhere((w) => w.physics is NeverScrollableScrollPhysics)
        .controller!;
    expect(numbersScroll.offset, 0);

    await tester.drag(find.byType(TextField), const Offset(0, -400));
    await tester.pump();
    final textScroll = tester.widget<TextField>(find.byType(TextField)).scrollController!;
    expect(textScroll.offset, greaterThan(0));
    expect(numbersScroll.offset, textScroll.offset);
  });
}
