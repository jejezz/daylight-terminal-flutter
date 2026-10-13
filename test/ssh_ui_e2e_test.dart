// 수동 통합 테스트: 실제 화면(탭, 접속 폼, 탐색기, 터미널, LineSender, 상태 바)을 실제 SSH 서버에 붙여 본다.
// ssh_e2e_test.dart와 같은 환경 변수가 필요하고, 없으면 건너뛴다.
import 'dart:io';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/remote_entry.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:daylight_terminal/widgets/sftp_pane.dart';
import 'package:daylight_terminal/widgets/status_bar.dart';
import 'package:daylight_terminal/widgets/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final port = Platform.environment['TEST_SSH_PORT'];
  final password = Platform.environment['TEST_SSH_PASSWORD'];
  final skip = port == null || password == null ? 'TEST_SSH_PORT / TEST_SSH_PASSWORD 없음' : null;

  Future<SessionsController> pumpApp(WidgetTester tester, {Size size = const Size(1200, 720)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionsController(await ProfileStore.load());
    final settings = await AppSettings.load();
    final terminalPrefs = await TerminalPrefs.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
          ChangeNotifierProvider<TerminalPrefs>.value(value: terminalPrefs),
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

  testWidgets('connect form -> split view with explorer, terminal, sender, status bar', (tester) async {
    final sessions = await pumpApp(tester);
    expect(find.text('서버에 연결'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '호스트'), '127.0.0.1');
    await tester.enterText(find.widgetWithText(TextField, '포트'), port!);
    await tester.enterText(find.widgetWithText(TextField, '사용자'), 'tester');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), password!);
    await tester.pump();
    // 실제 소켓 I/O는 가짜 시계 밖에서 돌아야 하므로 탭부터 runAsync 안에서 한다.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, '연결'));
      final end = DateTime.now().add(const Duration(seconds: 8));
      while (!sessions.current!.connected && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sessions.current!.connected, isTrue);
    expect(find.byType(SftpPane), findsOneWidget);
    expect(find.byType(TerminalPane), findsOneWidget);
    expect(find.byType(LineSender), findsOneWidget);
    expect(find.byType(StatusBar), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
    // 항목은 끌어내기(드래그 아웃)를 위해 Draggable이다.
    expect(find.byType(Draggable<List<RemoteEntry>>), findsWidgets);
    expect(find.text('tester@127.0.0.1:$port'), findsWidgets);

    // 패널 크기를 줄여도 오버플로가 나지 않는다.
    tester.view.physicalSize = const Size(960, 600);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 저장된 접속 정보에 비밀번호가 없다.
    final saved = sessions.store.profiles().single;
    expect(saved.toJson().toString(), isNot(contains(password)));

    // 새 탭 → 접속 폼, 원래 탭은 살아 있다.
    sessions.add();
    await tester.pump();
    expect(find.text('서버에 연결'), findsOneWidget);
    sessions.select(0);
    await tester.pump();
    expect(find.byType(SftpPane), findsOneWidget);

    await tester.runAsync(() async {
      await sessions.current!.disconnect();
      sessions.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
  }, skip: skip != null);
}
