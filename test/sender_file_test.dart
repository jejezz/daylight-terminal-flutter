import 'dart:convert';
import 'dart:io';

import 'package:daylight_terminal/services/sender_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String path;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dt_sender_');
    path = p.join(tmp.path, 'script.txt');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<SenderFileError> failure(Future<Object?> Function() action) async {
    try {
      await action();
    } on SenderFileException catch (e) {
      return e.kind;
    }
    fail('expected a SenderFileException');
  }

  group('read', () {
    test('plain UTF-8 with LF', () async {
      File(path).writeAsStringSync('ls -l\ncd /tmp\n');
      final doc = await SenderFile.read(path);
      expect(doc.text, 'ls -l\ncd /tmp\n');
      expect(doc.eol, '\n');
    });

    test('CRLF files are shown with LF (the editor splits lines on LF) and remember CRLF', () async {
      File(path).writeAsBytesSync(utf8.encode('a\r\nb\r\nc'));
      final doc = await SenderFile.read(path);
      expect(doc.text, 'a\nb\nc');
      expect(doc.eol, '\r\n');
    });

    test('old Mac CR-only line breaks become LF', () async {
      File(path).writeAsBytesSync(utf8.encode('a\rb\rc'));
      expect((await SenderFile.read(path)).text, 'a\nb\nc');
    });

    test('a UTF-8 BOM (Notepad adds one) is not part of the text', () async {
      File(path).writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode('echo hi')]);
      expect((await SenderFile.read(path)).text, 'echo hi');
    });

    test('Korean text survives', () async {
      File(path).writeAsStringSync('echo 안녕하세요\n한글 폴더');
      expect((await SenderFile.read(path)).text, 'echo 안녕하세요\n한글 폴더');
    });

    test('an empty file is an empty script', () async {
      File(path).writeAsBytesSync([]);
      final doc = await SenderFile.read(path);
      expect(doc.text, '');
    });

    test('not UTF-8 (e.g. a CP949 or binary file) is refused instead of being shown garbled', () async {
      File(path).writeAsBytesSync([0xC7, 0xD1, 0xB1, 0xDB]); // "한글" in CP949
      expect(await failure(() => SenderFile.read(path)), SenderFileError.notUtf8);
    });

    test('too large is refused before reading it all', () async {
      File(path).writeAsBytesSync(List.filled(SenderFile.maxBytes + 1, 0x61));
      expect(await failure(() => SenderFile.read(path)), SenderFileError.tooLarge);
    });

    test('exactly the limit is allowed', () async {
      File(path).writeAsBytesSync(List.filled(SenderFile.maxBytes, 0x61));
      expect((await SenderFile.read(path)).text.length, SenderFile.maxBytes);
    });

    test('a missing file is an io error', () async {
      expect(await failure(() => SenderFile.read(p.join(tmp.path, 'nope.txt'))), SenderFileError.io);
    });
  });

  group('write', () {
    test('UTF-8 without BOM, LF by default', () async {
      await SenderFile.write(path, 'a\nb\n안녕');
      final bytes = File(path).readAsBytesSync();
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(utf8.decode(bytes), 'a\nb\n안녕');
    });

    test('writes CRLF when the file used CRLF — opening and saving a Windows script changes nothing else', () async {
      final original = utf8.encode('echo 1\r\necho 2\r\n');
      File(path).writeAsBytesSync(original);
      final doc = await SenderFile.read(path);
      await SenderFile.write(path, doc.text, eol: doc.eol);
      expect(File(path).readAsBytesSync(), original);
    });

    test('overwrites an existing file completely (a shorter script leaves no tail)', () async {
      File(path).writeAsStringSync('a long first version of the script\nwith two lines');
      await SenderFile.write(path, 'short');
      expect(File(path).readAsStringSync(), 'short');
    });

    test('an unwritable location is an io error', () async {
      expect(await failure(() => SenderFile.write(p.join(tmp.path, 'no-such-dir', 'x.txt'), 'a')), SenderFileError.io);
    });
  });
}
