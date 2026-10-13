// portside-flutter에서 가져옴.
import 'dart:io';

/// OS 파일 탐색기(Windows Explorer / macOS Finder)에서 파일 위치를 열어준다.
class FileRevealService {
  static Future<void> reveal(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,$path']);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
  }
}
