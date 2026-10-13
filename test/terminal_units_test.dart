import 'package:daylight_terminal/models/line_ending.dart';
import 'package:daylight_terminal/models/ssh_profile.dart';
import 'package:daylight_terminal/services/ansi_stripper.dart';
import 'package:daylight_terminal/services/log_file_service.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnsiStripper', () {
    test('removes colors, cursor moves and OSC sequences', () {
      final s = AnsiStripper();
      expect(s.strip('\x1B[31mred\x1B[0m \x1B[2K\x1B[1;5Hok'), 'red ok');
      expect(s.strip('\x1B]0;title\x07after'), 'after');
      expect(s.strip('\x1B]7;file://h/p\x1B\\x'), 'x');
    });

    test('holds back a sequence split across chunks', () {
      final s = AnsiStripper();
      expect(s.strip('a\x1B[3'), 'a');
      expect(s.strip('1mb'), 'b');
      expect(s.strip('c\x1B'), 'c');
      expect(s.strip(']0;t\x07d'), 'd');
    });

    test('keeps plain text and Korean untouched', () {
      expect(AnsiStripper().strip('안녕 hello\r\n'), '안녕 hello\r\n');
    });
  });

  test('LineEnding suffix; SSH default is CR', () {
    expect(LineEnding.cr.suffix, '\r');
    expect(LineEnding.crlf.suffix, '\r\n');
    expect(LineEnding.none.suffix, '');
    expect(LineEnding.none.label, isNull);
  });

  test('LogFileService.suggestedFileName is filesystem-safe', () {
    final name = LogFileService.suggestedFileName('my host:22/x', DateTime(2026, 10, 13, 9, 5, 7));
    expect(name, 'my_host_22_x_20261013_090507.log');
  });

  group('ProfileStore', () {
    test('saves, updates, deletes profiles without secrets', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProfileStore.load();
      const p = SshProfile(id: 'a', host: 'h', port: 2200, username: 'u', keyPath: '/k');
      await store.saveProfile(p);
      await store.saveProfile(p.copyWith(host: 'h2'));
      final list = store.profiles();
      expect(list, hasLength(1));
      expect(list.single.host, 'h2');
      expect(list.single.label, 'u@h2:2200');
      expect(p.toJson().keys, isNot(contains('password')));
      await store.deleteProfile('a');
      expect(store.profiles(), isEmpty);
    });

    test('remembers host keys per host:port', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProfileStore.load();
      expect(store.knownHostKey('h', 22), isNull);
      await store.trustHostKey('h', 22, 'ssh-ed25519 aa');
      expect(store.knownHostKey('h', 22), 'ssh-ed25519 aa');
      expect(store.knownHostKey('h', 2222), isNull);
    });

    test('ignores corrupt stored data', () async {
      SharedPreferences.setMockInitialValues({'ssh_profiles': '{not json', 'ssh_known_hosts': '[]'});
      final store = await ProfileStore.load();
      expect(store.profiles(), isEmpty);
      expect(store.knownHostKey('h', 22), isNull);
    });
  });
}
