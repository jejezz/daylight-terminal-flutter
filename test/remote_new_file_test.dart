import 'dart:convert';

import 'package:daylight_terminal/services/remote_text_file.dart';
import 'package:daylight_terminal/services/sender_file.dart';
import 'package:daylight_terminal/state/remote_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_remote_fs.dart';

void main() {
  late FakeRemoteFs fs;

  setUp(() => fs = FakeRemoteFs());

  group('RemoteText.saveNew', () {
    test('creates a file that does not exist', () async {
      final result = await RemoteText.saveNew(fs, '/new.sh', const SenderDocument('echo hi\n', '\n'));
      expect(result.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/new.sh']!), 'echo hi\n');
    });

    test('an existing file is a conflict until overwrite is allowed', () async {
      fs.put('/a.txt', utf8.encode('old'));
      expect(
        (await RemoteText.saveNew(fs, '/a.txt', const SenderDocument('new', '\n'))).status,
        RemoteSaveStatus.conflict,
      );
      expect(utf8.decode(fs.files['/a.txt']!), 'old');
      final forced = await RemoteText.saveNew(fs, '/a.txt', const SenderDocument('new', '\n'), overwrite: true);
      expect(forced.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/a.txt']!), 'new');
    });

    test('a folder in the way is refused; a missing parent folder is an io error', () async {
      fs.dirs.add('/etc');
      await expectLater(
        RemoteText.saveNew(fs, '/etc', const SenderDocument('x', '\n')),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.notRegular)),
      );
      fs.strictDirs = true;
      await expectLater(
        RemoteText.saveNew(fs, '/nope/x.txt', const SenderDocument('x', '\n')),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.io)),
      );
    });
  });

  group('RemoteEditorController new files', () {
    test('the editor is visible even with no file, and stays visible after the last file is closed', () async {
      final c = RemoteEditorController(() => fs);
      expect(c.visible, isTrue);
      expect(c.documents, isEmpty);
      final doc = c.newDocument();
      c.close(doc);
      expect(c.visible, isTrue);
      c.dispose();
    });

    test('a new file is untitled, numbered, and modified once it has text', () {
      final c = RemoteEditorController(() => fs);
      final a = c.newDocument();
      final b = c.newDocument();
      expect(a.isNew, isTrue);
      expect(a.path, isNull);
      expect([a.number, b.number], [1, 2]);
      expect(a.modified, isFalse);
      a.text.text = 'echo hi';
      expect(a.modified, isTrue);
      expect(c.current, b);
      c.dispose();
    });

    test('saveAs writes the file to the server and the document becomes that file', () async {
      final c = RemoteEditorController(() => fs, directory: () => '/home/me');
      expect(c.suggestedDirectory, '/home/me');
      final doc = c.newDocument();
      doc.text.text = '#!/bin/bash\necho hi\n';
      final result = await c.saveAs(doc, '/home/me/run.sh');
      expect(result.status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/home/me/run.sh']!), '#!/bin/bash\necho hi\n');
      expect(doc.path, '/home/me/run.sh');
      expect(doc.isNew, isFalse);
      expect(doc.modified, isFalse);
      expect(doc.text.fileName, 'run.sh');

      // 이제 보통 파일이라 다시 저장하면 서버 변경을 확인하는 저장이 된다.
      doc.text.text = '#!/bin/bash\necho bye\n';
      expect((await c.save(doc)).status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/home/me/run.sh']!), '#!/bin/bash\necho bye\n');
      c.dispose();
    });

    test('saving over an existing server file asks first (conflict), overwrite replaces it', () async {
      fs.put('/a.txt', utf8.encode('theirs'));
      final c = RemoteEditorController(() => fs);
      final doc = c.newDocument()..text.text = 'mine';
      expect((await c.saveAs(doc, '/a.txt')).status, RemoteSaveStatus.conflict);
      expect(doc.isNew, isTrue);
      expect(doc.modified, isTrue);
      expect(utf8.decode(fs.files['/a.txt']!), 'theirs');
      expect((await c.saveAs(doc, '/a.txt', overwrite: true)).status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/a.txt']!), 'mine');
      c.dispose();
    });

    test('a path that is already open in another tab is refused', () async {
      fs.put('/a.txt', utf8.encode('x'));
      final c = RemoteEditorController(() => fs);
      await c.open('/a.txt');
      final doc = c.newDocument()..text.text = 'y';
      await expectLater(
        c.saveAs(doc, '/a.txt', overwrite: true),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.alreadyOpen)),
      );
      expect(utf8.decode(fs.files['/a.txt']!), 'x');
      c.dispose();
    });

    test('save() on a file with no server path is an error (use saveAs)', () async {
      final c = RemoteEditorController(() => fs);
      final doc = c.newDocument();
      await expectLater(c.save(doc), throwsA(isA<RemoteEditException>()));
      c.dispose();
    });

    test('Save As on an opened file makes a copy and the tab now edits the copy', () async {
      fs.put('/a.conf', utf8.encode('k=1\n'));
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/a.conf');
      doc.text.text = 'k=2\n';
      expect((await c.saveAs(doc, '/b.conf')).status, RemoteSaveStatus.saved);
      expect(utf8.decode(fs.files['/a.conf']!), 'k=1\n'); // 원본은 그대로
      expect(utf8.decode(fs.files['/b.conf']!), 'k=2\n');
      expect(doc.path, '/b.conf');
      c.dispose();
    });
  });
}
