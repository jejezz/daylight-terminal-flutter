import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/file_item.dart';
import '../models/local_shell.dart';
import '../services/local_paths.dart';
import '../services/pty_backend.dart';
import 'terminal_session.dart';

/// 탭 하나 = 이 PC에서 도는 셸 하나. 왼쪽에는 이 PC의 폴더를 보여 준다.
///
/// SSH 탭과 같게, 터미널의 현재 경로와 폴더 뷰의 경로는 **자동으로 맞추지 않는다.** 사용자가 메뉴로
/// 요청할 때만 [moveTerminalTo] / [syncExplorerToTerminal]이 한쪽을 다른 쪽에 맞춘다.
class LocalShellSession extends TerminalSession {
  LocalShellSession(this.shell, {super.scrollback, PtyFactory? ptyFactory, String? startDirectory})
    : _ptyFactory = ptyFactory ?? startFlutterPty,
      _folderPath = startDirectory ?? homeDirectory();

  final LocalShell shell;
  final PtyFactory _ptyFactory;

  PtyProcess? _pty;
  StreamSubscription<Uint8List>? _outputSub;
  int? _exitCode;
  String? _startError;

  // 폴더 뷰 상태
  String _folderPath;
  List<FileItem> _entries = const [];
  bool _folderLoading = false;
  String? _folderError;

  /// 셸이 끝났을 때의 종료 코드. 아직 돌고 있으면 null.
  int? get exitCode => _exitCode;

  /// 셸을 띄우지 못했을 때의 오류 문구.
  String? get startError => _startError;

  String get folderPath => _folderPath;
  List<FileItem> get entries => _entries;
  bool get folderLoading => _folderLoading;
  String? get folderError => _folderError;

  /// 위로 갈 수 있는 폴더인가 (드라이브나 `/` 같은 뿌리는 못 간다).
  bool get canGoUp => p.dirname(_folderPath) != _folderPath;

  @override
  String get tabTitle => shell.name;

  @override
  String get statusLabel => shell.name;

  @override
  String get logName => shell.id.replaceAll(':', '_');

  static String homeDirectory() =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;

  // ───────────────────────── 셸 프로세스 ─────────────────────────

  /// 셸을 띄운다. 이미 돌고 있으면 아무것도 하지 않는다. 폴더 뷰도 함께 불러온다.
  Future<void> start() async {
    if (_pty != null) return;
    _exitCode = null;
    _startError = null;
    try {
      final pty = _ptyFactory(
        shell,
        workingDirectory: _folderPath,
        environment: {...Platform.environment, 'TERM': 'xterm-256color', 'COLORTERM': 'truecolor'},
        rows: terminal.viewHeight,
        columns: terminal.viewWidth,
      );
      _pty = pty;
      _outputSub = pty.output.listen(handleOutput);
      unawaited(pty.exitCode.then((code) => _onExit(pty, code), onError: (Object _) => _onExit(pty, -1)));
      setStatus(SessionStatus.connected);
    } catch (e) {
      _pty = null;
      _startError = e.toString();
      setStatus(SessionStatus.error);
    }
    notify();
    await loadFolder(_folderPath);
  }

  void _onExit(PtyProcess pty, int code) {
    if (!identical(_pty, pty)) return; // 우리가 끈 것 (disconnect)이면 이미 정리됐다
    _release();
    _exitCode = code;
    setStatus(SessionStatus.idle);
    notify();
  }

  void _release() {
    final pty = _pty;
    _pty = null;
    _outputSub?.cancel();
    _outputSub = null;
    if (pty != null) {
      try {
        pty.kill();
      } catch (_) {
        // 이미 끝난 프로세스일 수 있다.
      }
    }
    if (isLogging) unawaited(stopLogging());
    cancelPendingCwd();
  }

  /// 끝난 셸을 같은 폴더에서 다시 띄운다.
  Future<void> restart() async {
    _release();
    terminal.write('\r\n');
    await start();
  }

  @override
  Future<void> disconnect() async {
    _release();
    setStatus(SessionStatus.idle);
    _exitCode ??= 0;
    notify();
  }

  @override
  void writeInput(List<int> bytes) {
    if (!connected) return;
    try {
      _pty?.write(Uint8List.fromList(bytes));
    } catch (_) {
      // 막 끝난 셸에 쓴 입력이다. 종료 처리는 exitCode에서 한다.
    }
  }

  @override
  void onTerminalResize(int width, int height, int pixelWidth, int pixelHeight) => _pty?.resize(height, width);

  // ───────────────────────── 경로 이동 (메뉴로만) ─────────────────────────

