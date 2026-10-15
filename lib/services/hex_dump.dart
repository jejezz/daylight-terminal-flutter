import 'dart:math';

/// 바이트 목록을 `hexdump -C` 느낌의 텍스트로 바꾼다. UI/스트림과 무관한
/// 순수 함수라 유닛 테스트로 검증하기 쉽다.
String hexDump(List<int> bytes, {int bytesPerLine = 16}) {
  if (bytes.isEmpty) return '';

  final buffer = StringBuffer();
  for (var offset = 0; offset < bytes.length; offset += bytesPerLine) {
    final end = min(offset + bytesPerLine, bytes.length);
    final chunk = bytes.sublist(offset, end);

    final hex = StringBuffer();
    final ascii = StringBuffer();
    for (var i = 0; i < bytesPerLine; i++) {
      if (i < chunk.length) {
        final b = chunk[i];
        hex.write(b.toRadixString(16).padLeft(2, '0'));
        ascii.write(b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : '.');
      } else {
        hex.write('  ');
      }
      hex.write(i == bytesPerLine ~/ 2 - 1 ? '  ' : ' ');
    }

    buffer
      ..write(offset.toRadixString(16).padLeft(8, '0'))
      ..write('  ')
      ..write(hex.toString())
      ..write('|')
      ..write(ascii.toString())
      ..writeln('|');
  }
  return buffer.toString();
}
