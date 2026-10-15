import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

import '../models/line_ending.dart';
import '../services/ansi_stripper.dart';
import '../services/drag_staging.dart';
import '../services/log_file_service.dart';
import '../services/shell_commands.dart';

enum SessionStatus { idle, connecting, connected, error }

/// [TerminalSession.dropFiles]의 결과. [fallbackDir]가 있으면 터미널의 현재 폴더를 몰라서 그 폴더(탐색기가 보던
/// 곳)에 올렸다는 뜻이다.
class TerminalDropResult {
  const TerminalDropResult({this.fallbackDir});

  final String? fallbackDir;
}

/// 탭 하나의 터미널 세션. SSH 세션과 로컬 셸 세션이 공통으로 갖는 것 — 터미널 화면, 입력 보내기,
/// LineSender, 기록(Recording), 터미널 현재 경로 확인 — 을 모았다.
///
/// 하위 클래스는 입력을 어디로 보낼지([writeInput])와 크기가 바뀔 때 무엇을 할지([onTerminalResize]),
/// 받은 출력을 [handleOutput]으로 넘기는 일을 맡는다.
abstract class TerminalSession extends ChangeNotifier {
  TerminalSession({int scrollback = 10000}) : terminal = Terminal(maxLines: scrollback) {
    terminal.onOutput = (data) => writeInput(utf8.encode(data));
    terminal.onResize = onTerminalResize;
    terminal.onCurrentDirectoryChange = _onTerminalCwd;
  }

  final Terminal terminal;
  final LogFileService _log = LogFileService();
  late final ByteConversionSink _terminalSink = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(FnSink((s) => terminal.write(s)));
  ByteConversionSink? _logSink;

  bool _disposed = false;
  SessionStatus _status = SessionStatus.idle;
  LineEnding _lineEnding = LineEnding.cr;
  bool _stripAnsi = false;
  Completer<String?>? _cwdWaiter;

  // ───────────────────────── 하위 클래스가 채울 것 ─────────────────────────

  /// 탭에 보이는 이름.
  String get tabTitle;

  /// 상태 표시줄에 보이는 이름.
  String get statusLabel;

  /// 기록 파일 이름에 쓸 이름 (호스트 이름이나 셸 이름).
  String get logName;

  /// 터미널(셸)에 입력 바이트를 보낸다. 연결되어 있지 않으면 아무 일도 하지 않는다.
  @protected
  void writeInput(List<int> bytes);

  /// 터미널 화면의 칸 수가 바뀌었다 — 상대 쪽 pty 크기도 맞춘다.
  @protected
  void onTerminalResize(int width, int height, int pixelWidth, int pixelHeight);

  Future<void> disconnect();

  // ───────────────────────── 상태 ─────────────────────────

  SessionStatus get status => _status;
  bool get connected => _status == SessionStatus.connected;
  bool get disposed => _disposed;
  LineEnding get lineEnding => _lineEnding;
  bool get stripAnsi => _stripAnsi;
  bool get isLogging => _log.isLogging;
  String? get logFilePath => _log.filePath;

  @protected
  void setStatus(SessionStatus value) => _status = value;

  /// 해제된 뒤에는 알리지 않는다.
  @protected
  void notify() {
    if (_disposed) return;
    _updateAutoRefresh();
    notifyListeners();
  }

  // ───────────────────────── 터미널 ─────────────────────────

  /// 상대(서버/셸)가 보낸 출력. 기록 중이면 파일에도 쓰고 화면에 그린다.
  @protected
  void handleOutput(Uint8List chunk) {
    if (_log.isLogging) {
      if (_logSink == null) {
        _log.write(chunk);
      } else {
        _logSink!.add(chunk);
      }
    }
    _terminalSink.add(chunk);
  }

  void setLineEnding(LineEnding value) {
    _lineEnding = value;
    notify();
  }

  void setStripAnsi(bool value) {
    _stripAnsi = value;
    if (_log.isLogging) _resetLogSink();
    notify();
  }

  /// LineSender에서 한 줄을 보낸다. 설정된 줄 끝 문자를 붙인다. 셸이 입력을 에코해 주므로
  /// 로컬 에코는 하지 않는다.
  void send(String text) => writeInput(utf8.encode(text + _lineEnding.suffix));

  /// 셸에 문자열을 그대로 입력한다 (메뉴 동작이 `cd` 같은 명령을 넣을 때 쓴다).
  void typeCommand(String command) => writeInput(utf8.encode(command));

  /// [path]를 이 터미널의 셸 명령줄에 넣을 수 있게 인용한다. 기본은 POSIX 셸(SSH 서버).
  String quotePath(String path) => ShellCommands.posixQuote(path);

