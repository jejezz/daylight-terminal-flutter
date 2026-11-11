import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'remote_text_file.dart';

/// 이 PC의 디스크 위의 [RemoteFs] — 로컬 셸·시리얼 탭의 편집기가 쓴다.
///
/// 저장은 파일에 바로 쓴다 ([writeInPlace]): 임시 파일을 바꿔 끼우면 Windows에서는 파일의 ACL과 대체 스트림이,
/// POSIX에서는 소유자·권한·하드 링크가 바뀌기 때문이다 (다른 편집기들도 보통 그렇게 쓴다). 수정 시각은 밀리초로 비교한다.
class LocalFs implements RemoteFs {
  const LocalFs();

  @override
  p.Context get pathContext => p.context;

  @override
  bool get writeInPlace => true;

  @override
  Future<String> resolve(String path) async {
    try {
      return await File(path).resolveSymbolicLinks();
    } on FileSystemException {
      return p.normalize(File(path).absolute.path); // 없는 파일: 이어지는 stat이 notFound로 알린다.
    }
  }

  @override
  Future<RemoteStat> stat(String path) async {
    final s = await FileStat.stat(path);
    switch (s.type) {
      case FileSystemEntityType.notFound:
        throw RemoteNotFound(path);
      case FileSystemEntityType.link:
        // FileStat.stat은 링크를 따라가므로 여기 오는 것은 끊어진 링크다.
        throw RemoteNotFound(path);
      default:
        break;
    }
    return RemoteStat(
      type: switch (s.type) {
        FileSystemEntityType.file => RemoteFileType.regular,
        FileSystemEntityType.directory => RemoteFileType.directory,
        _ => RemoteFileType.other,
      },
      size: s.size,
      mtime: s.modified.millisecondsSinceEpoch,
      mode: Platform.isWindows ? null : s.mode & 0xFFF,
    );
  }

  @override
  Future<Uint8List> read(String path) => File(path).readAsBytes();

  @override
  Future<void> write(String path, Uint8List data) => File(path).writeAsBytes(data, flush: true);

  @override
  Future<void> rename(String from, String to) async {
    await File(from).rename(to);
  }

  @override
  Future<void> remove(String path) => File(path).delete();

  /// 로컬 편집은 파일에 바로 쓰므로 호출되지 않는다.
  @override
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid}) async {}
}
