import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/sender_prefs.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:daylight_terminal/widgets/remote_editor_pane.dart';
import 'package:daylight_terminal/widgets/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_pty.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);

class _FixedFinder extends LocalShellFinder {
  _FixedFinder(this.shells);
  final List<LocalShell> shells;
  @override
  Future<List<LocalShell>> find() async => shells;
}

/// LineSender와 편집기의 자리 바꾸기 (`SenderPrefs.swapped`, 편집기 위쪽의 ⇆ 버튼).
void main() {
  late FakePtyFactory ptys;
  late SenderPrefs senderPrefs;

  setUp(() => ptys = FakePtyFactory());

  Future<SessionsController> pumpApp(WidgetTester tester, {Map<String, Object> initial = const {}}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues(initial);
    final sessions = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder([_bash]),
      ptyFactory: ptys.call,
    );
    await tester.runAsync(sessions.loadShells);
    final settings = await AppSettings.load();
    final prefs = await TerminalPrefs.load();
    senderPrefs = await SenderPrefs.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
          ChangeNotifierProvider<TerminalPrefs>.value(value: prefs),
          ChangeNotifierProvider<SenderPrefs>.value(value: senderPrefs),
        ],
        child: AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            home: HomeScreen(onAbout: () {}),
          ),
        ),
      ),
    );
    return sessions;
  }

  /// 터미널의 커서 깜박임 때문에 pumpAndSettle은 쓸 수 없다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openLocalTab(WidgetTester tester, {Map<String, Object> initial = const {}}) async {
    await pumpApp(tester, initial: initial);
    await tester.tap(find.byTooltip('새 연결'));
    await settle(tester);
    await tester.tap(find.ancestor(of: find.text('bash'), matching: find.byType(PopupMenuItem<Object>)));
    await settle(tester);
  }

  Rect rectOf(WidgetTester tester, Type type) => tester.getRect(find.byType(type));
  Finder senderField() => find.descendant(of: find.byType(LineSender), matching: find.byType(TextField));

  /// 보통 배치: LineSender는 터미널 바로 아래, 편집기는 오른쪽.
  void expectNormal(WidgetTester tester) {
    final terminal = rectOf(tester, TerminalPane);
    final sender = rectOf(tester, LineSender);
    final editor = rectOf(tester, RemoteEditorPane);
    expect(sender.top, greaterThanOrEqualTo(terminal.bottom));
    expect(sender.left, terminal.left);
    expect(editor.left, greaterThanOrEqualTo(terminal.right));
    expect(editor.left, greaterThanOrEqualTo(sender.right));
  }

  /// 바꾼 배치: 편집기가 터미널 바로 아래, LineSender가 오른쪽.
  void expectSwapped(WidgetTester tester) {
    final terminal = rectOf(tester, TerminalPane);
    final sender = rectOf(tester, LineSender);
    final editor = rectOf(tester, RemoteEditorPane);
    expect(editor.top, greaterThanOrEqualTo(terminal.bottom));
    expect(editor.left, terminal.left);
    expect(sender.left, greaterThanOrEqualTo(terminal.right));
    expect(sender.left, greaterThanOrEqualTo(editor.right));
  }

  testWidgets('the swap button moves the editor below the terminal and the sender to the right, keeping its text', (
    tester,
  ) async {
    await openLocalTab(tester);
    expectNormal(tester);

    await tester.enterText(senderField(), 'echo kept');
    await tester.pump();

    await tester.tap(find.byTooltip('편집기와 라인 전송기 자리 바꾸기'));
    await settle(tester);
    expect(senderPrefs.swapped, isTrue);
    expectSwapped(tester);
    expect(tester.widget<TextField>(senderField()).controller!.text, 'echo kept');
    expect(find.text('열린 파일이 없습니다'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('sender_editor_swapped'), isTrue);

    await tester.tap(find.byTooltip('편집기와 라인 전송기 자리 바꾸기'));
    await settle(tester);
    expect(senderPrefs.swapped, isFalse);
    expectNormal(tester);
    expect(tester.widget<TextField>(senderField()).controller!.text, 'echo kept');
  });

  testWidgets('the saved choice is used at start; collapsing the bottom editor leaves a bar that reopens it', (
    tester,
  ) async {
    await openLocalTab(tester, initial: {'sender_editor_swapped': true});
    expectSwapped(tester);

    await tester.tap(find.byTooltip('편집기 접기'));
    await settle(tester);
    expect(find.byType(RemoteEditorPane), findsNothing);
    final handle = tester.getRect(find.byType(RemoteEditorHandle));
    final terminal = rectOf(tester, TerminalPane);
    expect(handle.top, greaterThanOrEqualTo(terminal.bottom)); // 터미널 아래의 가로 손잡이
    expect(handle.width, greaterThan(handle.height));
    expect(rectOf(tester, LineSender).left, greaterThanOrEqualTo(terminal.right)); // LineSender는 오른쪽 그대로

    await tester.tap(find.byTooltip('편집'));
    await settle(tester);
    expectSwapped(tester);
  });

  testWidgets('the collapsed editor handle keeps the swap button, and swapping keeps it collapsed', (tester) async {
    await openLocalTab(tester);
    await tester.tap(find.byTooltip('편집기 접기'));
    await settle(tester);
    expect(find.byType(RemoteEditorPane), findsNothing);
    // 오른쪽 세로 손잡이에 ⇆ 버튼이 있다.
    var handle = tester.getRect(find.byType(RemoteEditorHandle));
    expect(handle.height, greaterThan(handle.width));
    expect(
      find.descendant(of: find.byType(RemoteEditorHandle), matching: find.byTooltip('편집기와 라인 전송기 자리 바꾸기')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('편집기와 라인 전송기 자리 바꾸기'));
    await settle(tester);
    expect(senderPrefs.swapped, isTrue);
    expect(find.byType(RemoteEditorPane), findsNothing); // 접힌 채로 자리만 바뀐다
    handle = tester.getRect(find.byType(RemoteEditorHandle));
    final terminal = rectOf(tester, TerminalPane);
    expect(handle.top, greaterThanOrEqualTo(terminal.bottom));
    expect(handle.width, greaterThan(handle.height));
    expect(rectOf(tester, LineSender).left, greaterThanOrEqualTo(terminal.right));

    // 아래 가로 손잡이에서도 되돌릴 수 있다.
    await tester.tap(find.byTooltip('편집기와 라인 전송기 자리 바꾸기'));
    await settle(tester);
    expect(senderPrefs.swapped, isFalse);
    handle = tester.getRect(find.byType(RemoteEditorHandle));
    expect(handle.height, greaterThan(handle.width));
    expect(rectOf(tester, LineSender).top, greaterThanOrEqualTo(rectOf(tester, TerminalPane).bottom));
  });

  testWidgets('each pane carries its own title, in both layouts', (tester) async {
    await openLocalTab(tester);
    for (var i = 0; i < 2; i++) {
      expect(find.descendant(of: find.byType(LineSender), matching: find.text('라인 전송기')), findsOneWidget);
      expect(find.descendant(of: find.byType(RemoteEditorPane), matching: find.text('편집기')), findsOneWidget);
      await tester.tap(find.byTooltip('편집기와 라인 전송기 자리 바꾸기'));
      await settle(tester);
    }
  });

  testWidgets('the settings reset puts them back', (tester) async {
    await openLocalTab(tester, initial: {'sender_editor_swapped': true});
    expectSwapped(tester);
    await senderPrefs.reset();
    await settle(tester);
    expectNormal(tester);
  });
}