  /// "터미널을 이 폴더로 이동": 셸 종류에 맞는 이동 명령을 입력한다.
  void moveTerminalTo(String path) => typeCommand(LocalPaths.cdCommand(shell, path));

  /// 이 셸이 현재 경로를 알려 줄 수 있는가 (cmd는 못 한다 — 메뉴에서 숨긴다).
  bool get canSyncExplorer => shell.canReportCwd;

  /// "탐색기를 터미널 경로로 이동": 셸에 현재 경로를 출력하는 명령을 입력하고, 돌아온 경로로 폴더 뷰를
  /// 옮긴다. 성공하면 true.
  Future<bool> syncExplorerToTerminal() async {
    final probe = LocalPaths.cwdProbe(shell);
    if (probe == null) return false;
    final reported = await requestTerminalCwd(probe);
    if (reported == null) return false;
    final path = LocalPaths.explorerPathFromTerminal(shell, reported);
    if (path == null) return false;
    await loadFolder(path);
    return _folderError == null;
  }

  // ───────────────────────── 폴더 뷰 ─────────────────────────

  Future<void> loadFolder(String path) async {
    _folderLoading = true;
    notify();
    try {
      final dir = Directory(path);
      final raw = <FileSystemEntity>[];
      await for (final e in dir.list(followLinks: false)) {
        raw.add(e);
      }
      final items = await Future.wait(raw.map(_toItem));
      items.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _entries = items;
      _folderPath = dir.absolute.path;
      _folderError = null;
    } catch (e) {
      _folderError = e.toString();
    } finally {
      _folderLoading = false;
      notify();
    }
  }

  Future<FileItem> _toItem(FileSystemEntity e) async {
    final name = p.basename(e.path);
    final isLink = e is Link;
    var isDir = e is Directory;
    if (isLink) {
      try {
        isDir = await FileSystemEntity.isDirectory(e.path); // 링크가 가리키는 쪽
      } catch (_) {}
    }
    int? size;
    DateTime? modified;
    try {
      final stat = await e.stat();
      modified = stat.modified;
      if (!isDir) size = stat.size;
    } catch (_) {
      // 권한이 없는 항목은 이름만 보여 준다.
    }
    return FileItem(name: name, isDirectory: isDir, isLink: isLink, size: size, modified: modified);
  }

  Future<void> refreshFolder() => loadFolder(_folderPath);
  Future<void> goUp() => loadFolder(p.dirname(_folderPath));
  Future<void> openEntry(FileItem e) => loadFolder(pathOf(e));
  String pathOf(FileItem e) => p.join(_folderPath, e.name);

  Future<void> makeDirectory(String name) async {
    await Directory(p.join(_folderPath, name)).create();
    await refreshFolder();
  }

  Future<void> rename(FileItem e, String newName) async {
    final from = pathOf(e);
    final to = p.join(_folderPath, newName);
    if (e.isDirectory && !e.isLink) {
      await Directory(from).rename(to);
    } else if (e.isLink) {
      await Link(from).rename(to);
    } else {
      await File(from).rename(to);
    }
    await refreshFolder();
  }

  /// 영구 삭제다 (휴지통을 거치지 않는다). 링크는 가리키는 대상이 아니라 링크만 지운다.
  Future<void> delete(FileItem e) async {
    final path = pathOf(e);
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.link:
        await Link(path).delete();
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      default:
        await File(path).delete();
    }
    await refreshFolder();
  }

  /// 자주 가는 곳: 홈, 바탕화면, 다운로드, 문서(있는 것만), Windows는 연결된 드라이브.
  Future<List<(String label, String path)>> places() async {
    final home = homeDirectory();
    final candidates = <(String, String)>[
      ('~', home),
      ('Desktop', p.join(home, 'Desktop')),
      ('Downloads', p.join(home, 'Downloads')),
      ('Documents', p.join(home, 'Documents')),
    ];
    final result = <(String, String)>[];
    for (final (label, path) in candidates) {
      if (await Directory(path).exists()) result.add((label, path));
    }
    if (Platform.isWindows) {
      final checks = await Future.wait([
        for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
          Directory('${String.fromCharCode(c)}:\\')
              .exists()
              .timeout(const Duration(milliseconds: 400), onTimeout: () => false),
      ]);
      for (var i = 0; i < checks.length; i++) {
        if (checks[i]) {
          final d = '${String.fromCharCode('A'.codeUnitAt(0) + i)}:\\';
          result.add((d, d));
        }
      }
    }
    return result;
  }

  // ───────────────────────── 종료 ─────────────────────────

  /// 앱을 끌 때 남는 셸 프로세스가 없게 한다 (기록 파일도 닫는다).
  @override
  Future<void> prepareForExit() async {
    _release();
    await super.prepareForExit();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }
}
