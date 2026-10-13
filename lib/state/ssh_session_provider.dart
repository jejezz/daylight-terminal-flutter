import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/file_item.dart';
import '../models/ssh_profile.dart';
import '../models/transfer.dart';
import '../services/drag_staging.dart';
import '../services/profile_store.dart';
import '../services/shell_commands.dart';
import '../services/ssh_connection.dart';
import 'terminal_session.dart';

export 'terminal_session.dart' show SessionStatus;

enum SessionError { hostKeyMismatch, closed, other }

/// 탭 하나 = SSH 연결 하나. 같은 연결 위에서 셸(터미널)과 SFTP(탐색기)를 함께 쓴다.
///
/// 터미널의 현재 경로와 탐색기 경로는 **자동으로 맞추지 않는다.** 사용자가 메뉴로
/// 요청할 때만 [moveTerminalTo] / [syncExplorerToTerminal]이 한쪽을 다른 쪽에 맞춘다.
class SshSessionProvider extends TerminalSession {
  SshSessionProvider(this.store, {super.scrollback});

  final ProfileStore store;

  SshConnection? _conn;
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  SessionError? _error;
  String? _errorDetail;
  SshProfile? _profile;

  // SFTP 탐색기 상태
  String _remotePath = '/';
  List<FileItem> _entries = const [];
  bool _sftpLoading = false;
  String? _sftpError;
  final List<Transfer> _transfers = [];

  SessionError? get error => _error;
  String? get errorDetail => _errorDetail;
  SshProfile? get profile => _profile;
  String get remotePath => _remotePath;
  List<FileItem> get entries => _entries;
  bool get sftpLoading => _sftpLoading;
  String? get sftpError => _sftpError;
  List<Transfer> get transfers => _transfers;

  @override
  String get tabTitle => _profile?.label ?? '';

  @override
  String get statusLabel => _profile?.label ?? '';

  @override
  String get logName => _profile?.host ?? 'ssh';

  // ───────────────────────── 터미널 ─────────────────────────

  @override
  void writeInput(List<int> bytes) {
    if (!connected) return;
    try {
      _conn?.shell.stdin.add(Uint8List.fromList(bytes));
    } catch (e) {
      _fail(SessionError.other, e.toString());
    }
  }

  @override
  void onTerminalResize(int width, int height, int pixelWidth, int pixelHeight) =>
      _conn?.shell.resizeTerminal(width, height, pixelWidth, pixelHeight);

  // ───────────────────────── 연결 ─────────────────────────

