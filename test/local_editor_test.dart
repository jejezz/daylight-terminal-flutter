import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/local_fs.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/services/remote_text_file.dart';
import 'package:daylight_terminal/services/sender_file.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/remote_editor_controller.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/remote_editor_pane.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_pty.dart';
import 'helpers/fake_remote_fs.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);

class _FixedFinder extends LocalShellFinder {
  _FixedFinder(this.shells);
  final List<LocalShell> shells;
  @override
  Future<List<LocalShell>> find() async => shells;
}

void main() {
  late FakePtyFactory ptys;
  late Directory tmp;

  /// 화면 테스트는 디스크 대신 메모리 파일 시스템으로 편집한다 (위젯 테스트의 가짜 시계 안에서는 실제 파일 입출력이 끝나지 않는다).
  /// 실제 디스크 동작은 위의 LocalFs 테스트가 확인한다.
  late FakeRemoteFs memFs;

  String path(String name) => p.join(tmp.path, name);

  setUp(() async {
    ptys = FakePtyFactory();
    tmp = await Directory.systemTemp.createTemp('dt_edit_');
    File(path('notes.txt')).writeAsStringSync('hi\n');
    Directory(path('projects')).createSync();
    memFs = FakeRemoteFs()
      ..pathContext = p.context
      ..writeInPlace = true
      ..put(path('notes.txt'), utf8.encode('hi\n'));
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('LocalFs', () {
    const fs = LocalFs();

    test('opens and saves a file in place, keeping CRLF and BOM, with no temp files left', () async {
      File(path('w.txt')).writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb\r\n')]);
      final file = await RemoteText.open(fs, path('w.txt'));
      expect(file.document.text, 'a\nb\n');
      final result = await RemoteText.save(
        fs,
        file,
        SenderDocument('a\nb\nc\n', file.document.eol, bom: file.document.bom),
      );
      expect(result.status, RemoteSaveStatus.saved);
      expect(File(path('w.txt')).readAsBytesSync(), [0xEF, 0xBB, 0xBF, ...utf8.encode('a\r\nb\r\nc\r\n')]);
      expect(Directory(tmp.path).listSync().map((e) => p.basename(e.path)).where((n) => n.endsWith('.tmp')), isEmpty);
    });

    test('a change made on disk meanwhile is a conflict and nothing is written', () async {
      final file = await RemoteText.open(fs, path('notes.txt'));
      File(path('notes.txt')).writeAsStringSync('changed by someone else, longer than before\n');
      final result = await RemoteText.save(
        fs,
        file,
        SenderDocument('mine\n', file.document.eol, bom: file.document.bom),
      );
      expect(result.status, RemoteSaveStatus.conflict);
      expect(File(path('notes.txt')).readAsStringSync(), 'changed by someone else, longer than before\n');
      final forced = await RemoteText.save(
        fs,
        file,
        SenderDocument('mine\n', file.document.eol, bom: file.document.bom),
        overwrite: true,
      );
      expect(forced.status, RemoteSaveStatus.saved);
      expect(File(path('notes.txt')).readAsStringSync(), 'mine\n');
    });

    test('refuses folders, missing files and binaries; saveNew creates, asks before replacing', () async {
      Future<RemoteEditError> failure(String name) async {
        try {
          await RemoteText.open(fs, path(name));
        } on RemoteEditException catch (e) {
          return e.kind;
        }
        fail('expected a failure for $name');
      }

      expect(await failure('projects'), RemoteEditError.notRegular);
      expect(await failure('nope.txt'), RemoteEditError.notFound);
      File(path('bin')).writeAsBytesSync([0x7f, 0x45, 0, 0x4c]);
      expect(await failure('bin'), RemoteEditError.binary);

      final made = await RemoteText.saveNew(fs, path('new.sh'), const SenderDocument('echo hi\n', '\n'));
      expect(made.status, RemoteSaveStatus.saved);
      expect(File(path('new.sh')).readAsStringSync(), 'echo hi\n');
      expect(
        (await RemoteText.saveNew(fs, path('new.sh'), const SenderDocument('x', '\n'))).status,
        RemoteSaveStatus.conflict,
      );
      await expectLater(
        RemoteText.saveNew(fs, path('no_such_dir/x.txt'), const SenderDocument('x', '\n')),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.io)),
      );
    });
  });

  group('controller', () {
    test(
      'a local controller opens files directly; a server controller opens a local file as a new unsaved file',
      () async {
        final local = RemoteEditorController(() => const LocalFs(), local: true, context: p.context);
        final doc = await local.open(path('notes.txt'));
        expect(doc.isNew, isFalse);
        expect(doc.text.text, 'hi\n');
        expect((await local.open(path('notes.txt'))), doc); // 이미 열려 있다
        local.dispose();

        File(path('deploy.sh')).writeAsBytesSync(utf8.encode('#!/bin/bash\r\necho "한글"\r\n'));
        final server = RemoteEditorController(() => null, directory: () => '/srv');
        final copy = await server.openLocalFileAsNew(path('deploy.sh'));
        expect(copy.isNew, isTrue);
        expect(copy.modified, isTrue); // 서버에는 아직 없다
        expect(copy.suggestedName, 'deploy.sh');
        expect(copy.text.text, '#!/bin/bash\necho "한글"\n');
        expect(copy.baseDocument.eol, '\r\n'); // 저장하면 원래 줄바꿈으로
        expect(copy.text.kind.name, 'shell'); // 이름만으로 색 입히기가 켜진다
        server.dispose();
      },
    );

    test('files that cannot be edited are refused when dropped from this PC', () async {
      final server = RemoteEditorController(() => null);
      File(path('bin')).writeAsBytesSync([0, 1, 2]);
      File(path('big.txt')).writeAsBytesSync(List.filled(2 * 1024 * 1024 + 1, 0x61));
      for (final (name, kind) in [
        ('projects', RemoteEditError.notRegular),
        ('bin', RemoteEditError.binary),
        ('big.txt', RemoteEditError.tooLarge),
        ('missing.txt', RemoteEditError.io),
      ]) {
        await expectLater(
          server.openLocalFileAsNew(path(name)),
          throwsA(isA<RemoteEditException>().having((e) => e.kind, name, kind)),
        );
      }
      expect(server.documents, isEmpty);
      server.dispose();
    });

    test('on Windows paths differ only by case or slash direction are the same file', () async {
      final win = p.Context(style: p.Style.windows, current: r'C:\');
      final fake = _MemoryFs(win);
      final c2 = RemoteEditorController(() => fake, local: true, context: win);
      final doc = c2.newDocument()..text.text = 'x';
      await c2.saveAs(doc, r'C:\Work\Notes.txt');
      final again = await c2.open('c:/work/NOTES.txt'); // 열린 파일로 간다 (디스크를 다시 읽지 않는다)
      expect(again, doc);
      expect(c2.documents.length, 1);
      final other = c2.newDocument()..text.text = 'y';
      await expectLater(
        c2.saveAs(other, r'c:\WORK\notes.txt', overwrite: true),
        throwsA(isA<RemoteEditException>().having((e) => e.kind, 'kind', RemoteEditError.alreadyOpen)),
      );
      c2.dispose();
    });
  });

  // ───────────────────────── 로컬 셸 탭 화면 ─────────────────────────

  Future<SessionsController> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder([_bash]),
      ptyFactory: ptys.call,
    );
    await tester.runAsync(sessions.loadShells);
    final settings = await AppSettings.load();
    final prefs = await TerminalPrefs.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
          ChangeNotifierProvider<TerminalPrefs>.value(value: prefs),
        ],
        child: AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            home: HomeScreen(onAbout: () {}),
          ),
        ),
      ),
    );
    return sessions;
  }

  /// 터미널의 커서 깜박임 때문에 pumpAndSettle은 쓸 수 없다.
  Future<void> settle(WidgetTester tester) async {
    // 파일 입출력은 실제 시간이 걸린다: 실제 시간과 화면 갱신을 번갈아 돌려서 끝난 뒤의 setState까지 반영한다.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// 메뉴가 다 열릴(또는 닫힐) 때까지만 기다린다 (파일 입출력을 기다리지 않는다).
  Future<void> settleMenu(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<LocalShellSession> openLocalTab(WidgetTester tester) async {
    final sessions = await pumpApp(tester);
    await tester.tap(find.byTooltip('새 연결'));
    await settleMenu(tester);
    await tester.tap(find.ancestor(of: find.text('bash'), matching: find.byType(PopupMenuItem<Object>)));
    await settleMenu(tester);
    final local = sessions.current! as LocalShellSession;
    await tester.runAsync(() => local.loadFolder(tmp.path));
    await tester.pump(const Duration(milliseconds: 100));
    local.editorFs = memFs;
    return local;
  }

  Finder editorField() => find.descendant(of: find.byType(RemoteEditorPane), matching: find.byType(TextField));

  testWidgets('a local shell tab has the editor docked, empty at first, and F4 opens the selected file', (
    tester,
  ) async {
    final local = await openLocalTab(tester);
    expect(find.byType(RemoteEditorPane), findsOneWidget);
    expect(find.text('열린 파일이 없습니다'), findsOneWidget);

    await tester.tap(find.text('notes.txt')); // 행을 고르면 탐색기가 키보드 포커스를 가져온다
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester);
    expect(local.editor.documents.map((d) => d.path), [path('notes.txt')]);
    expect(find.text('열린 파일이 없습니다'), findsNothing);
    expect(tester.widget<TextField>(editorField()).controller!.text, 'hi\n');
  });

  testWidgets('right-click → 편집 opens the file; Ctrl+S writes it to disk; an outside change asks first', (
    tester,
  ) async {
    final local = await openLocalTab(tester);
    await tester.tap(find.text('notes.txt'), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('편집'));
    await settle(tester);
    expect(local.editor.documents.length, 1);

    await tester.enterText(editorField(), 'edited\n');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(utf8.decode(memFs.files[path('notes.txt')]!), 'edited\n');
    expect(local.editor.hasUnsaved, isFalse);

    // 다른 프로그램이 파일을 고쳤다.
    memFs.touchExternally(path('notes.txt'), utf8.encode('someone else wrote a longer line here\n'));
    await tester.enterText(editorField(), 'mine again\n');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.text('서버에서 파일이 바뀌었습니다'), findsOneWidget);
    expect(utf8.decode(memFs.files[path('notes.txt')]!), 'someone else wrote a longer line here\n');
  });

  testWidgets('a folder is not editable: the menu has no 편집 for it, F4 does nothing', (tester) async {
    final local = await openLocalTab(tester);
    await tester.tap(find.text('projects'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester);
    expect(local.editor.documents, isEmpty);
  });

  testWidgets('dragging a row of the folder view onto the editor opens that file', (tester) async {
    final local = await openLocalTab(tester);
    final row = tester.getCenter(find.text('notes.txt'));
    final gesture = await tester.startGesture(row);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.byType(RemoteEditorPane)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('여기에 놓으면 편집기로 엽니다'), findsOneWidget); // 놓을 수 있는 곳이라고 알려 준다
    await gesture.up();
    await settle(tester);

    expect(local.editor.documents.map((d) => d.path), [path('notes.txt')]);
  });

  testWidgets('openDroppedPaths: a folder among several files is skipped; a single bad file is reported', (
    tester,
  ) async {
    final controller = RemoteEditorController(() => const LocalFs(), local: true, context: p.context);
    addTearDown(controller.dispose);
    File(path('b.txt')).writeAsStringSync('b');
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => openDroppedPaths(ctx, controller, [path('projects'), path('notes.txt'), path('b.txt')], localFiles: true),
    );
    await tester.pump();
    expect(controller.documents.map((d) => p.basename(d.path!)), ['notes.txt', 'b.txt']);
    expect(find.byType(SnackBar), findsNothing);

    await tester.runAsync(() => openDroppedPaths(ctx, controller, [path('projects')], localFiles: true));
    await tester.pump();
    expect(find.textContaining('Not a regular file'), findsOneWidget);
  });

  testWidgets(
    'on a server editor: a file from this PC opens as a new file, a server path from the explorer opens as is',
    (tester) async {
      final server = FakeRemoteFs()..put('/srv/app.conf', utf8.encode('port=1\n'));
      final controller = RemoteEditorController(() => server, directory: () => '/srv');
      addTearDown(controller.dispose);
      File(path('local.sh')).writeAsStringSync('echo local\n');
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() => openDroppedPaths(ctx, controller, [path('local.sh')], localFiles: true));
      await tester.pump();
      final copy = controller.current!;
      expect(copy.isNew, isTrue);
      expect(copy.suggestedName, 'local.sh');
      expect(copy.text.text, 'echo local\n');
      expect(server.files.keys, ['/srv/app.conf']); // 서버에는 아직 아무것도 쓰지 않았다

      await openDroppedPaths(ctx, controller, ['/srv/app.conf'], localFiles: false);
      await tester.pump();
      expect(controller.current!.path, '/srv/app.conf');
      expect(controller.documents.length, 2);
    },
  );
}

/// Windows 경로 규칙의 메모리 파일 시스템.
class _MemoryFs implements RemoteFs {
  _MemoryFs(this.pathContext);

  @override
  final p.Context pathContext;
  final Map<String, List<int>> files = {};

  @override
  bool get writeInPlace => true;

  @override
  Future<String> resolve(String path) async => path;
  @override
  Future<RemoteStat> stat(String path) async {
    final f = files[path];
    if (f == null) throw RemoteNotFound(path);
    return RemoteStat(type: RemoteFileType.regular, size: f.length, mtime: 1);
  }

  @override
  Future<Uint8List> read(String path) async => throw UnimplementedError();
  @override
  Future<void> write(String path, Uint8List data) async => files[path] = data;
  @override
  Future<void> rename(String from, String to) async {}
  @override
  Future<void> remove(String path) async => files.remove(path);
  @override
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid}) async {}
}
