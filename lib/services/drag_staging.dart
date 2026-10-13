import 'dart:io';

import 'package:path/path.dart' as p;

/// 끌어내기(드래그 아웃)할 원격 파일의 임시 로컬 사본을 두는 폴더.
///
/// 드래그가 끝나도 탐색기가 아직 복사 중일 수 있으므로 바로 지우지 않고, 다음 드래그를 시작할 때와
/// 앱을 끝낼 때 지운다.
class DragStaging {
  static Directory get root => Directory(p.join(Directory.systemTemp.path, 'daylight_terminal_drag'));

  /// 이전 사본을 지우고 이번 드래그용 새 폴더를 만든다.
  static Future<Directory> newDir() async {
    await clean();
    return Directory(p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}')).create(recursive: true);
  }

  static Future<void> clean() async {
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } on FileSystemException {
      // 다른 프로그램이 아직 쓰는 중이면 다음 기회에 지운다.
    }
  }
}