  /// 연결과 그 뒤의 소켓 수명 전체를 가드 존에서 실행한다 — 네트워크가 끊길 때 소켓에서
  /// 나오는 비동기 오류가 처리되지 않은 채 앱 전체로 새지 않게 한다.
  Future<void> connect(SshProfile profile, {String? password, String? keyPassphrase}) {
    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        await _connect(profile, password: password, keyPassphrase: keyPassphrase);
      } finally {
        if (!done.isCompleted) done.complete();
      }
    }, _onZoneError);
    return done.future;
  }

  void _onZoneError(Object error, StackTrace stack) {
    if (disposed) return;
    if (connected) {
      _fail(SessionError.other, '$error'); // 연결 도중 끊김
    } else {
      debugPrint('ssh: ignored async error after the connection closed: $error');
    }
  }

  Future<void> _connect(SshProfile profile, {String? password, String? keyPassphrase}) async {
    if (status == SessionStatus.connecting || connected) return;
    _profile = profile;
    setStatus(SessionStatus.connecting);
    _error = null;
    _errorDetail = null;
    notify();
    try {
      final conn = await SshConnection.open(
        profile: profile,
        store: store,
        cols: terminal.viewWidth,
        rows: terminal.viewHeight,
        password: password,
        keyPassphrase: keyPassphrase,
      );
      if (disposed) {
        unawaited(conn.close());
        return;
      }
      _conn = conn;
      _stdoutSub = conn.shell.stdout.listen(handleOutput, onError: (Object e) => _fail(SessionError.other, '$e'));
      _stderrSub = conn.shell.stderr.listen(handleOutput);
      unawaited(conn.shell.done.then((_) => _onShellClosed(conn), onError: (Object _) => _onShellClosed(conn)));
      setStatus(SessionStatus.connected);
      notify();
      await loadDir('.');
    } on HostKeyMismatchException {
      _fail(SessionError.hostKeyMismatch, profile.host);
    } catch (e) {
      _fail(SessionError.other, e.toString());
    }
  }

  void _onShellClosed(SshConnection conn) {
    if (_conn != conn || status != SessionStatus.connected) return;
    _fail(SessionError.closed, null);
  }

  void _fail(SessionError kind, String? detail) {
    _teardown();
    setStatus(SessionStatus.error);
    _error = kind;
    _errorDetail = detail;
    notify();
  }

  void _teardown() {
    final conn = _conn;
    _conn = null;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = _stderrSub = null;
    if (conn != null) unawaited(conn.close());
    if (isLogging) unawaited(stopLogging());
    cancelPendingCwd();
  }

  @override
  Future<void> disconnect() async {
    _teardown();
    setStatus(SessionStatus.idle);
    _entries = const [];
    notify();
  }

  // ───────────────────────── 경로 이동 (메뉴로만) ─────────────────────────

  /// "터미널을 이 폴더로 이동": 셸에 `cd`를 입력한다. 앞의 공백은 히스토리에 남지 않게 한다.
  void moveTerminalTo(String path) => typeCommand(' cd -- ${ShellCommands.posixQuote(path)}\r');

  /// "탐색기를 터미널 경로로 이동": 셸에 OSC 7로 현재 경로를 출력시키는 명령을 입력하고,
  /// 돌아온 경로로 탐색기를 옮긴다. 성공하면 true.
  Future<bool> syncExplorerToTerminal() async {
    final path = await requestTerminalCwd(ShellCommands.posixCwdProbe);
    if (path == null) return false;
    await loadDir(path);
    return _sftpError == null;
  }

  // ───────────────────────── SFTP ─────────────────────────

  String _join(String dir, String name) => p.posix.join(dir, name);

  SftpClient? get _sftp => _conn?.sftp;

  Future<void> loadDir(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    _sftpLoading = true;
    notify();
    try {
      final abs = await sftp.absolute(path);
      final names = await sftp.listdir(abs);
      final entries = await Future.wait([
        for (final n in names)
          if (n.filename != '.' && n.filename != '..') _toEntry(sftp, abs, n),
      ]);
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _entries = entries;
      _remotePath = abs;
      _sftpError = null;
    } catch (e) {
      _sftpError = e.toString();
    } finally {
      _sftpLoading = false;
      notify();
    }
  }

  Future<FileItem> _toEntry(SftpClient sftp, String dir, SftpName n) async {
    var isDir = n.attr.isDirectory;
    final isLink = n.attr.isSymbolicLink;
    if (isLink) {
      // 심볼릭 링크는 가리키는 대상이 폴더인지 확인해서, 폴더면 들어갈 수 있게 한다.
      try {
        isDir = (await sftp.stat(_join(dir, n.filename))).isDirectory;
      } catch (_) {}
    }
    final mtime = n.attr.modifyTime;
    return FileItem(
      name: n.filename,
      isDirectory: isDir,
      isLink: isLink,
      size: n.attr.size,
      modified: mtime == null ? null : DateTime.fromMillisecondsSinceEpoch(mtime * 1000),
    );
  }

  Future<void> refresh() => loadDir(_remotePath);
  Future<void> goUp() => loadDir(p.posix.dirname(_remotePath));
  Future<void> openEntry(FileItem e) => loadDir(_join(_remotePath, e.name));
  String pathOf(FileItem e) => _join(_remotePath, e.name);

  Future<void> makeDirectory(String name) async {
    await _sftp?.mkdir(_join(_remotePath, name));
    await refresh();
  }

  Future<void> rename(FileItem e, String newName) async {
    await _sftp?.rename(_join(_remotePath, e.name), _join(_remotePath, newName));
    await refresh();
  }

  Future<void> delete(FileItem e) async {
    final sftp = _sftp;
    if (sftp == null) return;
    await _deleteRecursive(sftp, _join(_remotePath, e.name), e.isDirectory);
    await refresh();
  }

  Future<void> _deleteRecursive(SftpClient sftp, String path, bool isDir) async {
    if (!isDir) {
      await sftp.remove(path);
      return;
    }
    for (final n in await sftp.listdir(path)) {
      if (n.filename == '.' || n.filename == '..') continue;
      await _deleteRecursive(sftp, _join(path, n.filename), n.attr.isDirectory);
    }
    await sftp.rmdir(path);
  }

  // ───────────────────────── 전송 (드래그 앤 드롭 / 메뉴) ─────────────────────────

  /// 현재 폴더에 이미 있는 이름 중 [localPaths]와 겹치는 것.
  List<String> uploadConflicts(List<String> localPaths) {
    final existing = {for (final e in _entries) e.name};
    return [
      for (final path in localPaths)
        if (existing.contains(p.basename(path))) p.basename(path),
    ];
  }

  /// [localPaths](파일/폴더)를 현재 원격 폴더로 올린다. 같은 이름은 덮어쓴다 —
  /// 호출하는 쪽이 [uploadConflicts]로 먼저 확인받는다.
  Future<void> upload(List<String> localPaths) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final target = _remotePath;
    for (final path in localPaths) {
      final t = Transfer(p.basename(path), TransferDirection.upload);
      _transfers.insert(0, t);
      notify();
      try {
        await _uploadPath(sftp, path, _join(target, p.basename(path)), t);
        t.finish();
      } catch (e) {
        t.finish(e);
      }
    }
    if (_remotePath == target) await refresh();
  }

  Future<void> _uploadPath(SftpClient sftp, String local, String remote, Transfer t) async {
    if (await FileSystemEntity.isDirectory(local)) {
      try {
        await sftp.mkdir(remote);
      } catch (_) {
        // 이미 있는 폴더면 그 안에 이어서 올린다.
      }
      await for (final child in Directory(local).list(followLinks: false)) {
        await _uploadPath(sftp, child.path, _join(remote, p.basename(child.path)), t);
      }
      return;
    }
    final file = File(local);
    final length = await file.length();
    t.update(addTotal: length);
    final base = t.done;
    final remoteFile = await sftp.open(
      remote,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
    try {
      final stream = file.openRead().map((c) => c is Uint8List ? c : Uint8List.fromList(c));
      await remoteFile.write(stream, onProgress: (n) => t.update(setDone: base + n)).done;
    } finally {
      await remoteFile.close();
    }
  }

  /// [items]와 같은 이름이 [localDir]에 이미 있는지 확인한다.
  List<String> downloadConflicts(List<FileItem> items, String localDir) => [
    for (final e in items)
      if (FileSystemEntity.typeSync(p.join(localDir, e.name)) != FileSystemEntityType.notFound) e.name,
  ];

  /// [items]를 [localDir] 아래로 내려받는다. 같은 이름은 덮어쓴다. [from]은 원격 폴더(기본: 지금 폴더).
  Future<void> download(List<FileItem> items, String localDir, {String? from}) async {
    final sftp = _sftp;
    if (sftp == null) return;
    for (final e in items) {
      await _downloadItem(sftp, _join(from ?? _remotePath, e.name), p.join(localDir, e.name), e);
    }
  }

  /// [e] 하나를 [localPath](전체 경로)로 내려받는다 — 저장 대화상자와 드래그 앤 드롭(macOS 파일 프로미스)용.
  /// 성공하면 true, 실패하면 전송 목록에 오류를 남기고 false.
  Future<bool> downloadEntryTo(FileItem e, String localPath, {String? from}) async {
    final sftp = _sftp;
    if (sftp == null) return false;
    return _downloadItem(sftp, _join(from ?? _remotePath, e.name), localPath, e);
  }

  /// 끌어내기(드래그 아웃)용: macOS 밖에서는 파일 프로미스가 없으므로, 먼저 임시 폴더에 로컬 사본을
  /// 받아 그 경로를 돌려준다. 하나라도 실패하면 예외를 던진다.
  Future<List<String>> stageForDrag(List<FileItem> items, {String? from}) async {
    final dir = await DragStaging.newDir();
    final paths = <String>[];
    for (final e in items) {
      final local = p.join(dir.path, e.name);
      if (!await downloadEntryTo(e, local, from: from)) {
        throw FileSystemException('download failed', e.name);
      }
      paths.add(local);
    }
    return paths;
  }

  Future<bool> _downloadItem(SftpClient sftp, String remote, String local, FileItem e) async {
    final t = Transfer(e.name, TransferDirection.download);
    _transfers.insert(0, t);
    notify();
    try {
      await _downloadPath(sftp, remote, local, e.isDirectory, t, size: e.size);
      t.finish();
      return true;
    } catch (err) {
      t.finish(err);
      return false;
    }
  }

  Future<void> _downloadPath(SftpClient sftp, String remote, String local, bool isDir, Transfer t, {int? size}) async {
    if (isDir) {
      await Directory(local).create(recursive: true);
      for (final n in await sftp.listdir(remote)) {
        if (n.filename == '.' || n.filename == '..') continue;
        await _downloadPath(
          sftp,
          _join(remote, n.filename),
          p.join(local, n.filename),
          n.attr.isDirectory,
          t,
          size: n.attr.size,
        );
      }
      return;
    }
    t.update(addTotal: size ?? 0);
    final base = t.done;
    final out = File(local).openWrite();
    try {
      await sftp.download(remote, out, onProgress: (n) => t.update(setDone: base + n));
    } finally {
      await out.close();
    }
  }

  void clearFinishedTransfers() {
    _transfers.removeWhere((t) => t.status != TransferStatus.running);
    notify();
  }

  // ───────────────────────── 종료 ─────────────────────────

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
