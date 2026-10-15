/// 패리티 비트.
enum SerialParity { none, odd, even, mark, space }

/// 흐름 제어.
enum SerialFlow { none, rtsCts, xonXoff, dtrDsr }

/// 하나의 시리얼 연결 설정. 기본은 흔한 8N1, 흐름 제어 없음.
class SerialSettings {
  const SerialSettings({
    required this.portName,
    this.baudRate = 115200,
    this.dataBits = 8,
    this.parity = SerialParity.none,
    this.stopBits = 1,
    this.flow = SerialFlow.none,
  });

  final String portName;
  final int baudRate;

  /// 5~8.
  final int dataBits;
  final SerialParity parity;

  /// 1 또는 2.
  final int stopBits;
  final SerialFlow flow;

  static const dataBitsChoices = [5, 6, 7, 8];
  static const stopBitsChoices = [1, 2];
  static const commonBaudRates = <int>[1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600];

  /// 상태 표시줄 등에 쓰는 "115200 8N1" 모양.
  String get summary {
    final p = switch (parity) {
      SerialParity.none => 'N',
      SerialParity.odd => 'O',
      SerialParity.even => 'E',
      SerialParity.mark => 'M',
      SerialParity.space => 'S',
    };
    return '$baudRate $dataBits$p$stopBits';
  }
}
