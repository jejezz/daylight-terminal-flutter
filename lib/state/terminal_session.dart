import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

import '../models/line_ending.dart';
import '../services/ansi_stripper.dart';
import '../services/drag_staging.dart';
import '../services/log_file_service.dart';

enum SessionStatus { idle, connecting, connected, error }

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
    if (!_disposed) notifyListeners();
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
    final waiter = _cwdWaiter;
    if (waiter == null || waiter.isCompleted) return;
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
    waiter.complete(rest);
  }

  /// 연결이 끊길 때 기다리던 경로 요청을 끝낸다.
  @protected
  void cancelPendingCwd() {
    final waiter = _cwdWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(null);
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
