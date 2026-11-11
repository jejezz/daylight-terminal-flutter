import 'dart:convert';
import 'dart:typed_data';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/services/cp949_table.dart';
import 'package:daylight_terminal/services/remote_text_file.dart';
import 'package:daylight_terminal/services/sender_file.dart';
import 'package:daylight_terminal/services/text_encoding.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/remote_editor_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/remote_editor_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_remote_fs.dart';

Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  group('Cp949', () {
    test('the table has the full 126 x 190 grid and the 17,048 characters of code page 949', () {
      expect(cp949Table.length, cp949Rows * cp949Columns);
      expect(cp949Table.codeUnits.where((c) => c != 0xFFFD).length, 17048);
    });

    test('every assigned pair decodes and encodes back to the same two bytes', () {
      var checked = 0;
      for (var lead = 0x81; lead <= 0xFE; lead++) {
        for (var trail = 0x41; trail <= 0xFE; trail++) {
          final text = Cp949.decode(b([lead, trail]));
          if (text == null) continue;
          checked++;
          expect(Cp949.encode(text).bytes, [
            lead,
            trail,
          ], reason: '0x${lead.toRadixString(16)}${trail.toRadixString(16)}');
        }
      }
      expect(checked, 17048);
    });

    test('known Korean text', () {
      expect(Cp949.decode(b([0xC7, 0xD1, 0xB1, 0xDB])), '한글');
      expect(Cp949.encode('한글').bytes, [0xC7, 0xD1, 0xB1, 0xDB]);
      expect(Cp949.encode('가').bytes, [0xB0, 0xA1]);
      expect(Cp949.encode('똠').bytes, [0x8C, 0x63]); // KS X 1001에 없고 CP949에만 있는 글자
      expect(Cp949.decode(b([0x61, 0xC7, 0xD1, 0x0D, 0x0A, 0x20])), 'a한\r\n ');
    });

    test('bytes that are not CP949 are refused instead of guessed', () {
      expect(Cp949.decode(b([0xC7])), isNull); // 잘린 글자
      expect(Cp949.decode(b([0x80])), isNull);
      expect(Cp949.decode(b([0xFF, 0x41])), isNull);
      expect(Cp949.decode(b([0xC7, 0x20])), isNull); // 뒤 바이트가 범위 밖
      expect(Cp949.decode(b([0xC9, 0xFE])), isNull); // 사용자 정의 영역 끝의 빈 칸
    });

    test('characters CP949 does not have are reported by the first offender', () {
      final r = Cp949.encode('한글 😀 end');
      expect(r.bytes, isNull);
      expect(r.unencodable, '😀');
      expect(Cp949.encode('abc').unencodable, isNull);
    });
  });

  group('SenderFile.decode with allowLegacy', () {
    final korean = b([
      ...ascii.encode('# '),
      0xC7,
      0xD1,
      0xB1,
      0xDB,
      0x0D,
      0x0A,
      ...ascii.encode('x=1'),
    ]); // "# 한글\r\nx=1"

    test('CP949 text is opened as CP949 and saved back to the very same bytes', () {
      final doc = SenderFile.decode(korean, allowLegacy: true);
      expect(doc.encoding, TextEncoding.cp949);
      expect(doc.text, '# 한글\nx=1');
      expect(doc.eol, '\r\n');
      expect(SenderFile.encode(doc), korean);
    });

    test('without allowLegacy it is still refused (LineSender stays UTF-8 only)', () {
      expect(
        () => SenderFile.decode(korean),
        throwsA(isA<SenderFileException>().having((e) => e.kind, 'kind', SenderFileError.notUtf8)),
      );
    });

    test('valid UTF-8 stays UTF-8, including Korean', () {
      final doc = SenderFile.decode(b(utf8.encode('한글')), allowLegacy: true);
      expect(doc.encoding, TextEncoding.utf8);
      expect(doc.text, '한글');
    });

    test('things that are neither UTF-8 nor CP949 are refused', () {
      for (final bytes in [
        [0xE9, 0x20, 0x61], // Latin-1 'é'
        [0xC7], // 잘림
        [0x80, 0x81],
        [0xEF, 0xBB, 0xBF, 0xC7, 0xD1], // BOM이 있으면 UTF-8이어야 한다
      ]) {
        expect(
          () => SenderFile.decode(b(bytes), allowLegacy: true),
          throwsA(isA<SenderFileException>().having((e) => e.kind, 'kind', SenderFileError.notUtf8)),
          reason: '$bytes',
        );
      }
    });

    test('saving a CP949 document with a character it cannot hold is an error, not a silent loss', () {
      final doc = SenderFile.decode(korean, allowLegacy: true);
      final edited = SenderDocument('${doc.text} 😀', doc.eol, encoding: doc.encoding);
      expect(
        () => SenderFile.encode(edited),
        throwsA(isA<SenderFileException>().having((e) => e.kind, 'kind', SenderFileError.unencodable)),
      );
      // UTF-8로 바꾸면 저장할 수 있다.
      expect(SenderFile.encode(SenderDocument(edited.text, edited.eol)), utf8.encode('# 한글\r\nx=1 😀'));
    });
  });

  group('editor controller with a CP949 file', () {
    late FakeRemoteFs fs;
    final original = b([0xC7, 0xD1, 0xB1, 0xDB, 0x0A, ...ascii.encode('port=22\n')]); // "한글\nport=22\n"

    setUp(() => fs = FakeRemoteFs()..put('/old.ini', original));

    test('opens as CP949, keeps the bytes when only ASCII is edited, and does not look modified', () async {
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/old.ini');
      expect(doc.encoding, TextEncoding.cp949);
      expect(doc.text.text, '한글\nport=22\n');
      expect(doc.modified, isFalse);

      doc.text.text = '한글\nport=2222\n';
      await c.save(doc);
      expect(fs.files['/old.ini'], [0xC7, 0xD1, 0xB1, 0xDB, 0x0A, ...ascii.encode('port=2222\n')]);
      c.dispose();
    });

    test('Korean typed into a CP949 file is saved as CP949; an emoji is refused and nothing is written', () async {
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/old.ini');
      doc.text.text = '안녕\n';
      await c.save(doc);
      expect(fs.files['/old.ini'], [0xBE, 0xC8, 0xB3, 0xE7, 0x0A]);

      doc.text.text = '안녕 😀\n';
      await expectLater(
        c.save(doc),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.unencodable)),
      );
      expect(fs.files['/old.ini'], [0xBE, 0xC8, 0xB3, 0xE7, 0x0A]);
      c.dispose();
    });

    test('switching the encoding counts as a change and converts the file on save; switching back clears it', () async {
      final c = RemoteEditorController(() => fs);
      final doc = await c.open('/old.ini');
      doc.setEncoding(TextEncoding.utf8);
      expect(doc.modified, isTrue);
      doc.setEncoding(TextEncoding.cp949);
      expect(doc.modified, isFalse);

      doc.setEncoding(TextEncoding.utf8);
      await c.save(doc);
      expect(fs.files['/old.ini'], utf8.encode('한글\nport=22\n'));
      expect(doc.modified, isFalse);
      expect(doc.encoding, TextEncoding.utf8);

      // 다시 열면 UTF-8 파일이다.
      c.close(doc);
      expect((await c.open('/old.ini')).encoding, TextEncoding.utf8);
      c.dispose();
    });

    test('a new file is UTF-8 unless it came from a CP949 file on this PC', () {
      final c = RemoteEditorController(() => fs);
      expect(c.newDocument().encoding, TextEncoding.utf8);
      final dropped = c.newDocument(initial: SenderFile.decode(original, allowLegacy: true), suggestedName: 'old.ini');
      expect(dropped.encoding, TextEncoding.cp949);
      expect(dropped.modified, isTrue); // 서버에는 아직 없다
      c.dispose();
    });
  });

  group('encoding menu', () {
    late FakeRemoteFs fs;
    late RemoteEditorController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fs = FakeRemoteFs()..put('/old.ini', [0xC7, 0xD1, 0xB1, 0xDB, 0x0A]);
      controller = RemoteEditorController(() => fs);
    });

    tearDown(() => controller.dispose());

    testWidgets('the status line shows the file\'s encoding; picking another marks the file modified', (tester) async {
      final prefs = await TerminalPrefs.load();
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ChangeNotifierProvider<TerminalPrefs>.value(
          value: prefs,
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: SizedBox(width: 500, child: RemoteEditorPane(controller: controller)),
            ),
          ),
        ),
      );
      await tester.runAsync(() => controller.open('/old.ini'));
      await tester.pump();

      expect(find.text('CP949'), findsOneWidget);
      expect(find.textContaining('●'), findsNothing);

      await tester.tap(find.byTooltip('Text encoding (changing it and saving converts the file to that encoding)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UTF-8').last);
      await tester.pumpAndSettle();
      expect(find.text('UTF-8'), findsOneWidget);
      expect(find.textContaining('● old.ini'), findsOneWidget);
    });
  });
}
