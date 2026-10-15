// portside-flutter의 serial_service.dart에서 가져와 데이터 비트·패리티·정지 비트·흐름 제어를 더했다.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../models/serial_settings.dart';
import 'ansi_codepage.dart';

/// [flutter_libserialport]에 대한 얇은 래퍼.
/// 포트 열기/닫기/읽기/쓰기만 담당하고 연결 상태·버퍼 관리는 하지 않는다 (그건 `SerialSession`의 책임).
class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;

  /// 네이티브 라이브러리를 로드할 수 없는 환경(예: 앱 번들 밖에서 도는 `flutter test`)에서도 UI가
  /// 크래시하지 않도록 빈 목록으로 대체한다.
  static List<String> availablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      return const [];
    }
  }

  bool get isOpen => _port != null;

  /// 포트를 열고 수신 스트림을 반환한다. 실패하면 [SerialServiceException]을 던진다.
  Stream<Uint8List> open(SerialSettings settings) {
    close();

    final port = SerialPort(settings.portName);
    if (!port.openReadWrite()) {
      final raw = SerialPort.lastError?.message;
      final detail = raw == null ? null : fixWindowsAnsiMessage(raw);
      port.dispose();
      throw SerialServiceException(SerialErrorKind.openFailed, detail);
    }

    port.config = SerialPortConfig()
      ..baudRate = settings.baudRate
      ..bits = settings.dataBits
      ..parity = switch (settings.parity) {
        SerialParity.none => SerialPortParity.none,
        SerialParity.odd => SerialPortParity.odd,
        SerialParity.even => SerialPortParity.even,
        SerialParity.mark => SerialPortParity.mark,
        SerialParity.space => SerialPortParity.space,
      }
      ..stopBits = settings.stopBits
      ..setFlowControl(switch (settings.flow) {
        SerialFlow.none => SerialPortFlowControl.none,
        SerialFlow.rtsCts => SerialPortFlowControl.rtsCts,
        SerialFlow.xonXoff => SerialPortFlowControl.xonXoff,
        SerialFlow.dtrDsr => SerialPortFlowControl.dtrDsr,
      });

    _port = port;
    _reader = SerialPortReader(port);
    return _reader!.stream;
  }

  /// 바이트를 전송하고 실제로 쓰여진 바이트 수를 반환한다.
  int write(Uint8List bytes) {
    final port = _port;
    if (port == null) {
      throw SerialServiceException(SerialErrorKind.notOpen);
    }
    try {
      return port.write(bytes);
    } on SerialPortError catch (e) {
      // 기기가 도중에 뽑히면 여기서 네이티브 에러가 난다 — 상위가 일관되게 처리할 수 있는 타입으로 감싼다.
      throw SerialServiceException(SerialErrorKind.io, fixWindowsAnsiMessage(e.message));
    }
  }

  /// 이미 뽑혀서 죽은 포트를 닫으려 할 때 네이티브 쪽에서 예외가 나도 앱이 죽지 않도록, 각 단계를 독립적으로 방어한다.
  void close() {
    try {
      _reader?.close();
    } catch (_) {}
    try {
      _port?.close();
    } catch (_) {}
    try {
      _port?.dispose();
    } catch (_) {}
    _reader = null;
    _port = null;
  }
}

/// 오류 종류. 화면 문구는 UI가 l10n으로 고른다 — 서비스는 문구를 모른다.
enum SerialErrorKind {
  /// 포트를 열지 못함.
  openFailed,

  /// 열린 포트 없이 쓰기를 시도함.
  notOpen,

  /// 읽기/쓰기 중 네이티브 오류 (기기를 뽑는 등).
  io,

  /// 수신 스트림이 오류 없이 끝남 — 기기가 뽑혔다.
  deviceDisconnected,
}

class SerialServiceException implements Exception {
  SerialServiceException(this.kind, [this.detail]);

  final SerialErrorKind kind;

  /// OS/libserialport가 준 원문 (번역되지 않음). 없을 수 있다.
  final String? detail;

  @override
  String toString() => detail ?? kind.name;
}
