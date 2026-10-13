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

  /// 파일/폴더를 OS의 기본 프로그램으로 연다 (더블클릭한 것과 같다).
  static Future<void> open(String path) async {
    if (Platform.isWindows) {
      // explorer.exe에 경로를 주면 연결된 프로그램으로 열고, 폴더면 그 폴더를 연다.
      await Process.start('explorer', [path], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    }
  }
}
