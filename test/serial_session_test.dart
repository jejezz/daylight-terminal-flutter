import 'dart:io';

import 'package:daylight_terminal/models/line_ending.dart';
import 'package:daylight_terminal/models/serial_settings.dart';
import 'package:daylight_terminal/services/hex_dump.dart';
import 'package:daylight_terminal/services/serial_service.dart';
import 'package:daylight_terminal/state/serial_session.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_serial.dart';

void main() {
  late FakeSerialService serial;
  late Directory tmp;
  late SerialSession session;

  setUp(() async {
    serial = FakeSerialService();
    tmp = await Directory.systemTemp.createTemp('dt_serial_');
    session = SerialSession(service: serial, startDirectory: tmp.path);
  });

  tearDown(() async {
    session.dispose();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  const settings = SerialSettings(portName: 'COM3', baudRate: 9600, dataBits: 7, parity: SerialParity.even, stopBits: 2);

  test('처음에는 연결되지 않았고 줄 끝 문자는 LF다', () {
    expect(session.status, SessionStatus.idle);
    expect(session.lineEnding, LineEnding.lf);
    expect(session.pendingSettings, isNull);
    expect(session.tabTitle, '');
  });

  test('폼에서 고른 값으로 연다', () {
    session
      ..setPendingPort('/dev/ttyUSB0')
      ..setPendingBaud(57600)
      ..setPendingFlow(SerialFlow.rtsCts);
    expect(session.tabTitle, 'ttyUSB0');
    session.connect();
    expect(session.connected, isTrue);
    expect(serial.openedWith!.baudRate, 57600);
    expect(serial.openedWith!.flow, SerialFlow.rtsCts);
    expect(serial.openedWith!.dataBits, 8);
    expect(session.statusLabel, 'ttyUSB0 · 57600 8N1');
  });

  test('연결하면 깨우는 Enter를 한 번 보낸다', () {
    session.connect(settings);
    expect(serial.written, [0x0D, 0x0A]);
    expect(session.statusLabel, 'COM3 · 9600 7E2');
  });

  test('열기에 실패하면 오류 상태가 된다', () {
    serial.failOpen = SerialServiceException(SerialErrorKind.openFailed, 'busy');
    session.connect(settings);
    expect(session.status, SessionStatus.error);
    expect(session.error!.kind, SerialErrorKind.openFailed);
    expect(session.connected, isFalse);
  });

  test('받은 바이트는 터미널과 raw 버퍼에 들어간다', () async {
    session.connect(settings);
    serial.emit('hello\r\n');
    serial.emitBytes([0xFF, 0x00]);
    await Future<void>.delayed(Duration.zero);
    expect(session.terminal.buffer.getText(), contains('hello'));
    expect(session.rawBytes.take(7).toList(), [...'hello\r\n'.codeUnits]);
    expect(session.byteCount, 9);
  });

  test('LineSender: 줄 끝 문자를 붙여 보내고, 로컬 에코가 켜져 있으면 화면에도 쓴다', () async {
    session.connect(settings);
    serial.clearWritten();
    session.send('AT');
    expect(serial.writtenText, 'AT\n');
    expect(session.terminal.buffer.getText(), contains('AT'));
  });

  test('로컬 에코를 끄면 화면에 쓰지 않는다', () {
    session.connect(settings);
    session.setLocalEcho(false);
    serial.clearWritten();
    session.setLineEnding(LineEnding.crlf);
    session.send('AT');
    expect(serial.writtenText, 'AT\r\n');
    expect(session.terminal.buffer.getText(), isNot(contains('AT')));
  });

  test('터미널에서 친 키는 그대로 보낸다 (에코는 장치 몫)', () {
    session.connect(settings);
    serial.clearWritten();
    session.terminal.textInput('a');
    expect(serial.writtenText, 'a');
    expect(session.terminal.buffer.getText(), isNot(contains('a')));
  });

  test('연결 전에는 보내지 않는다', () {
    session.send('x');
    expect(serial.written, isEmpty);
  });

  test('쓰다가 장치가 뽑히면 오류 상태로 바뀌고 포트를 닫는다', () {
    session.connect(settings);
    serial.failWrite = SerialServiceException(SerialErrorKind.io, 'gone');
    session.send('x');
    expect(session.status, SessionStatus.error);
    expect(session.error!.kind, SerialErrorKind.io);
    expect(serial.isOpen, isFalse);
  });

  test('오류 없이 스트림이 끝나도 장치가 분리된 것으로 본다', () async {
    session.connect(settings);
    await serial.endStream();
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.error);
    expect(session.error!.kind, SerialErrorKind.deviceDisconnected);
  });

  test('끊으면 포트를 닫고 idle이 된다', () async {
    session.connect(settings);
    await session.disconnect();
    expect(session.status, SessionStatus.idle);
    expect(serial.isOpen, isFalse);
  });

  test('raw 버퍼는 2MB를 넘으면 앞부분을 버린다', () async {
    session.connect(settings);
    serial.emitBytes(List.filled(1024 * 1024, 0x41));
    serial.emitBytes(List.filled(1024 * 1024, 0x42));
    serial.emitBytes([0x43, 0x44]);
    await Future<void>.delayed(Duration.zero);
    expect(session.byteCount, 2 * 1024 * 1024);
    expect(session.rawBytes.last, 0x44);
    expect(session.rawBytes.first, 0x41);
  });

  test('폴더 뷰는 시리얼 탭에서도 이 PC의 폴더를 읽는다', () async {
    File('${tmp.path}${Platform.pathSeparator}a.txt').writeAsStringSync('x');
    await session.loadFolder(session.folderPath);
    expect(session.entries.map((e) => e.name), ['a.txt']);
    expect(session.canMoveTerminal, isFalse);
    expect(session.canSyncExplorer, isFalse);
  });

  group('hexDump', () {
    test('16바이트씩 오프셋·hex·ASCII로 나눈다', () {
      final out = hexDump('Hello, serial!!\n'.codeUnits);
      expect(out, startsWith('00000000  48 65 6c 6c 6f 2c 20 73'));
      expect(out, contains('|Hello, serial!!.|'));
    });

    test('빈 목록은 빈 문자열', () => expect(hexDump(const []), ''));
  });
}
