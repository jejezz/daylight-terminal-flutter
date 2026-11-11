import 'dart:typed_data';

import 'cp949_table.dart';

/// 편집기가 다루는 글자 인코딩. 기본은 UTF-8이고, 한국어 Windows의 옛 파일(.bat, .ini, CSV 등)과 옛 서버의 글은 CP949(EUC-KR의
/// 확장)로 되어 있는 일이 많아서 이것도 읽고 쓴다. 열 때 어느 쪽인지 정해 두었다가 저장할 때 같은 인코딩으로 되돌린다.
enum TextEncoding {
  utf8('UTF-8'),
  cp949('CP949');

  const TextEncoding(this.label);

  final String label;
}

/// CP949(Microsoft 코드 페이지 949, UHC) 변환. 외부 패키지 없이 표([cp949Table])로 한다 (macOS·Linux에서도 같은 결과).
abstract final class Cp949 {
  /// [bytes]를 글로 바꾼다. CP949가 아닌 바이트가 하나라도 있으면(잘린 글자, 없는 조합, 0x80·0xFF) null.
  static String? decode(Uint8List bytes) {
    final units = <int>[];
    var i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b < 0x80) {
        units.add(b);
        i++;
        continue;
      }
      if (b == 0x80 || b == 0xFF || i + 1 >= bytes.length) return null;
      final t = bytes[i + 1];
      if (t < 0x41 || t > 0xFE) return null;
      final c = cp949Table.codeUnitAt((b - 0x81) * cp949Columns + (t - 0x41));
      if (c == 0xFFFD) return null;
      units.add(c);
      i += 2;
    }
    return String.fromCharCodes(units);
  }

  static Map<int, int>? _reverse;

  /// 글자 → 두 바이트 (선행 << 8 | 뒤). 처음 쓸 때 만든다.
  static Map<int, int> get _toBytes {
    final cached = _reverse;
    if (cached != null) return cached;
    final map = <int, int>{};
    for (var i = 0; i < cp949Table.length; i++) {
      final c = cp949Table.codeUnitAt(i);
      if (c == 0xFFFD) continue;
      map.putIfAbsent(c, () => ((i ~/ cp949Columns + 0x81) << 8) | (i % cp949Columns + 0x41));
    }
    return _reverse = map;
  }

  /// [text]를 CP949 바이트로 바꾼다. CP949에 없는 글자(이모지, 일본어 가나 등)가 있으면 그 첫 글자를 [unencodable]에 담아 돌려준다.
  static ({Uint8List? bytes, String? unencodable}) encode(String text) {
    final map = _toBytes;
    final out = BytesBuilder(copy: false);
    for (final r in text.runes) {
      if (r < 0x80) {
        out.addByte(r);
        continue;
      }
      final pair = r <= 0xFFFF ? map[r] : null;
      if (pair == null) return (bytes: null, unencodable: String.fromCharCode(r));
      out.addByte(pair >> 8);
      out.addByte(pair & 0xFF);
    }
    return (bytes: out.takeBytes(), unencodable: null);
  }
}
