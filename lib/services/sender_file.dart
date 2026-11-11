import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum SenderFileError { tooLarge, notUtf8, binary, io }

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
  const SenderDocument(this.text, this.eol, {this.bom = false});

  final String text;
  final String eol;

  /// 파일 맨 앞에 UTF-8 BOM이 있었는가. 원격 편집기는 저장할 때 그대로 되돌린다 (LineSender는 무시한다).
  final bool bom;
}

/// LineSender의 스크립트 파일 읽기/쓰기. UTF-8 텍스트만 다룬다.
abstract final class SenderFile {
  /// 스크립트는 사람이 한 줄씩 보내는 것이라 이보다 큰 파일은 텍스트 칸에 넣지 않는다.
  static const maxBytes = 2 * 1024 * 1024;

  static const suggestedName = 'line-sender.txt';

  /// 끌어넣기로 바로 열 수 있는 텍스트 파일 확장자(소문자, 점 없음). 이 밖의 파일은 열지 않는다.
  static const textExtensions = {
    'txt',
    'md',
    'markdown',
    'cfg',
    'conf',
    'config',
    'ini',
    'env',
    'properties',
    'toml',
    'yaml',
    'yml',
    'json',
    'xml',
    'csv',
    'tsv',
    'log',
    'sh',
    'bash',
    'zsh',
    'fish',
    'bat',
    'cmd',
    'ps1',
    'sql',
    'py',
    'rb',
    'pl',
    'js',
    'ts',
    'service',
    'rules',
    'list',
    'repo',
    'hosts',
    'cnf',
    'gitignore',
  };

  /// [path]가 끌어넣어 열 수 있는 텍스트 파일 형식인가. 확장자 없는 점 파일(`.env`, `.gitignore`)도 이름으로 본다.
  static bool isSupportedText(String path) {
    final name = path.split(RegExp(r'[\\/]')).last.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot == -1) return false;
    return textExtensions.contains(name.substring(dot + 1));
  }

  static Future<SenderDocument> read(String path) async {
    try {
      final file = File(path);
      if (await file.length() > maxBytes) throw const SenderFileException(SenderFileError.tooLarge);
      return decode(await file.readAsBytes());
    } on FileSystemException catch (e) {
      throw SenderFileException(SenderFileError.io, e.message);
    }
  }

  /// UTF-8 [bytes]를 문서로 바꾼다 (BOM은 떼어 [SenderDocument.bom]에 기억한다). 크기 한도를 넘거나 UTF-8이 아니면
  /// 던진다. [rejectBinary]이면 NUL 바이트가 있는 것(이미지·실행 파일 등)도 던진다.
  static SenderDocument decode(Uint8List bytes, {bool rejectBinary = false}) {
    if (bytes.length > maxBytes) throw const SenderFileException(SenderFileError.tooLarge);
    // UTF-8 BOM(메모장 등이 붙인다)은 내용이 아니다.
    final bom = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
    if (bom) bytes = Uint8List.sublistView(bytes, 3);
    if (rejectBinary && bytes.contains(0)) throw const SenderFileException(SenderFileError.binary);
    final String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      throw const SenderFileException(SenderFileError.notUtf8);
    }
    final eol = raw.contains('\r\n') ? '\r\n' : '\n';
    return SenderDocument(raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'), eol, bom: bom);
  }

  /// [doc]을 파일이 원래 쓰던 줄바꿈·BOM 그대로 UTF-8 바이트로 만든다.
  static Uint8List encode(SenderDocument doc) {
    final text = doc.eol == '\n' ? doc.text : doc.text.replaceAll('\n', doc.eol);
    final body = utf8.encode(text);
    if (!doc.bom) return Uint8List.fromList(body);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
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
