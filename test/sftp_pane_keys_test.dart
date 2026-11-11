import 'dart:convert';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/file_item.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/sftp_pane.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_remote_fs.dart';

void main() {
  late SshSessionProvider session;
  late FakeRemoteFs fs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = SshSessionProvider(await ProfileStore.load());
    fs = FakeRemoteFs()..put('/home/app.conf', utf8.encode('port=22\n'));
    session.debugRemoteFs = fs;
    session.debugSetListing('/home', const [
      FileItem(name: 'sub', isDirectory: true, isLink: false),
      FileItem(name: 'app.conf', isDirectory: false, isLink: false, size: 8),
    ]);
  });

  tearDown(() => session.dispose());

  /// 터미널처럼 자동으로 포커스를 가진 입력 칸이 옆에 있는 상태 — 실제 앱에서는 터미널이 포커스를 쥐고 있다.
  Future<void> pumpPane(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ChangeNotifierProvider<SshSessionProvider>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(width: 400, child: const SftpPane()),
                const Expanded(child: TextField(autofocus: true)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('F4 edits the selected file even though the terminal had the keyboard focus', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('app.conf'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester);

    expect(session.editor.documents.map((d) => d.path), ['/home/app.conf']);
  });

  testWidgets('F4 with only a folder selected does nothing', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('sub'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester);

    expect(session.editor.documents, isEmpty);
  });

  testWidgets('right-click → Edit opens the file', (tester) async {
    await pumpPane(tester);
    await tester.tap(find.text('app.conf'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await settle(tester);

    expect(session.editor.documents.map((d) => d.path), ['/home/app.conf']);
  });
}