  /// 탐색기에서 끌어온 [paths]를 인용해 프롬프트에 입력한다. Enter는 누르지 않는다.
  /// 붙여넣기로 보내므로 이름에 줄바꿈이 있어도 실행되지 않는다.
  void typePaths(List<String> paths) {
    if (!connected || paths.isEmpty) return;
    terminal.paste('${paths.map(quotePath).join(' ')} ');
  }

  /// 이 PC의 파일을 터미널에 끌어놓았을 때. 기본(로컬 셸)은 이 PC의 경로를 인용해 입력만 한다.
  /// [confirmOverwrite]는 덮어쓸 이름이 있을 때 사용자에게 물어 true/false를 돌려주는 함수다.
  Future<TerminalDropResult> dropFiles(
    List<String> localPaths,
    Future<bool> Function(List<String> names) confirmOverwrite,
  ) async {
    typePaths(localPaths);
    return const TerminalDropResult();
  }

  void clearTerminal() => terminal.clear();

  // ───────────────────────── 기록(Recording) ─────────────────────────

  /// 기록을 시작/정지한다. 파일에는 받은 출력이 기록된다 — [stripAnsi]가 켜져 있으면 이스케이프
  /// 시퀀스를 뺀 텍스트, 아니면 받은 바이트 그대로. 시작할 때마다 저장 위치를 묻고, 취소하면 켜지지
  /// 않는다. [confirmButtonText]는 저장 대화상자의 확인 버튼 문구(l10n).
  Future<void> toggleLogging({required String confirmButtonText}) async {
    if (_log.isLogging) {
      await stopLogging();
      notify();
      return;
    }
    if (!connected) return;
    final location = await getSaveLocation(
      initialDirectory: await LogFileService.defaultDirectory(),
      suggestedName: LogFileService.suggestedFileName(logName),
      confirmButtonText: confirmButtonText,
    );
    if (location == null) return;
    await _log.start(location.path);
    _resetLogSink();
    notify();
  }

  /// 이스케이프 제거 모드면 디코더+스트리퍼를 거치는 싱크를, 아니면 null(원본 바이트 기록).
  void _resetLogSink() {
    _logSink?.close();
    if (!_stripAnsi) {
      _logSink = null;
      return;
    }
    final stripper = AnsiStripper();
    _logSink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(
      FnSink((s) {
        final text = stripper.strip(s);
        if (text.isNotEmpty) _log.write(Uint8List.fromList(utf8.encode(text)));
      }),
    );
  }

  /// 터미널 안의 모든 글(스크롤백 포함)을 텍스트로. 기록을 켜 두지 않았을 때 쏟아진 출력을 건지는 용도다.
  /// 줄 끝 공백과 맨 끝의 빈 줄은 뺀다. 스크롤백 줄 수(`terminal_scrollback`)를 넘어 밀려난 줄은 없다.
  String bufferText() {
    final text = terminal.buffer.getText(null, true).trimRight();
    return text.isEmpty ? '' : '$text\n';
  }

  /// [bufferText]를 저장 위치를 물어 파일로 쓴다. 취소하면 null, 썼으면 파일 경로.
  Future<String?> saveBufferToFile({required String confirmButtonText}) async {
    final location = await getSaveLocation(
      initialDirectory: await LogFileService.defaultDirectory(),
      suggestedName: LogFileService.suggestedFileName(logName),
      confirmButtonText: confirmButtonText,
    );
    if (location == null) return null;
    await File(location.path).writeAsString(bufferText());
    return location.path;
  }

  @protected
  Future<void> stopLogging() async {
    _logSink?.close();
    _logSink = null;
    await _log.stop();
  }

  // ───────────────────────── 터미널 현재 경로 (메뉴로만 요청) ─────────────────────────

  /// 셸에 [probeCommand](현재 경로를 OSC 7로 출력하는 명령)를 입력하고, 돌아온 경로를 기다린다.
  /// 3초 안에 안 오면 null. 경로를 못 얻는 셸(cmd 등)에서는 부르지 않는다.
  @protected
  Future<String?> requestTerminalCwd(String probeCommand) async {
    if (!connected) return null;
    final waiter = _cwdWaiter = Completer<String?>();
    typeCommand('$probeCommand\r');
    final path = await waiter.future.timeout(const Duration(seconds: 3), onTimeout: () => null);
    _cwdWaiter = null;
    return path;
  }

