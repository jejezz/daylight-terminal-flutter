import 'dart:io';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/refresh_prefs.dart';

void main() {
  late Directory tmp;
  late SessionsController sessions;
  late RefreshPrefs refresh;
  late LocalShellSession a;
  late LocalShellSession b;

  setUp(() async {
    TerminalSession.autoRefreshEnabled = true;
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('dt_ar_');
    refresh = await RefreshPrefs.load();
    sessions = SessionsController(await ProfileStore.load(), refreshPrefs: refresh);
    const shell = LocalShell(id: 'x', name: 'x', executable: 'x', kind: ShellKind.posix);
    a = LocalShellSession(shell, startDirectory: tmp.path);
    b = LocalShellSession(shell, startDirectory: tmp.path);
    sessions.sessions
      ..clear()
      ..addAll([a, b]);
  });

  tearDown(() async {
    TerminalSession.autoRefreshEnabled = false;
    sessions.dispose();
    await tmp.delete(recursive: true);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 300));
  void touch(String name) => File('${tmp.path}${Platform.pathSeparator}$name').writeAsStringSync('x');

  test('a tab refreshes when it becomes active; an inactive tab does not', () async {
    sessions.select(1); // b 활성화 (a 비활성화)
    await settle();
    touch('new.txt');
    sessions.select(0); // a 활성화 → 바로 새로 고침
    await settle();
    expect(a.entries.map((e) => e.name), ['new.txt']);
    expect(b.entries, isEmpty); // 비활성 탭은 그대로
  });

  test('turning the local option off stops auto refresh', () async {
    await refresh.setLocal(false);
    sessions.select(1);
    sessions.select(0);
    await settle();
    touch('x.txt');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(a.entries, isEmpty);
    await refresh.setLocal(true); // 다시 켜면 바로 새로 고침
    await settle();
    expect(a.entries.map((e) => e.name), ['x.txt']);
  });

  test('the active tab refreshes every 5s and a manual refresh restarts the countdown', () async {
    sessions.select(1);
    sessions.select(0);
    await settle();
    touch('late.txt');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(a.entries, isEmpty); // 아직 5초 전
    await a.refreshFolder(); // 사용자가 새로 고침 → 타이머 초기화
    expect(a.entries.map((e) => e.name), ['late.txt']);
    touch('later.txt');
    await Future<void>.delayed(const Duration(seconds: 3)); // 처음 시작 기준이면 이미 울렸을 시점
    expect(a.entries.length, 1);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(a.entries.length, 2);
  });
}
