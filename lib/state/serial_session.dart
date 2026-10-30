// portside-flutter의 terminal_session_provider.dart에서 가져와 TerminalSession 위에 다시 만들었다.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../models/line_ending.dart';
import '../models/serial_settings.dart';
import '../services/ansi_codepage.dart';
import '../services/serial_service.dart';
import 'local_folder_session.dart';
import 'terminal_session.dart';

enum SerialViewMode { terminal, hex }

/// 탭 하나 = 시리얼 포트 하나. 왼쪽에는 이 PC의 폴더를 보여 준다 (시리얼에는 서버도 셸도 없다).
///
/// 터미널 화면과 키보드 입력은 [TerminalSession]의 xterm2에 맡긴다. [rawBytes]는 화면과 별개로 실제로
/// 받은 바이트만 담아 Hex 보기의 소스로 쓴다 (기록 파일에도 같은 바이트가 쓰인다).
class SerialSession extends LocalFolderSession {
  SerialSession({super.scrollback, SerialService? service, super.startDirectory})
    : _service = service ?? SerialService() {
    // 시리얼 장치는 보통 LF를 기대한다 (SSH의 pty와 달리 Enter 키가 CR이 아니다).
    setLineEnding(LineEnding.lf);
  }

  static const _maxRawBytes = 2 * 1024 * 1024;
  // 꽉 찬 뒤로도 매 청크마다 맨 앞을 깎으면 그때마다 2MB를 통째로 밀어야 해서(removeRange) 느려진다.
  // 더 받아 두었다가(여유分) 한 번에 깎아서, 깎는 빈도를 청크 수백~수천 개에 한 번으로 줄인다.
  static const _rawBytesTrimAt = _maxRawBytes + 256 * 1024;

  final SerialService _service;
  StreamSubscription<Uint8List>? _sub;
  bool _notifyScheduled = false;

  SerialSettings? _active;
  SerialServiceException? _error;
  final List<int> _rawBytes = [];
  bool _localEcho = false;
  SerialViewMode _viewMode = SerialViewMode.terminal;

  // 연결 전에 고르고 있는 설정. 탭을 바꿔도 남아야 해서 위젯이 아니라 여기 둔다.
  String? _pendingPort;
  int _pendingBaud = 115200;
  int _pendingDataBits = 8;
  SerialParity _pendingParity = SerialParity.none;
  int _pendingStopBits = 1;
  SerialFlow _pendingFlow = SerialFlow.none;

  /// 지금 연결되어 있거나 마지막으로 연결했던 설정.
  SerialSettings? get activeSettings => _active;
  SerialServiceException? get error => _error;
  List<int> get rawBytes => _rawBytes;
  int get byteCount => _rawBytes.length;
  bool get localEcho => _localEcho;
  SerialViewMode get viewMode => _viewMode;

  String? get pendingPort => _pendingPort;
  int get pendingBaud => _pendingBaud;
  int get pendingDataBits => _pendingDataBits;
  SerialParity get pendingParity => _pendingParity;
  int get pendingStopBits => _pendingStopBits;
  SerialFlow get pendingFlow => _pendingFlow;

  /// 연결 폼에서 고른 값으로 만든 설정. 포트를 안 골랐으면 null.
  SerialSettings? get pendingSettings => _pendingPort == null
      ? null
      : SerialSettings(
          portName: _pendingPort!,
          baudRate: _pendingBaud,
          dataBits: _pendingDataBits,
          parity: _pendingParity,
          stopBits: _pendingStopBits,
          flow: _pendingFlow,
        );

  static String shortPortName(String name) => name.startsWith('/dev/') ? name.substring(5) : name;

  @override
  String get tabTitle {
    final name = _active?.portName ?? _pendingPort;
    return name == null ? '' : shortPortName(name);
  }

  @override
  String get statusLabel {
    final s = _active;
    return s == null ? '' : '${shortPortName(s.portName)} · ${s.summary}';
  }

  @override
  String get logName => shortPortName(_active?.portName ?? _pendingPort ?? 'serial').replaceAll(RegExp(r'[\/:]'), '_');

  // ───────────────────────── 연결 폼 ─────────────────────────

  void setPendingPort(String? value) {
    _pendingPort = value;
    notify();
  }

  void setPendingBaud(int value) {
    _pendingBaud = value;
    notify();
  }

  void setPendingDataBits(int value) {
    _pendingDataBits = value;
    notify();
  }

  void setPendingParity(SerialParity value) {
    _pendingParity = value;
    notify();
  }

  void setPendingStopBits(int value) {
    _pendingStopBits = value;
    notify();
  }

  void setPendingFlow(SerialFlow value) {
    _pendingFlow = value;
    notify();
  }

