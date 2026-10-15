import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:daylight_terminal/models/serial_settings.dart';
import 'package:daylight_terminal/services/serial_service.dart';

/// 실제 포트 없이 시리얼 탭을 테스트하기 위한 가짜 서비스.
/// 보낸 바이트는 [written]에 쌓이고, [emit]으로 장치가 보내는 데이터를 흉내 낸다.
class FakeSerialService extends SerialService {
  final _incoming = StreamController<Uint8List>.broadcast();
  final List<int> written = [];
  bool _open = false;

  /// 마지막으로 열 때 받은 설정.
  SerialSettings? openedWith;

  /// 열기를 실패시키려면 채운다.
  SerialServiceException? failOpen;

  /// 쓰기를 실패시키려면 채운다 (장치를 뽑은 상황).
  SerialServiceException? failWrite;

  @override
  bool get isOpen => _open;

  String get writtenText => utf8.decode(written, allowMalformed: true);

  /// 연결할 때 보내는 깨우기용 Enter(CRLF) 같은 것을 비우고 이후에 보낸 것만 본다.
  void clearWritten() => written.clear();

  void emit(String text) => _incoming.add(Uint8List.fromList(utf8.encode(text)));

  void emitBytes(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  /// 오류 없이 스트림이 끝난다 (기기가 뽑혔다).
  Future<void> endStream() => _incoming.close();

  @override
  Stream<Uint8List> open(SerialSettings settings) {
    final fail = failOpen;
    if (fail != null) throw fail;
    openedWith = settings;
    _open = true;
    return _incoming.stream;
  }

  @override
  int write(Uint8List bytes) {
    final fail = failWrite;
    if (fail != null) throw fail;
    written.addAll(bytes);
    return bytes.length;
  }

  @override
  void close() => _open = false;
}
