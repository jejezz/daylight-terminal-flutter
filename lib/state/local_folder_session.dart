import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../services/diag_log.dart';
import '../models/file_item.dart';
import 'terminal_session.dart';

/// 왼쪽에 이 PC의 폴더 뷰가 붙는 탭(로컬 셸, 시리얼)의 공통 부분. 폴더 목록, 이동, 복사, 이름 변경, 삭제,
/// 자동 새로 고침을 맡는다. 터미널 경로와는 자동으로 맞추지 않는다.
abstract class LocalFolderSession extends TerminalSession {
  LocalFolderSession({super.scrollback, String? startDirectory}) : _folderPath = startDirectory ?? homeDirectory();

  String _folderPath;
  List<FileItem> _entries = const [];
  bool _folderLoading = false;
  bool _autoRefreshing = false;
  String? _folderError;
  String? _folderErrorPath;
  bool _folderErrorDenied = false;
  String? _folderErrorMovedTo;
  bool _hasListing = false;

  String get folderPath => _folderPath;
  List<FileItem> get entries => _entries;
  bool get folderLoading => _folderLoading;
  String? get folderError => _folderError;

  /// 읽지 못한 폴더 경로. 오류가 없으면 null.
  String? get folderErrorPath => _folderErrorPath;

  /// 권한이 없어서 읽지 못했는가 (Windows errno 5, POSIX EACCES/EPERM).
  bool get folderErrorDenied => _folderErrorDenied;

  /// 읽지 못해서 대신 열어 준 폴더. 이동하지 않았으면 null.
  String? get folderErrorMovedTo => _folderErrorMovedTo;

  /// 오류 안내를 닫는다 (목록은 그대로).
  void dismissFolderError() {
    if (_folderError == null) return;
    _clearFolderError();
    notify();
  }

  void _clearFolderError() {
    _folderError = null;
    _folderErrorPath = null;
    _folderErrorDenied = false;
    _folderErrorMovedTo = null;
  }

  static bool _isAccessDenied(Object e) {
    if (e is PathAccessException) return true;
    if (e is! FileSystemException) return false;
    final code = e.osError?.errorCode;
    return Platform.isWindows ? code == 5 : (code == 13 || code == 1);
  }

  /// [failed]를 못 읽을 때 대신 열 폴더를 찾는다: 위쪽 폴더를 차례로, 홈, 현재 폴더, 임시 폴더 순.
  /// 읽을 수 있는 첫 폴더를 목록으로 싣고 그 경로를 돌려준다. 하나도 없으면 null.
  Future<String?> _loadFallback(String failed) async {
    final candidates = <String>[];
    for (var cur = failed;;) {
      final parent = p.dirname(cur);
      if (parent == cur) break;
      candidates.add(parent);
      cur = parent;
    }
    candidates.addAll([homeDirectory(), Directory.current.path, Directory.systemTemp.path]);
    final tried = <String>{p.normalize(failed)};
    for (final c in candidates) {
      if (!tried.add(p.normalize(c))) continue;
      try {
        final dir = Directory(c);
        _entries = await _list(dir);
        _folderPath = dir.absolute.path;
        _hasListing = true;
        return _folderPath;
      } catch (_) {}
    }
    return null;
  }

  /// 위로 갈 수 있는 폴더인가 (드라이브나 `/` 같은 뿌리는 못 간다).
  bool get canGoUp => p.dirname(_folderPath) != _folderPath;

  static String homeDirectory() =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;

  // ───────────────────────── 경로 이동 (셸이 있는 탭만) ─────────────────────────

  /// "터미널을 이 폴더로 이동" 메뉴를 보일 수 있는 탭인가 (시리얼은 셸이 아니라 못 한다).
  bool get canMoveTerminal => false;

  void moveTerminalTo(String path) {}

  /// "탐색기를 터미널 경로로 이동" 메뉴를 보일 수 있는 탭인가.
  bool get canSyncExplorer => false;

  Future<bool> syncExplorerToTerminal() async => false;

  // ───────────────────────── 폴더 뷰 ─────────────────────────

