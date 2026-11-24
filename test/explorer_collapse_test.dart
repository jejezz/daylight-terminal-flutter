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
import 'package:daylight_terminal/widgets/local_folder_pane.dart';
import 'package:daylight_terminal/state/local_folder_session.dart';
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

/// 탐색기 접기/펼치기 (탐색기 헤더 맨 오른쪽 버튼, 접으면 왼쪽에 손잡이).
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
  testWidgets('the explorer collapses to a thin handle on the left and comes back, per tab', (tester) async {
    await openLocalTab(tester);
    final sessions = tester.element(find.byType(HomeScreen)).read<SessionsController>();
    final first = sessions.current! as LocalFolderSession;
    final terminalBefore = rectOf(tester, TerminalPane);
    expect(find.byType(LocalFolderPane), findsOneWidget);

    await tester.tap(find.byTooltip('탐색기 접기'));
    await settle(tester);
    expect(first.explorerVisible, isFalse);
    expect(find.byType(LocalFolderPane), findsNothing);
    final handle = tester.getRect(find.byType(ExplorerHandle));
    expect(handle.width, 36);
    expect(handle.right, lessThanOrEqualTo(rectOf(tester, TerminalPane).left));
    // 접은 만큼 터미널(과 라인 전송기)이 넓어진다.
    expect(rectOf(tester, TerminalPane).width, greaterThan(terminalBefore.width + 150));
    expect(rectOf(tester, LineSender).left, rectOf(tester, TerminalPane).left);

    // 다른 탭은 펼쳐진 채다.
    await tester.tap(find.byTooltip('새 연결'));
    await settle(tester);
    await tester.tap(find.ancestor(of: find.text('bash'), matching: find.byType(PopupMenuItem<Object>)).last);
    await settle(tester);
    expect(sessions.current, isNot(first));
    expect(find.byType(LocalFolderPane), findsOneWidget);
    sessions.select(sessions.sessions.indexOf(first));
    await settle(tester);
    expect(find.byType(LocalFolderPane), findsNothing);

    await tester.tap(find.byTooltip('탐색기 펼치기'));
    await settle(tester);
    expect(first.explorerVisible, isTrue);
    expect(find.byType(LocalFolderPane), findsOneWidget);
    expect(find.byType(ExplorerHandle), findsNothing);
    expect(rectOf(tester, TerminalPane).width, closeTo(terminalBefore.width, 1));
  });
}
