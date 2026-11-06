import 'dart:io';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/utils/tab_label.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_pty.dart';

const _pwsh = LocalShell(id: 'pwsh', name: 'PowerShell 7', executable: 'pwsh.exe', kind: ShellKind.powershell);

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('TabLabels paths', () {
    test('displayPath turns the reported path into a readable one', () {
      expect(TabLabels.displayPath('/C:/Users/me'), r'C:\Users\me');
      expect(TabLabels.displayPath('/C:'), 'C:\\');
      expect(TabLabels.displayPath('/home/me'), '/home/me');
    });

    test('folderName: last folder, ~ for home, roots stay readable, depth adds the parent', () {
      expect(TabLabels.folderName(r'C:\Work\app'), 'app');
      expect(TabLabels.folderName(r'C:\Work\app', depth: 2), 'Work/app');
      expect(TabLabels.folderName(r'C:\Users\me', home: r'C:\Users\me'), '~');
      expect(TabLabels.folderName('c:\\users\\ME\\', home: r'C:\Users\me'), '~');
      expect(TabLabels.folderName('C:\\'), 'C:\\');
      expect(TabLabels.folderName('/'), '/');
    });
  });

  group('TabLabels.compute', () {
    late Directory tmp;
    late FakePtyFactory ptys;
    final sessions = <LocalShellSession>[];

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('dt_tl_');
      ptys = FakePtyFactory();
      sessions.clear();
    });
    tearDown(() async {
      for (final s in sessions) {
        s.dispose();
      }
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    Future<LocalShellSession> open(String? cwd) async {
      final s = LocalShellSession(_pwsh, ptyFactory: ptys.call, startDirectory: tmp.path);
      sessions.add(s);
      await s.start();
      if (cwd != null) {
        ptys.last.emit('\x1b]7;file://PC$cwd\x1b\\');
        await pump();
      }
      return s;
    }

    List<TabLabel> labels() => TabLabels.compute(sessions, fallbackTitle: (s) => s.tabTitle);

    test('folder first, shell name second; falls back to the shell name when the folder is unknown', () async {
      await open('/C:/Work/app');
      await open(null);
      final l = labels();
      expect(l[0].primary, 'app');
      expect(l[0].shell, 'pwsh');
      expect(l[0].secondary, r'C:\Work\app');
      expect(l[0].tooltip, contains(r'C:\Work\app'));
      expect(l[1].primary, 'PowerShell 7');
      expect(l[1].secondary, isNull);
    });

    test('same folder name in different places gets the parent folder', () async {
      await open('/C:/a/src');
      await open('/C:/b/src');
      await open('/C:/Work/other');
      final l = labels();
      expect(l[0].primary, 'a/src');
      expect(l[1].primary, 'b/src');
      expect(l[2].primary, 'other');
    });

    test('a running command replaces the shell name and is flagged running', () async {
      final s = await open('/C:/Work/app');
      ptys.last.emit('\x1b]633;E;flutter run\x1b\\\x1b]133;C\x1b\\');
      await pump();
      final running = labels().single;
      expect(running.running, isTrue);
      expect(running.secondary, 'flutter run');
      expect(running.tooltip, contains('flutter run'));

      ptys.last.emit('\x1b]133;D;1\x1b\\');
      await pump();
      final done = labels().single;
      expect(done.running, isFalse);
      expect(done.secondary, r'C:\Work\app');
      expect(done.exitCode, 1);
      expect(s.lastExitCode, 1);
    });
  });
}
