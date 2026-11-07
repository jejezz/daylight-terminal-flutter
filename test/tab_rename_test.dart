import 'dart:io';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/models/ssh_profile.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/services/tab_store.dart';
import 'package:daylight_terminal/settings/restore_prefs.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:daylight_terminal/utils/tab_label.dart';
import 'package:daylight_terminal/widgets/tab_bar_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_pty.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);
const _profile = SshProfile(id: 'p1', host: 'h', port: 22, username: 'u', keyPath: '', name: 'web-01', group: '');

class _FixedFinder extends LocalShellFinder {
  @override
  Future<List<LocalShell>> find() async => [_bash];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('custom title', () {
    test('is trimmed, empty means automatic, and only real changes notify', () async {
      final s = SshSessionProvider(await ProfileStore.load());
      var n = 0;
      s.addListener(() => n++);
      expect(s.customTitle, isNull);
      s.setCustomTitle('  build box  ');
      expect(s.customTitle, 'build box');
      expect(n, 1);
      s.setCustomTitle('build box');
      expect(n, 1);
      s.setCustomTitle('   ');
      expect(s.customTitle, isNull);
      expect(n, 2);
      s.dispose();
    });

    test('replaces the folder name on the tab but keeps the shell and the path line', () async {
      final tmp = await Directory.systemTemp.createTemp('dt_rn_');
      addTearDown(() => tmp.delete(recursive: true));
      final ptys = FakePtyFactory();
      final s = LocalShellSession(_bash, ptyFactory: ptys.call, startDirectory: tmp.path);
      addTearDown(s.dispose);
      await s.start();
      ptys.last.emit('\x1b]7;file://PC/home/me/app\x1b\\');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      List<TabLabel> labels() => TabLabels.compute([s], fallbackTitle: (x) => x.tabTitle);
      expect(labels().single.primary, 'app');
      s.setCustomTitle('api server');
      final l = labels().single;
      expect(l.primary, 'api server');
      expect(l.shell, 'bash');
      expect(l.secondary, '/home/me/app');
      s.setCustomTitle(null);
      expect(labels().single.primary, 'app');
    });

    test('is saved with the tabs and comes back after a restart', () async {
      final tmp = await Directory.systemTemp.createTemp('dt_rn2_');
      addTearDown(() => tmp.delete(recursive: true));
      final ptys = FakePtyFactory();
      Future<SessionsController> launch() async {
        final c = SessionsController(
          await ProfileStore.load(),
          shellFinder: _FixedFinder(),
          ptyFactory: ptys.call,
          tabStore: await TabStore.load(),
          restorePrefs: await RestorePrefs.load(),
        );
        await c.loadShells();
        await c.restoreTabs();
        return c;
      }

      final first = await launch();
      first.addLocal(_bash);
      (first.current! as LocalShellSession).setCustomTitle('logs');
      first.add();
      (first.current! as SshSessionProvider).prefill(_profile);
      first.current!.setCustomTitle('prod web');
      await first.prepareForExit();

      final second = await launch();
      expect(second.sessions.map((s) => s.customTitle), ['logs', 'prod web']);
      second.dispose();
    });

    test('SavedTabs ignores a missing or blank title', () {
      const tab = SavedLocalTab('bash', '/tmp');
      expect(tab.toJson().containsKey('title'), isFalse);
      expect(SavedTab.fromJson({'type': 'local', 'shell': 'bash', 'folder': '/tmp', 'title': '  '})!.title, isNull);
      expect(SavedTab.fromJson({'type': 'local', 'shell': 'bash', 'folder': '/tmp', 'title': ' x '})!.title, 'x');
    });
  });

  group('renaming from the tab bar', () {
    Future<(SessionsController, Finder)> pumpBar(WidgetTester tester) async {
      final c = SessionsController(await ProfileStore.load());
      addTearDown(c.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionsController>.value(
          value: c,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ko'),
            home: Scaffold(body: TabBarRow()),
          ),
        ),
      );
      return (c, find.byType(Draggable<int>).first);
    }

    testWidgets('right-click → Rename tab → type → OK; right-click → automatic name resets', (tester) async {
      final (c, tab) = await pumpBar(tester);
      await tester.tap(tab, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('자동 이름으로'), findsNothing); // 이름을 짓기 전에는 없다
      await tester.tap(find.text('탭 이름 바꾸기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  내 서버 ');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(c.current!.customTitle, '내 서버');
      expect(find.text('내 서버'), findsOneWidget);

      await tester.tap(find.byType(Draggable<int>).first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('자동 이름으로'));
      await tester.pumpAndSettle();
      expect(c.current!.customTitle, isNull);
    });

    testWidgets('double-click opens the rename dialog; a single click does not, and still selects at once', (tester) async {
      final (c, tab) = await pumpBar(tester);
      c.add();
      await tester.pump();
      c.select(1);
      await tester.pump();
      await tester.tap(find.byType(Draggable<int>).first);
      await tester.pump();
      expect(c.selected, 0, reason: '한 번 클릭은 바로 탭을 고른다');
      expect(find.text('탭 이름 바꾸기'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(Draggable<int>).first);
      await tester.pumpAndSettle();
      expect(find.text('탭 이름 바꾸기'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(c.sessions.first.customTitle, isNull);
      expect(tab, isNotNull);
    });
  });
}
