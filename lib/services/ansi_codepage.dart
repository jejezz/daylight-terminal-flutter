import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _MultiByteToWideCharC =
    Int32 Function(Uint32, Uint32, Pointer<Uint8>, Int32, Pointer<Uint16>, Int32);
typedef _MultiByteToWideCharDart = int Function(int, int, Pointer<Uint8>, int, Pointer<Uint16>, int);

/// libserialport가 Windows에서 주는 오류 문구는 시스템 코드 페이지(한국어 Windows는 CP949)로 된 바이트인데,
/// 이를 쓰는 패키지가 UTF-8로 읽다 실패하면 Latin-1로 읽어서 한글이 깨진다("ÀÛ¾÷À»…").
/// 모든 글자가 Latin-1 범위(≤ 0xFF)이고 ASCII가 아닌 글자가 있을 때만, 그 바이트를 되살려 시스템 코드 페이지로 다시 읽는다.
/// 올바른 UTF-8 문구(한글은 0xFF를 넘는다)나 Windows가 아닌 환경은 그대로 돌려준다.
String fixWindowsAnsiMessage(String message) {
  if (!Platform.isWindows) return message;
  final runes = message.runes;
  if (runes.every((r) => r < 0x80) || runes.any((r) => r > 0xFF)) return message;
  try {
    return _decodeAcp(latin1.encode(message)) ?? message;
  } catch (_) {
    return message;
  }
}

String? _decodeAcp(List<int> bytes) {
  final convert = DynamicLibrary.open('kernel32.dll').lookupFunction<_MultiByteToWideCharC, _MultiByteToWideCharDart>(
    'MultiByteToWideChar',
  );
  final input = calloc<Uint8>(bytes.length);
  final output = calloc<Uint16>(bytes.length);
  try {
    input.asTypedList(bytes.length).setAll(0, bytes);
    const cpAcp = 0;
    final n = convert(cpAcp, 0, input, bytes.length, output, bytes.length);
    if (n <= 0) return null;
    return String.fromCharCodes(output.asTypedList(n));
  } finally {
    calloc.free(input);
    calloc.free(output);
  }
}
