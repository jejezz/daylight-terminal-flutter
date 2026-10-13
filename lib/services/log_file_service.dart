// portside-flutter의 LogFileService에서 가져와 Daylight Terminal에 맞게 고침.
import 'dart:io';
import 'dart:typed_data';

/// 터미널 출력을 파일에 기록한다. 시작/정지만 하는 얇은 래퍼 —
/// 언제 기록할지, 어떤 형태(원본/이스케이프 제거)로 쓸지는 상위(세션)의 몫이다.
class LogFileService {
  IOSink? _sink;
  File? _file;

  bool get isLogging => _sink != null;

  /// 지금 기록 중인 파일, 없으면(정지 후) 바로 이전에 기록했던 파일의 경로.
  String? get filePath => _file?.path;

  /// 기본 저장 폴더 — 없으면 만들어서 경로를 반환한다.
  /// 네이티브 Windows 프로세스는 HOME이 아니라 USERPROFILE만 채워준다.
  static Future<String> defaultDirectory() async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    final dir = Directory('$home/Downloads/daylight_terminal_logs');
    await dir.create(recursive: true);
    return dir.path;
  }

  /// `<host>_<yyyyMMdd_HHmmss>.log` 형태의 기본 파일 이름 제안.
  static String suggestedFileName(String host, [DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
    final safeHost = host.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '${safeHost}_$stamp.log';
  }

  Future<void> start(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    _file = file;
  }

  void write(Uint8List bytes) => _sink?.add(bytes);

  Future<void> stop() async {
    final sink = _sink;
    _sink = null;
    // _file은 그대로 둔다 — "탐색기에서 보기"가 정지 직후에도 방금 기록한
    // 파일 위치를 열 수 있어야 한다. 다음 start()가 덮어쓴다.
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }
}
