import 'dart:typed_data';

import 'package:daylight_terminal/services/remote_text_file.dart';

/// 메모리 안의 가짜 서버 파일 시스템. 시각은 [clock]이 올라가며 쓸 때마다 바뀐다.
class FakeRemoteFs implements RemoteFs {
  final Map<String, Uint8List> files = {};
  final Map<String, RemoteStat> stats = {};
  final Set<String> dirs = {'/'};
  final Map<String, String> links = {};
  final List<String> log = [];

  int clock = 1000;

  /// true면 폴더에 새 파일을 만들 수 없다 (임시 파일 쓰기가 막힌 경우).
  bool dirReadOnly = false;

  /// 설정하면 다음 [write]가 이 오류로 실패한다.
  Object? failNextWrite;

  void put(String path, List<int> bytes, {int mode = 420, int uid = 1000, int gid = 1000, int? mtime}) {
    files[path] = Uint8List.fromList(bytes);
    stats[path] = RemoteStat(
      type: RemoteFileType.regular,
      size: bytes.length,
      mtime: mtime ?? clock++,
      mode: mode,
      uid: uid,
      gid: gid,
    );
  }

  /// 다른 사람이 서버에서 파일을 고쳤다.
  void touchExternally(String path, List<int> bytes) {
    final old = stats[path]!;
    put(path, bytes, mode: old.mode!, uid: old.uid!, gid: old.gid!);
  }

  @override
  Future<String> resolve(String path) async => links[path] ?? path;

  @override
  Future<RemoteStat> stat(String path) async {
    final s = stats[path];
    if (s != null) return s;
    if (dirs.contains(path)) return const RemoteStat(type: RemoteFileType.directory, size: 0);
    throw RemoteNotFound(path);
  }

  @override
  Future<Uint8List> read(String path) async {
    log.add('read $path');
    final b = files[path];
    if (b == null) throw RemoteNotFound(path);
    return b;
  }

  @override
  Future<void> write(String path, Uint8List data) async {
    log.add('write $path');
    final fail = failNextWrite;
    if (fail != null) {
      failNextWrite = null;
      throw fail;
    }
    final existing = stats[path];
    if (existing == null && dirReadOnly) throw StateError('permission denied');
    put(path, data, mode: existing?.mode ?? 420, uid: existing?.uid ?? 1000, gid: existing?.gid ?? 1000);
  }

  @override
  Future<void> rename(String from, String to) async {
    log.add('rename $from $to');
    final b = files.remove(from);
    final s = stats.remove(from);
    if (b == null || s == null) throw RemoteNotFound(from);
    files[to] = b;
    stats[to] = s;
  }

  @override
  Future<void> remove(String path) async {
    log.add('remove $path');
    files.remove(path);
    stats.remove(path);
  }

  @override
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid}) async {
    log.add('setAttrs $path mode=$mode uid=$uid');
    final s = stats[path];
    if (s == null) throw RemoteNotFound(path);
    stats[path] = RemoteStat(
      type: s.type,
      size: s.size,
      mtime: s.mtime,
      mode: mode ?? s.mode,
      uid: uid ?? s.uid,
      gid: gid ?? s.gid,
    );
  }
}
