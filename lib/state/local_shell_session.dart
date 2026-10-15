import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/local_shell.dart';
import '../services/local_paths.dart';
import '../services/pty_backend.dart';
import 'local_folder_session.dart';
import 'terminal_session.dart';

/// 탭 하나 = 이 PC에서 도는 셸 하나. 왼쪽에는 이 PC의 폴더를 보여 준다.
///
/// SSH 탭과 같게, 터미널의 현재 경로와 폴더 뷰의 경로는 **자동으로 맞추지 않는다.** 사용자가 메뉴로
/// 요청할 때만 [moveTerminalTo] / [syncExplorerToTerminal]이 한쪽을 다른 쪽에 맞춘다.
class LocalShellSession extends LocalFolderSession {
  LocalShellSession(this.shell, {super.scrollback, PtyFactory? ptyFactory, super.startDirectory})
    : _ptyFactory = ptyFactory ?? startFlutterPty;

  final LocalShell shell;
  final PtyFactory _ptyFactory;

  @override
  String quotePath(String path) => LocalPaths.quotePath(shell, path);

  PtyProcess? _pty;
  StreamSubscription<Uint8List>? _outputSub;
  int? _exitCode;
  String? _startError;

  /// 셸이 끝났을 때의 종료 코드. 아직 돌고 있으면 null.
  int? get exitCode => _exitCode;

  /// 셸을 띄우지 못했을 때의 오류 문구.
  String? get startError => _startError;

  static String homeDirectory() => LocalFolderSession.homeDirectory();

  @override
  String get tabTitle => shell.name;

  @override
  String get statusLabel => shell.name;

  @override
  String get logName => shell.id.replaceAll(':', '_');

  // ───────────────────────── 셸 프로세스 ─────────────────────────

  /// 셸을 띄운다. 이미 돌고 있으면 아무것도 하지 않는다. 폴더 뷰도 함께 불러온다.
  Future<void> start() async {
    if (_pty != null) return;
    _exitCode = null;
    _startError = null;
    try {
      final pty = _ptyFactory(
        shell,
        workingDirectory: folderPath,
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
    await loadFolder(folderPath);
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

  @override
  bool get canMoveTerminal => true;

  /// "터미널을 이 폴더로 이동": 셸 종류에 맞는 이동 명령을 입력한다.
  @override
  void moveTerminalTo(String path) => typeCommand(LocalPaths.cdCommand(shell, path));

  /// 이 셸이 현재 경로를 알려 줄 수 있는가 (cmd는 못 한다 — 메뉴에서 숨긴다).
  @override
  bool get canSyncExplorer => shell.canReportCwd;

  /// "탐색기를 터미널 경로로 이동": 셸에 현재 경로를 출력하는 명령을 입력하고, 돌아온 경로로 폴더 뷰를
  /// 옮긴다. 성공하면 true.
  @override
  Future<bool> syncExplorerToTerminal() async {
    final probe = LocalPaths.cwdProbe(shell);
    if (probe == null) return false;
    final reported = await requestTerminalCwd(probe);
    if (reported == null) return false;
    final path = LocalPaths.explorerPathFromTerminal(shell, reported);
    if (path == null) return false;
    await loadFolder(path);
    return folderError == null;
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