  Future<List<FileItem>> _list(Directory dir) async {
    final raw = <FileSystemEntity>[];
    await for (final e in dir.list(followLinks: false)) {
      raw.add(e);
    }
    final items = await Future.wait(raw.map(_toItem));
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// 자동 새로 고침: 로딩 표시와 오류 없이 현재 폴더를 다시 읽고, 바뀐 것이 있을 때만 화면을 갱신한다.
  /// 읽는 동안 사용자가 다른 폴더로 옮겼으면 결과를 버린다.
  @override
  bool get autoRefreshReady => true;

  @override
  Future<void> autoRefresh() async {
    if (_folderLoading || _autoRefreshing) return;
    final path = _folderPath;
    _autoRefreshing = true;
    try {
      final items = await _list(Directory(path));
      if (disposed || _folderLoading || _folderPath != path || listEquals(items, _entries)) return;
      _entries = items;
      notify();
    } catch (_) {
      // 일시적인 오류는 다음 주기에 다시 시도한다.
    } finally {
      _autoRefreshing = false;
    }
  }

  /// [path]를 연다. 못 읽으면 오류를 따로 기록한다. 이미 보고 있는 목록이 있고 다른 폴더로 가려던 것이면 그 자리에
  /// 남고, 보던 폴더 자체가 못 읽게 됐거나 보여 줄 목록이 아직 없으면 읽을 수 있는 폴더로 옮겨 간다.
  Future<void> loadFolder(String path) async {
    final done = DiagLog.begin('local.loadFolder');
    _folderLoading = true;
    notify();
    try {
      final dir = Directory(path);
      _entries = await _list(dir);
      _folderPath = dir.absolute.path;
      _hasListing = true;
      _clearFolderError();
    } catch (e) {
      _folderError = e.toString();
      _folderErrorPath = Directory(path).absolute.path;
      _folderErrorDenied = _isAccessDenied(e);
      _folderErrorMovedTo = null;
      final stayHere = _hasListing && p.normalize(_folderErrorPath!) != p.normalize(_folderPath);
      if (!stayHere) {
        try {
          _folderErrorMovedTo = await _loadFallback(_folderErrorPath!);
        } catch (_) {}
      }
    } finally {
      _folderLoading = false;
      notify();
      done();
    }
  }

  Future<FileItem> _toItem(FileSystemEntity e) async {
    final name = p.basename(e.path);
    final isLink = e is Link;
    var isDir = e is Directory;
    if (isLink) {
      try {
        isDir = await FileSystemEntity.isDirectory(e.path); // 링크가 가리키는 쪽
      } catch (_) {}
    }
    int? size;
    DateTime? modified;
    try {
      final stat = await e.stat();
      modified = stat.modified;
      if (!isDir) size = stat.size;
    } catch (_) {
      // 권한이 없는 항목은 이름만 보여 준다.
    }
    return FileItem(name: name, isDirectory: isDir, isLink: isLink, size: size, modified: modified);
  }

  Future<void> refreshFolder() {
    restartAutoRefreshTimer();
    return loadFolder(_folderPath);
  }

  Future<void> goUp() => loadFolder(p.dirname(_folderPath));
  Future<void> openEntry(FileItem e) => loadFolder(pathOf(e));
  String pathOf(FileItem e) => p.join(_folderPath, e.name);

  Future<void> makeDirectory(String name) async {
    await Directory(p.join(_folderPath, name)).create();
    await refreshFolder();
  }

  Future<void> rename(FileItem e, String newName) async {
    final from = pathOf(e);
    final to = p.join(_folderPath, newName);
    if (e.isDirectory && !e.isLink) {
      await Directory(from).rename(to);
    } else if (e.isLink) {
      await Link(from).rename(to);
    } else {
      await File(from).rename(to);
    }
    await refreshFolder();
  }

  /// [sources](이 PC의 파일/폴더)를 [to](기본: 지금 폴더)로 복사한다. 이미 [to] 안에 있는 것과 자기 자신(안)으로 가는 것은
  /// 건너뛰고, 같은 이름은 덮어쓴다 — 호출하는 쪽이 [copyConflicts]로 먼저 확인받는다. 복사한 최상위 이름을 돌려준다.
  Future<List<String>> copyIn(List<String> sources, {String? to}) async {
    final dest = to ?? _folderPath;
    final done = <String>[];
    for (final src in transferable(sources, dest)) {
      await _copyEntity(src, p.join(dest, p.basename(src)));
      done.add(p.basename(src));
    }
    await refreshFolder();
    return done;
  }

  /// [sources](이 PC의 파일/폴더)를 [to](기본: 지금 폴더)로 옮긴다. 같은 이름이 없으면 이름만 바꿔 옮기고(드라이브가
  /// 다르면 복사한 뒤 지운다), 있으면 복사처럼 덮어쓴 뒤 원본을 지운다 — 호출하는 쪽이 [copyConflicts]로 먼저 확인받는다.
  /// 옮긴 최상위 이름을 돌려준다.
  Future<List<String>> moveIn(List<String> sources, {String? to}) async {
    final dest = to ?? _folderPath;
    final done = <String>[];
    for (final src in transferable(sources, dest)) {
      final target = p.join(dest, p.basename(src));
      if (FileSystemEntity.typeSync(target, followLinks: false) == FileSystemEntityType.notFound) {
        try {
          await _renameEntity(src, target);
        } on FileSystemException {
          // 다른 드라이브(볼륨)로는 이름만 바꿔서 옮길 수 없다.
          await _copyEntity(src, target);
          await _deleteEntity(src);
        }
      } else {
        await _copyEntity(src, target);
        await _deleteEntity(src);
      }
      done.add(p.basename(src));
    }
    await refreshFolder();
    return done;
  }

  /// [sources] 중 [to](기본: 지금 폴더)에 같은 이름이 이미 있는 것.
  List<String> copyConflicts(List<String> sources, {String? to}) {
    final dest = to ?? _folderPath;
    return [
      for (final src in transferable(sources, dest))
        if (FileSystemEntity.typeSync(p.join(dest, p.basename(src)), followLinks: false) !=
            FileSystemEntityType.notFound)
          p.basename(src),
    ];
  }

  /// [sources] 중 [dest] 폴더로 옮기거나 복사할 수 있는 것. 이미 [dest] 안에 있는 것, 자기 자신, 자기 안쪽 폴더로 가는
  /// 것은 뺀다 (폴더를 자기 하위 폴더로 옮길 수 없다).
  static List<String> transferable(List<String> sources, String dest) => [
    for (final s in sources)
      if (!p.equals(p.dirname(s), dest) && !p.equals(s, dest) && !p.isWithin(s, dest)) s,
  ];

  Future<void> _renameEntity(String from, String to) async {
    switch (FileSystemEntity.typeSync(from, followLinks: false)) {
      case FileSystemEntityType.directory:
        await Directory(from).rename(to);
      case FileSystemEntityType.link:
        await Link(from).rename(to);
      default:
        await File(from).rename(to);
    }
  }

  Future<void> _deleteEntity(String path) async {
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.link:
        await Link(path).delete();
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      default:
        await File(path).delete();
    }
  }

