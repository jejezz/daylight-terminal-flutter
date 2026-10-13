import 'dart:io';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:daylight_terminal/widgets/local_folder_pane.dart';
import 'package:daylight_terminal/widgets/sftp_pane.dart';
import 'package:daylight_terminal/widgets/status_bar.dart';
import 'package:daylight_terminal/widgets/terminal_pane.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_pty.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);
const _cmd = LocalShell(id: 'cmd', name: 'Command Prompt', executable: 'cmd.exe', kind: ShellKind.cmd);

class _FixedFinder extends LocalShellFinder {
  _FixedFinder(this.shells);
  final List<LocalShell> shells;
  @override
  Future<List<LocalShell>> find() async => shells;
}

void main() {
  late FakePtyFactory ptys;
  late Directory tmp;

  setUp(() async {
    ptys = FakePtyFactory();
    tmp = await Directory.systemTemp.createTemp('dt_ui_');
    File('${tmp.path}${Platform.pathSeparator}notes.txt').writeAsStringSync('hi');
    Directory('${tmp.path}${Platform.pathSeparator}projects').createSync();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<SessionsController> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder([_bash, _cmd]),
      ptyFactory: ptys.call,
    );
    await tester.runAsync(sessions.loadShells);
    final settings = await AppSettings.load();
    final prefs = await TerminalPrefs.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
          ChangeNotifierProvider<TerminalPrefs>.value(value: prefs),
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

  /// 메뉴가 다 열릴(또는 닫힐) 때까지 기다린다. 터미널의 커서 깜박임 때문에 pumpAndSettle은 쓸 수 없다.
  Future<void> settleMenu(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 새 탭 메뉴(+)에서 [label]을 고른다.
  Future<void> openFromPlusMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('새 연결'));
    await settleMenu(tester);
    final item = find.ancestor(of: find.text(label), matching: find.byType(PopupMenuItem<Object>));
    await tester.tap(item);
    await settleMenu(tester);
  }

  /// 새로 연 로컬 탭이 이 테스트의 임시 폴더를 보게 하고 화면에 반영한다.
  Future<LocalShellSession> pointAtTmp(WidgetTester tester, SessionsController sessions) async {
    final local = sessions.current! as LocalShellSession;
    await tester.runAsync(() => local.loadFolder(tmp.path));
    await tester.pump(const Duration(milliseconds: 100));
    return local;
  }

  testWidgets('the + menu offers SSH and every local shell, with the default shell marked by a shortcut', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('새 연결'));
    await settleMenu(tester);
    expect(find.text('SSH 연결'), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('Command Prompt'), findsOneWidget);
    expect(find.textContaining('Ctrl+Shift+L'), findsOneWidget); // 기본 셸(첫 번째)에만
  });

  testWidgets('a local tab shows THIS PC\'s folder (not SFTP) next to a terminal, sender and status bar', (
    tester,
  ) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await pointAtTmp(tester, sessions);

    expect(sessions.sessions, hasLength(2));
    expect(ptys.made, hasLength(1));
    expect(find.byType(LocalFolderPane), findsOneWidget);
    expect(find.byType(SftpPane), findsNothing); // 이 탭에는 서버가 없다
    expect(find.byType(TerminalPane), findsOneWidget);
    expect(find.byType(LineSender), findsOneWidget);
    expect(find.byType(StatusBar), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('projects'), findsOneWidget);
    expect(find.text('서버에 연결'), findsNothing); // 접속 폼 없이 바로 셸

    // 폴더가 위, 파일이 아래
    expect(tester.getTopLeft(find.text('projects')).dy, lessThan(tester.getTopLeft(find.text('notes.txt')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the LineSender types into the local shell', (tester) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await tester.enterText(find.descendant(of: find.byType(LineSender), matching: find.byType(TextField)), 'echo hi');
    await tester.tap(find.byTooltip('현재 줄 전송'));
    await tester.pump();
    expect(ptys.last.writtenText, 'echo hi\r');
    expect(sessions.current!.connected, isTrue);
  });

  testWidgets('path menu on a bash tab has both items; on a cmd tab "explorer → terminal" is hidden', (tester) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await pointAtTmp(tester, sessions);
    await tester.tap(find.byTooltip('경로 이동'));
    await settleMenu(tester);
    expect(find.text('터미널을 이 폴더로 이동'), findsOneWidget);
    expect(find.text('탐색기를 터미널 경로로 이동'), findsOneWidget);
    // "터미널을 이 폴더로"는 셸에 cd를 입력한다 — 눌렀을 때만.
    expect(ptys.last.writtenText, isEmpty);
    await tester.tap(find.text('터미널을 이 폴더로 이동'));
    await settleMenu(tester);
    expect(ptys.last.writtenText, " cd -- '${tmp.path}'\r");

    await openFromPlusMenu(tester, 'Command Prompt');
    await pointAtTmp(tester, sessions);
    await tester.tap(find.byTooltip('경로 이동'));
    await settleMenu(tester);
    expect(find.text('터미널을 이 폴더로 이동'), findsOneWidget);
    expect(find.text('탐색기를 터미널 경로로 이동'), findsNothing); // cmd는 현재 경로를 알려 줄 수 없다
  });

  testWidgets('right-click menu: open, show in file manager, move terminal here, rename, delete', (tester) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await pointAtTmp(tester, sessions);

    await tester.tap(find.text('projects'), buttons: kSecondaryButton);
    await settleMenu(tester);
    expect(find.text('열기'), findsOneWidget);
    expect(find.text('파일 관리자에서 보기'), findsOneWidget);
    expect(find.text('터미널을 이 폴더로 이동'), findsOneWidget);
    expect(find.text('이름 바꾸기'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // 닫기
    await settleMenu(tester);

    // 파일에는 "터미널을 이 폴더로"가 없다
    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await settleMenu(tester);
    expect(find.text('터미널을 이 폴더로 이동'), findsNothing);
    expect(find.text('열기'), findsOneWidget);
  });

  testWidgets('double-clicking a folder enters it; up goes back; nothing is typed into the shell', (tester) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    final local = await pointAtTmp(tester, sessions);

    await tester.runAsync(() => local.openEntry(local.entries.firstWhere((e) => e.name == 'projects')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('비어 있는 폴더입니다'), findsOneWidget);
    await tester.runAsync(local.goUp);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('notes.txt'), findsOneWidget);
    expect(ptys.last.written, isEmpty, reason: '폴더 뷰를 옮겨도 터미널은 따라가지 않는다');
  });

  testWidgets('when the shell exits a banner appears with the code; Restart brings it back', (tester) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await pointAtTmp(tester, sessions);
    expect(find.textContaining('셸이 종료되었습니다'), findsNothing);

    await tester.runAsync(() async {
      ptys.last.finish(7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('셸이 종료되었습니다 (종료 코드 7)'), findsOneWidget);
    expect(find.byType(LocalFolderPane), findsOneWidget); // 탭과 폴더 뷰는 그대로

    await tester.tap(find.text('다시 시작'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ptys.made, hasLength(2));
    expect(find.textContaining('셸이 종료되었습니다'), findsNothing);
  });

  testWidgets('a shell that cannot start shows the error and a Restart button', (tester) async {
    ptys.failWith = StateError('no such executable');
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await tester.pump(const Duration(milliseconds: 100));
    expect(sessions.current!.connected, isFalse);
    expect(find.textContaining('셸을 시작하지 못했습니다'), findsOneWidget);
    expect(find.textContaining('no such executable'), findsOneWidget);
    expect(find.text('다시 시작'), findsOneWidget);
  });

  testWidgets('the app bar button ends the shell on a local tab (and says so), and disappears afterwards', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byTooltip('연결 끊기'), findsNothing); // 아직 연결 없는 SSH 탭
    await openFromPlusMenu(tester, 'bash');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('셸 종료'), findsOneWidget);
    expect(find.byTooltip('연결 끊기'), findsNothing);

    await tester.tap(find.byTooltip('셸 종료'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ptys.last.killed, isTrue);
    expect(find.byTooltip('셸 종료'), findsNothing);
  });

  testWidgets('tabs: closing a local tab kills its shell; the SSH tab is untouched; two shells can run at once', (
    tester,
  ) async {
    final sessions = await pumpApp(tester);
    await openFromPlusMenu(tester, 'bash');
    await openFromPlusMenu(tester, 'bash');
    expect(ptys.made, hasLength(2));
    expect(sessions.sessions, hasLength(3));

    sessions.closeAt(2);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ptys.made[1].killed, isTrue);
    expect(ptys.made[0].killed, isFalse);
    expect(sessions.sessions, hasLength(2));
  });

  testWidgets('the default-shell shortcut opens a local tab; with no shells found it does nothing', (tester) async {
    final sessions = await pumpApp(tester);
    expect(sessions.addLocal(), isNotNull);
    expect(ptys.made, hasLength(1));
    expect((sessions.current! as LocalShellSession).shell.id, 'bash');

    SharedPreferences.setMockInitialValues({});
    final empty = SessionsController(await ProfileStore.load(), shellFinder: _FixedFinder(const []));
    await empty.loadShells();
    expect(empty.addLocal(), isNull);
    expect(empty.sessions, hasLength(1));
    empty.dispose();
  });
}