  void _onTerminalCwd(String uri) {
    var rest = uri.startsWith('file://') ? uri.substring(7) : uri;
    final slash = rest.indexOf('/');
    if (slash == -1) return;
    rest = rest.substring(slash);
    if (rest.contains('%')) {
      try {
        rest = Uri.decodeFull(rest);
      } on FormatException {
        // 디코딩할 수 없으면 원문 그대로 쓴다.
      }
    }
    final waiter = _cwdWaiter;
    if (waiter == null) {
      // 메뉴가 요청한 것이 아니라 셸이 알아서 보낸 것(프롬프트마다 OSC 7을 내는 셸)이다.
      _autoReportedCwd = rest;
    } else if (!waiter.isCompleted) {
      waiter.complete(rest);
    }
  }

  /// 셸이 요청 없이 스스로 알려 준 가장 최근 현재 경로. 그런 셸이 아니면 null.
  /// 프롬프트마다 갱신되는 값이라 믿을 수 있지만, 메뉴 요청으로 얻은 경로는 곧 낡으므로 담지 않는다.
  String? get autoReportedCwd => _autoReportedCwd;
  String? _autoReportedCwd;

  /// 연결이 끊길 때 기다리던 경로 요청을 끝낸다.
  @protected
  void cancelPendingCwd() {
    final waiter = _cwdWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(null);
  }

  // ───────────────────────── 탐색기 자동 새로 고침 ─────────────────────────

  static const autoRefreshInterval = Duration(seconds: 5);

  /// 테스트가 끈다 (끝나지 않은 타이머가 남으면 위젯 테스트가 실패한다).
  @visibleForTesting
  static bool autoRefreshEnabled = true;

  Timer? _autoRefreshTimer;
  bool _active = false;
  bool _autoRefreshAllowed = true;

  /// 탐색기 목록을 조용히 다시 읽는다 (로딩 표시나 오류 없이). 하위 클래스가 채운다.
  @protected
  Future<void> autoRefresh() async {}

  /// 자동 새로 고침을 하는 탭인가. 기본은 하지 않는다 (SSH는 네트워크 오류가 잦아 직접 새로 고칠 때만 읽는다).
  @protected
  bool get autoRefreshReady => false;

  /// 이 탭이 지금 보이는 탭인지 알린다. 활성화되면 바로 한 번 새로 고치고 [autoRefreshInterval]마다 되풀이하며,
  /// 비활성화되면 멈춘다.
  void setActive(bool value) {
    if (_active == value || _disposed) return;
    _active = value;
    _updateAutoRefresh();
    if (value && _autoRefreshTimer != null) unawaited(autoRefresh());
  }

  /// 설정에서 이 종류의 탭(SSH/로컬)에 자동 새로 고침을 허용했는지. 꺼지면 타이머가 멈춘다.
  void setAutoRefreshAllowed(bool value) {
    if (_autoRefreshAllowed == value || _disposed) return;
    _autoRefreshAllowed = value;
    _updateAutoRefresh();
    if (value && _autoRefreshTimer != null) unawaited(autoRefresh());
  }

  /// 사용자가 직접 새로 고쳤을 때: 다음 자동 새로 고침을 다시 [autoRefreshInterval] 뒤로 미룬다.
  @protected
  void restartAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _updateAutoRefresh();
  }

  // 보이는 탭이고 읽을 수 있는 상태일 때만 타이머가 돈다. 상태가 바뀔 때마다([notify]) 맞춘다.
  void _updateAutoRefresh() {
    final shouldRun = autoRefreshEnabled && _autoRefreshAllowed && _active && !_disposed && autoRefreshReady;
    if (!shouldRun) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    } else {
      _autoRefreshTimer ??= Timer.periodic(autoRefreshInterval, (_) => unawaited(autoRefresh()));
    }
  }

  // ───────────────────────── 종료 ─────────────────────────

  /// 앱 종료 요청(⌘Q 등) 시 위젯 dispose가 보장되지 않으므로, 종료 직전에 호출해서
  /// 기록 파일이 확실히 flush/close되게 한다.
  Future<void> prepareForExit() async {
    await stopLogging();
    await DragStaging.clean();
  }

  /// 하위 클래스는 자기 자원(연결, 프로세스)을 먼저 정리한 뒤 불러야 한다.
  @override
  void dispose() {
    _disposed = true;
    _autoRefreshTimer?.cancel();
    unawaited(stopLogging());
    terminal.dispose();
    super.dispose();
  }
}

/// 문자열을 받는 함수 하나를 [Sink]로 감싼다 (청크 디코더의 출력용).
class FnSink implements Sink<String> {
  FnSink(this._onData);
  final void Function(String) _onData;
  @override
  void add(String data) => _onData(data);
  @override
  void close() {}
}
