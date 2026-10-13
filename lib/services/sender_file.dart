import 'dart:convert';
import 'dart:io';

enum SenderFileError { tooLarge, notUtf8, io }

class SenderFileException implements Exception {
  const SenderFileException(this.kind, [this.detail = '']);

  final SenderFileError kind;
  final String detail;

  @override
  String toString() => 'SenderFileException($kind, $detail)';
}

/// LineSender에 불러온 스크립트 한 개. [text]는 줄바꿈을 `\n`으로 통일한 내용이고, [eol]은 파일이 원래 쓰던
/// 줄바꿈이다 — 저장할 때 같은 줄바꿈으로 돌려 놓아서 CRLF 스크립트를 열었다 저장해도 파일 전체가 바뀌지 않는다.
class SenderDocument {
  const SenderDocument(this.text, this.eol);

  final String text;
  final String eol;
}

/// LineSender의 스크립트 파일 읽기/쓰기. UTF-8 텍스트만 다룬다.
abstract final class SenderFile {
  /// 스크립트는 사람이 한 줄씩 보내는 것이라 이보다 큰 파일은 텍스트 칸에 넣지 않는다.
  static const maxBytes = 2 * 1024 * 1024;

  static const suggestedName = 'line-sender.txt';

  static Future<SenderDocument> read(String path) async {
    try {
      final file = File(path);
      if (await file.length() > maxBytes) throw const SenderFileException(SenderFileError.tooLarge);
      var bytes = await file.readAsBytes();
      // UTF-8 BOM(메모장 등이 붙인다)은 내용이 아니다.
      if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }
      final String raw;
      try {
        raw = utf8.decode(bytes);
      } on FormatException {
        throw const SenderFileException(SenderFileError.notUtf8);
      }
      final eol = raw.contains('\r\n') ? '\r\n' : '\n';
      return SenderDocument(raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'), eol);
    } on FileSystemException catch (e) {
      throw SenderFileException(SenderFileError.io, e.message);
    }
  }

  /// [text](줄바꿈 `\n`)를 [eol] 줄바꿈의 UTF-8(BOM 없음)로 쓴다.
  static Future<void> write(String path, String text, {String eol = '\n'}) async {
    try {
      await File(path).writeAsString(eol == '\n' ? text : text.replaceAll('\n', eol), flush: true);
    } on FileSystemException catch (e) {
      throw SenderFileException(SenderFileError.io, e.message);
    }
  }
}