  /// 연결하지 않고 폼 값만 채워 둔다 (지난번 탭을 다시 열 때). 장치를 자동으로 열지는 않는다.
  void prefill(SerialSettings s) {
    _pendingPort = s.portName;
    _pendingBaud = s.baudRate;
    _pendingDataBits = s.dataBits;
    _pendingParity = s.parity;
    _pendingStopBits = s.stopBits;
    _pendingFlow = s.flow;
  }

  void setLocalEcho(bool value) {
    _localEcho = value;
    notify();
  }

  void setViewMode(SerialViewMode value) {
    _viewMode = value;
    notify();
  }

  // ───────────────────────── 연결 ─────────────────────────

  /// [settings](없으면 폼에서 고른 값)로 포트를 연다. 실패하면 [SessionStatus.error]와 [error]가 남는다.
  void connect([SerialSettings? settings]) {
    final s = settings ?? pendingSettings;
    if (s == null || connected) return;
    try {
      final stream = _service.open(s);
      _sub = stream.listen(handleOutput, onError: _onStreamError, onDone: _onStreamDone);
      _active = s;
      _pendingPort = s.portName;
      _error = null;
      setStatus(SessionStatus.connected);
      // 많은 시리얼 콘솔(임베디드 리눅스, 안드로이드 디버그 콘솔 등)은 뭔가 받기 전엔 프롬프트를 찍지 않는다 —
      // 연결하자마자 Enter를 한 번 보내 깨운다.
      writeInput(const [0x0D, 0x0A]);
    } on SerialServiceException catch (e) {
      _error = e;
      setStatus(SessionStatus.error);
    }
    notify();
  }

  @override
  Future<void> disconnect() async {
    _release();
    setStatus(SessionStatus.idle);
    notify();
  }

  void _release() {
    _sub?.cancel();
    _sub = null;
    _service.close();
    if (isLogging) unawaited(stopLogging());
  }

  /// 기기가 갑자기 뽑히는 등 스트림에서 오류가 나면 죽은 포트를 붙잡고 있지 않도록 정리하고 오류 상태로 바꾼다.
  void _onStreamError(Object error) {
    _release();
    _error = switch (error) {
      SerialServiceException() => error,
      SerialPortError() => SerialServiceException(SerialErrorKind.io, fixWindowsAnsiMessage(error.message)),
      _ => SerialServiceException(SerialErrorKind.io, error.toString()),
    };
    setStatus(SessionStatus.error);
    notify();
  }

  /// 기기가 뽑혔을 때 오류 없이 스트림이 그냥 끝나는 경우도 있다 — 그것도 끊김으로 본다.
  void _onStreamDone() {
    if (!connected) return;
    _onStreamError(SerialServiceException(SerialErrorKind.deviceDisconnected));
  }

  // ───────────────────────── 입출력 ─────────────────────────

  @override
  void handleOutput(Uint8List chunk) {
    _rawBytes.addAll(chunk);
    if (_rawBytes.length > _rawBytesTrimAt) {
      _rawBytes.removeRange(0, _rawBytes.length - _maxRawBytes);
    }
    super.handleOutput(chunk);
    _scheduleNotify();
  }

  @override
  void writeInput(List<int> bytes) {
    if (!connected) return;
    unawaited(_write(Uint8List.fromList(bytes)));
  }

  // 실제 쓰기는 별도 isolate에서 돈다(SerialService.write) — 여기서 기다리면 호출자(키 입력, LineSender)가
  // 멈추므로 기다리지 않고 흘려보낸다. 끊긴 경우의 오류 처리만 비동기로 따라간다.
  Future<void> _write(Uint8List bytes) async {
    try {
      await _service.write(bytes);
    } on SerialServiceException catch (e) {
      _onStreamError(e);
    }
  }

  /// LineSender에서 한 줄을 보낸다. 로컬 에코가 켜져 있으면 보낸 내용을 터미널 화면에도 그대로 쓴다
  /// (시리얼 장치는 입력을 에코해 주지 않는 경우가 많다).
  @override
  void send(String text) {
    if (!connected) return;
    final line = text + lineEnding.suffix;
    writeInput(utf8.encode(line));
    if (_localEcho && connected) terminal.write(line);
  }

  /// 시리얼에는 칸 수를 알릴 곳이 없다.
  @override
  void onTerminalResize(int width, int height, int pixelWidth, int pixelHeight) {}

  /// 고빈도 스트림에서 청크마다 다시 그리지 않도록 한 번에 모아 알린다 (바이트 수·Hex 보기용 —
  /// 터미널 자체는 xterm2가 알아서 다시 그린다).
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notify();
    });
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }
}
