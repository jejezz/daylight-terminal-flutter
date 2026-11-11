import 'dart:convert';
import 'dart:typed_data';

import 'package:daylight_terminal/services/remote_text_file.dart';
import 'package:daylight_terminal/services/sender_file.dart';
import 'package:daylight_terminal/state/remote_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_remote_fs.dart';

void main() {
  late FakeRemoteFs fs;

  setUp(() => fs = FakeRemoteFs());

  Future<RemoteEditError> openFailure(String path) async {
    try {
      await RemoteText.open(fs, path);
    } on RemoteEditException catch (e) {
      return e.kind;
    }
    fail('expected a RemoteEditException');
  }

  group('SenderFile.decode/encode', () {
    test('round trip keeps CRLF and BOM', () {
      final bytes = utf8.encode('a\r\nb\r\n안녕');
      final doc = SenderFile.decode(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes]));
      expect(doc.text, 'a\nb\n안녕');
      expect(doc.eol, '\r\n');
      expect(doc.bom, isTrue);
      expect(SenderFile.encode(doc), [0xEF, 0xBB, 0xBF, ...bytes]);
    });

    test('no BOM and a final newline come back unchanged', () {
      final bytes = utf8.encode('x=1\ny=2\n');
      expect(SenderFile.encode(SenderFile.decode(Uint8List.fromList(bytes))), bytes);
    });

    test('NUL bytes are rejected only when asked', () {
      final bytes = Uint8List.fromList([0x61, 0, 0x62]);
      expect(SenderFile.decode(bytes).text.length, 3);
      expect(
        () => SenderFile.decode(bytes, rejectBinary: true),
        throwsA(isA<SenderFileException>().having((e) => e.kind, 'kind', SenderFileError.binary)),
      );
    });
  });

  group('open', () {
    test('reads text, remembers the server state', () async {
      fs.put('/etc/app.conf', utf8.encode('a=1\r\nb=2\r\n'));
      final file = await RemoteText.open(fs, '/etc/app.conf');
      expect(file.document.text, 'a=1\nb=2\n');
      expect(file.document.eol, '\r\n');
      expect(file.stat.size, 10);
    });

    test('follows a symbolic link to the real path', () async {
      fs.put('/real.txt', utf8.encode('hi'));
      fs.links['/link.txt'] = '/real.txt';
      expect((await RemoteText.open(fs, '/link.txt')).path, '/real.txt');
    });

    test('refuses folders, missing files, binaries, big files and non-UTF-8', () async {
      expect(await openFailure('/'), RemoteEditError.notRegular);
      expect(await openFailure('/nope'), RemoteEditError.notFound);
      fs.put('/bin', [0x7f, 0x45, 0, 0x4c]);
      expect(await openFailure('/bin'), RemoteEditError.binary);
      fs.put('/big', List.filled(SenderFile.maxBytes + 1, 0x61));
      expect(await openFailure('/big'), RemoteEditError.tooLarge);
      fs.put('/latin', [0xE9, 0x20, 0x61]); // Latin-1 'é': UTF-8도 CP949도 아니다 (0xE9 0xE8은 CP949의 한 글자다)
      expect(await openFailure('/latin'), RemoteEditError.notUtf8);
    });

    test('a big file is refused before its content is downloaded', () async {
      fs.put('/big', List.filled(SenderFile.maxBytes + 1, 0x61));
      await openFailure('/big');
      expect(fs.log.where((l) => l.startsWith('read')), isEmpty);
    });
  });

  group('save', () {
    Future<RemoteTextFile> openIt(String content, {int mode = 420}) async {
      fs.put('/f.conf', utf8.encode(content), mode: mode);
      return RemoteText.open(fs, '/f.conf');
    }

    test('writes through a temp file, keeps mode and owner, leaves no temp behind', () async {
      final file = await openIt('a\n', mode: 384);
      final result = await RemoteText.save(fs, file, const SenderDocument('b\n', '\n'));
      expect(result.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/f.conf']!), 'b\n');
      expect(fs.stats['/f.conf']!.mode, 384);
      expect(fs.files.keys.where((k) => k.endsWith('.tmp')), isEmpty);
      expect(fs.log.any((l) => l.startsWith('rename')), isTrue);
    });

    test('restores CRLF and BOM when saving', () async {
      fs.put('/w.txt', [0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\n')]);
      final file = await RemoteText.open(fs, '/w.txt');
      await RemoteText.save(fs, file, SenderDocument('a\nb\n', file.document.eol, bom: file.document.bom));
      expect(fs.files['/w.txt'], [0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb\r\n')]);
    });

    test('a change made on the server meanwhile is a conflict and nothing is written', () async {
      final file = await openIt('a\n');
      fs.touchExternally('/f.conf', utf8.encode('someone else\n'));
      final result = await RemoteText.save(fs, file, const SenderDocument('mine\n', '\n'));
      expect(result.status, RemoteSaveStatus.conflict);
      expect(utf8.decode(fs.files['/f.conf']!), 'someone else\n');
      expect(fs.log.where((l) => l.startsWith('write')), isEmpty);
    });

    test('a file deleted on the server is a conflict; overwrite recreates it', () async {
      final file = await openIt('a\n');
      fs.files.remove('/f.conf');
      fs.stats.remove('/f.conf');
      expect((await RemoteText.save(fs, file, const SenderDocument('b\n', '\n'))).status, RemoteSaveStatus.conflict);
      final forced = await RemoteText.save(fs, file, const SenderDocument('b\n', '\n'), overwrite: true);
      expect(forced.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/f.conf']!), 'b\n');
    });

    test('overwrite ignores the conflict', () async {
      final file = await openIt('a\n');
      fs.touchExternally('/f.conf', utf8.encode('other\n'));
      final result = await RemoteText.save(fs, file, const SenderDocument('mine\n', '\n'), overwrite: true);
      expect(result.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/f.conf']!), 'mine\n');
    });

    test('writes in place when the folder does not allow a new file', () async {
      final file = await openIt('a\n');
      fs.dirReadOnly = true;
      final result = await RemoteText.save(fs, file, const SenderDocument('b\n', '\n'));
      expect(result.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/f.conf']!), 'b\n');
    });

    test('backup keeps the previous content', () async {
      final file = await openIt('old\n');
      await RemoteText.save(fs, file, const SenderDocument('new\n', '\n'), backup: true);
      expect(utf8.decode(fs.files['/f.conf.bak']!), 'old\n');
      expect(utf8.decode(fs.files['/f.conf']!), 'new\n');
    });

    test('a failed write is reported and the original stays', () async {
      final file = await openIt('a\n');
      final failing = _FailingWrites(fs);
      await expectLater(
        RemoteText.save(failing, file, const SenderDocument('b\n', '\n')),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.io)),
      );
      expect(utf8.decode(fs.files['/f.conf']!), 'a\n');
    });
  });

  group('RemoteEditorController', () {
    test('opens a file once, tracks changes, saves and closes', () async {
      fs.put('/a.txt', utf8.encode('one\n'));
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/a.txt');
      expect(c.visible, isTrue);
      expect(identical(await c.open('/a.txt'), doc), isTrue);
      expect(c.documents.length, 1);

      doc.text.text = 'two\n';
      expect(doc.modified, isTrue);
      expect(c.hasUnsaved, isTrue);

      final result = await c.save(doc);
      expect(result.status, RemoteSaveStatus.saved);
      expect(doc.modified, isFalse);
      expect(utf8.decode(fs.files['/a.txt']!), 'two\n');

      c.close(doc);
      expect(c.documents, isEmpty);
      expect(c.visible, isTrue);
      c.dispose();
    });

    test('opening again does not overwrite what the user is typing', () async {
      fs.put('/a.txt', utf8.encode('one\n'));
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/a.txt');
      doc.text.text = 'typing\n';
      await c.open('/a.txt');
      expect(doc.text.text, 'typing\n');
      c.dispose();
    });

    test('conflict flags the document; reload takes the server version', () async {
      fs.put('/a.txt', utf8.encode('one\n'));
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/a.txt');
      doc.text.text = 'mine\n';
      fs.touchExternally('/a.txt', utf8.encode('theirs\n'));
      expect((await c.save(doc)).status, RemoteSaveStatus.conflict);
      expect(doc.conflict, isTrue);
      expect(doc.modified, isTrue);

      await c.reload(doc);
      expect(doc.text.text, 'theirs\n');
      expect(doc.modified, isFalse);
      expect(doc.conflict, isFalse);
      c.dispose();
    });

    test('hiding keeps the open files', () async {
      fs.put('/a.txt', utf8.encode('x'));
      final c = RemoteEditorController(() => fs);
      await c.open('/a.txt');
      c.setVisible(false);
      expect(c.visible, isFalse);
      expect(c.documents.length, 1);
      c.setVisible(true);
      expect(c.visible, isTrue);
      c.dispose();
    });

    test('without a connection nothing opens', () async {
      final c = RemoteEditorController(() => null);
      await expectLater(c.open('/a.txt'), throwsA(isA<RemoteEditException>()));
      c.dispose();
    });
  });
}

/// 쓰기가 모두 실패하는 [RemoteFs] (읽기·확인은 [inner]에 맡긴다).
class _FailingWrites implements RemoteFs {
  _FailingWrites(this.inner);

  final FakeRemoteFs inner;

  @override
  p.Context get pathContext => inner.pathContext;
  @override
  bool get writeInPlace => inner.writeInPlace;
  @override
  Future<String> resolve(String path) => inner.resolve(path);
  @override
  Future<RemoteStat> stat(String path) => inner.stat(path);
  @override
  Future<Uint8List> read(String path) => inner.read(path);
  @override
  Future<void> write(String path, Uint8List data) async => throw StateError('disk full');
  @override
  Future<void> rename(String from, String to) => inner.rename(from, to);
  @override
  Future<void> remove(String path) => inner.remove(path);
  @override
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid}) =>
      inner.setAttrs(path, mode: mode, uid: uid, gid: gid);
}
