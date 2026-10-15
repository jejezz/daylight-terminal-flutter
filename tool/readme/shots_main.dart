// ignore_for_file: invalid_use_of_visible_for_testing_member, use_build_context_synchronously
// README 스크린샷용 하니스 (tool/readme/capture.sh의 수동 클릭을 대신한다). 실제 앱(App)을 그대로 띄우고, 데모 SSH 서버에
// 접속해 명령을 치고, 창을 screencapture로 찍은 뒤 끝난다. 사용자의 실제 설정은 건드리지 않는다(메모리 전용 SharedPreferences).
//
//   python3 <demo_server.py> 2299 <home>      # 데모 서버 (사용자 demo / 비밀번호 demo)
//   flutter run -d macos --release -t tool/readme/shots_main.dart
//
// 결과: docs/screenshots/raw/{home,detail}-{light,dark}.png  →  frame.py --split 으로 합친다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daylight_terminal/main.dart' show App;
import 'package:daylight_terminal/models/ssh_profile.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/refresh_prefs.dart';
import 'package:daylight_terminal/settings/restore_prefs.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:daylight_terminal/widgets/address_book_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const _port = int.fromEnvironment('DEMO_PORT', defaultValue: 2299);
const _root = String.fromEnvironment('REPO_ROOT');
const _gif = bool.fromEnvironment('GIF');
const _uploadFile = String.fromEnvironment('UPLOAD_FILE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'theme_mode': 'light',
    'app_locale': 'en',
    'ssh_profiles': jsonEncode([
      for (final p in _profiles) p.toJson(),
    ]),
  });
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1200, 720), center: true, title: 'Daylight Terminal'),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final settings = await AppSettings.load();
  final terminalPrefs = await TerminalPrefs.load();
  final refreshPrefs = await RefreshPrefs.load();
  final sessions = SessionsController(
    await ProfileStore.load(),
    scrollback: () => terminalPrefs.scrollback,
    refreshPrefs: refreshPrefs,
  );
  runApp(
    App(
      settings: settings,
      sessions: sessions,
      terminalPrefs: terminalPrefs,
      refreshPrefs: refreshPrefs,
      restorePrefs: await RestorePrefs.load(),
    ),
  );
  unawaited((_gif ? _gifScript(sessions, settings) : _script(sessions, settings)).whenComplete(() => exit(0)));
}

final _profiles = [
  const SshProfile(
    id: 'a1', host: '127.0.0.1', port: _port, username: 'demo',
    name: 'web-01', group: 'Production', note: 'nginx + API',
  ),
  const SshProfile(
    id: 'a3', host: 'db.example.com', port: 22, username: 'postgres',
    name: 'db-primary', group: 'Production', note: 'PostgreSQL 16',
  ),
  const SshProfile(
    id: 'a4', host: 'staging.example.com', port: 2222, username: 'ubuntu',
    name: 'staging', group: 'Staging', note: 'resets nightly',
  ),
  const SshProfile(
    id: 'a5', host: '192.168.1.50', port: 22, username: 'pi',
    name: 'raspberry-pi', group: 'Home lab', note: 'Pi-hole',
  ),
  const SshProfile(
    id: 'a6', host: '192.168.1.60', port: 22, username: 'admin',
    name: 'nas', group: 'Home lab', note: 'backups',
  ),
];

Future<void> _wait(double seconds) => Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

Future<void> _script(SessionsController sessions, AppSettings settings) async {
  await _wait(2);
  final window = (await Process.run('swift', ['$_root/tool/readme/find_window.swift', 'Daylight Terminal']))
      .stdout
      .toString()
      .trim()
      .split(' ')
      .first;
  Future<void> shot(String name) async {
    await _wait(0.8);
    final r = await Process.run('screencapture', ['-x', '-o', '-l$window', '$_root/docs/screenshots/raw/$name.png']);
    stdout.writeln('shot $name exit=${r.exitCode} ${r.stderr}');
  }

  await Directory('$_root/docs/screenshots/raw').create(recursive: true);

  final ssh = sessions.current as SshSessionProvider;
  await ssh.connect(_profiles.first, password: 'demo');
  await _wait(2);
  for (final cmd in ['uptime', 'ls -lh', 'tail -n 4 logs/app.log']) {
    ssh.typeCommand('$cmd\r');
    await _wait(1);
  }
  await _wait(1);
  stdout.writeln('status=${ssh.status} entries=${ssh.entries.length}');

  await shot('home-light');
  await settings.setThemeMode(ThemeMode.dark);
  await _wait(1);
  await shot('home-dark');

  BuildContext? context;
  void visit(Element e) {
    if (e.widget is HomeScreen) {
      context = e;
    } else {
      e.visitChildren(visit);
    }
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  unawaited(showAddressBook(context!));
  await _wait(1.5);
  await shot('detail-dark');
  Navigator.of(context!).pop();
  await _wait(0.5);
  await settings.setThemeMode(ThemeMode.light);
  await _wait(1);
  unawaited(showAddressBook(context!));
  await _wait(1.5);
  await shot('detail-light');
}

Future<void> _type(SshSessionProvider ssh, String cmd) async {
  for (final c in cmd.split('')) {
    ssh.typeCommand(c);
    await _wait(0.06);
  }
  await _wait(0.4);
  ssh.typeCommand('\r');
}

/// demo.gif: 접속 화면 → 주소록 → 접속 → 명령 → 업로드. 창 영역을 screencapture -v로 녹화한다.
Future<void> _gifScript(SessionsController sessions, AppSettings settings) async {
  await _wait(2);
  final f = (await Process.run('swift', ['$_root/tool/readme/find_window.swift', 'Daylight Terminal']))
      .stdout.toString().trim().split(' ');
  await Directory('$_root/docs/screenshots/raw').create(recursive: true);
  final rec = await Process.start('screencapture',
      ['-x', '-v', '-V22', '-R${f[1]},${f[2]},${f[3]},${f[4]}', '$_root/docs/screenshots/raw/demo.mov']);
  await _wait(2.5);

  BuildContext? context;
  void visit(Element e) {
    if (e.widget is HomeScreen) {
      context = e;
    } else {
      e.visitChildren(visit);
    }
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  unawaited(showAddressBook(context!));
  await _wait(2.5);
  Navigator.of(context!).pop();
  final ssh = sessions.current as SshSessionProvider;
  await ssh.connect(_profiles.first, password: 'demo');
  await _wait(2);
  await _type(ssh, 'ls -lh logs');
  await _wait(1.5);
  await _type(ssh, 'tail -n 3 logs/app.log');
  await _wait(2);
  await ssh.upload([_uploadFile]);
  await _wait(1.5);
  await _type(ssh, 'ls -lh');
  await _wait(3);
  await rec.exitCode;
}