  Future<void> _copyEntity(String from, String to) async {
    if (await FileSystemEntity.isDirectory(from)) {
      await Directory(to).create(recursive: true);
      await for (final child in Directory(from).list(followLinks: false)) {
        await _copyEntity(child.path, p.join(to, p.basename(child.path)));
      }
    } else {
      await File(from).copy(to);
    }
  }

  /// 영구 삭제다 (휴지통을 거치지 않는다). 링크는 가리키는 대상이 아니라 링크만 지운다.
  Future<void> delete(FileItem e) async {
    await _deleteEntity(pathOf(e));
    await refreshFolder();
  }

  /// 자주 가는 곳: 홈, 바탕화면, 다운로드, 문서(있는 것만), Windows는 연결된 드라이브.
  Future<List<(String label, String path)>> places() async {
    final home = homeDirectory();
    final candidates = <(String, String)>[
      ('~', home),
      ('Desktop', p.join(home, 'Desktop')),
      ('Downloads', p.join(home, 'Downloads')),
      ('Documents', p.join(home, 'Documents')),
    ];
    final result = <(String, String)>[];
    for (final (label, path) in candidates) {
      if (await Directory(path).exists()) result.add((label, path));
    }
    if (Platform.isWindows) {
      final checks = await Future.wait([
        for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
          Directory('${String.fromCharCode(c)}:\\')
              .exists()
              .timeout(const Duration(milliseconds: 400), onTimeout: () => false),
      ]);
      for (var i = 0; i < checks.length; i++) {
        if (checks[i]) {
          final d = '${String.fromCharCode('A'.codeUnitAt(0) + i)}:\\';
          result.add((d, d));
        }
      }
    }
    return result;
  }
}
