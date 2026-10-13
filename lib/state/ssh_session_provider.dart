import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xterm2/xterm.dart';

import '../models/line_ending.dart';
import '../models/remote_entry.dart';
import '../models/ssh_profile.dart';
import '../models/transfer.dart';
import '../services/ansi_stripper.dart';
import '../services/drag_staging.dart';
import '../services/log_file_service.dart';
import '../services/profile_store.dart';
import '../services/ssh_connection.dart';

enum SessionStatus { idle, connecting, connected, error }

enum SessionError { hostKeyMismatch, closed, other }

/// 탭 하나 = SSH 연결 하나. 같은 연결 위에서 셸(터미널)과 SFTP(탐색기)를 함께 쓴다.
///
/// 터미널의 현재 경로와 탐색기 경로는 **자동으로 맞추지 않는다.** 사용자가 메뉴로
/// 요청할 때만 [moveTerminalTo] / [syncExplorerToTerminal]이 한쪽을 다른 쪽에 맞춘다.
class SshSessionProvider extends ChangeNotifier {
  SshSessionProvider(this.store, {int scrollback = 10000}) : terminal = Terminal(maxLines: scrollback) {
    _bind(terminal);
  }

  final ProfileStore store;
  final LogFileService _log = LogFileService();

  final Terminal terminal;

  SshConnection? _conn;
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;
  late final ByteConversionSink _terminalSink = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(_FnSink((s) => terminal.write(s)));
  ByteConversionSink? _logSink;
  bool _disposed = false;

  SessionStatus _status = SessionStatus.idle;
  SessionError? _error;
  String? _errorDetail;
  SshProfile? _profile;

  LineEnding _lineEnding = LineEnding.cr;
  bool _stripAnsi = false;

  // SFTP 탐색기 상태
  String _remotePath = '/';
  List<RemoteEntry> _entries = const [];
  bool _sftpLoading = false;
  String? _sftpError;
  final List<Transfer> _transfers = [];

  Completer<String?>? _cwdWaiter;

  SessionStatus get status => _status;
  bool get connected => _status == SessionStatus.connected;
  SessionError? get error => _error;
  String? get errorDetail => _errorDetail;
  SshProfile? get profile => _profile;
  LineEnding get lineEnding => _lineEnding;
  bool get stripAnsi => _stripAnsi;
  bool get isLogging => _log.isLogging;
  String? get logFilePath => _log.filePath;
  String get remotePath => _remotePath;
  List<RemoteEntry> get entries => _entries;
  bool get sftpLoading => _sftpLoading;
  String? get sftpError => _sftpError;
  List<Transfer> get transfers => _transfers;

  String get tabTitle => _profile?.label ?? '';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ───────────────────────── 터미널 ─────────────────────────

  void _bind(Terminal t) {
    t.onOutput = (data) => _write(utf8.encode(data));
    t.onResize = (w, h, pw, ph) => _conn?.shell.resizeTerminal(w, h, pw, ph);
    t.onCurrentDirectoryChange = _onTerminalCwd;
  }

  void _write(List<int> bytes) {
    if (!connected) return;
    try {
      _conn?.shell.stdin.add(Uint8List.fromList(bytes));
    } catch (e) {
      _fail(SessionError.other, e.toString());
    }
  }

  void setLineEnding(LineEnding value) {
    _lineEnding = value;
    _notify();
  }

  void setStripAnsi(bool value) {
    _stripAnsi = value;
    if (_log.isLogging) _resetLogSink();
    _notify();
  }

  /// LineSender에서 한 줄을 보낸다. 설정된 줄 끝 문자를 붙인다.
  /// SSH는 원격 셸이 입력을 에코해 주므로 로컬 에코는 하지 않는다.
  void send(String text) => _write(utf8.encode(text + _lineEnding.suffix));

  void clearTerminal() => terminal.clear();

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
    if (_disposed) return;
    if (connected) {
      _fail(SessionError.other, '$error'); // 연결 도중 끊김
    } else {
      debugPrint('ssh: ignored async error after the connection closed: $error');
    }
  }

  Future<void> _connect(SshProfile profile, {String? password, String? keyPassphrase}) async {
    if (_status == SessionStatus.connecting || connected) return;
    _profile = profile;
    _status = SessionStatus.connecting;
    _error = null;
    _errorDetail = null;
    _notify();
    try {
      final conn = await SshConnection.open(
        profile: profile,
        store: store,
        cols: terminal.viewWidth,
        rows: terminal.viewHeight,
        password: password,
        keyPassphrase: keyPassphrase,
      );
      if (_disposed) {
        unawaited(conn.close());
        return;
      }
      _conn = conn;
      _stdoutSub = conn.shell.stdout.listen(_onData, onError: (Object e) => _fail(SessionError.other, '$e'));
      _stderrSub = conn.shell.stderr.listen(_onData);
      unawaited(conn.shell.done.then((_) => _onShellClosed(conn), onError: (Object _) => _onShellClosed(conn)));
      _status = SessionStatus.connected;
      _notify();
      await loadDir('.');
    } on HostKeyMismatchException {
      _fail(SessionError.hostKeyMismatch, profile.host);
    } catch (e) {
      _fail(SessionError.other, e.toString());
    }
  }

  void _onData(Uint8List chunk) {
    if (_log.isLogging) {
      if (_logSink == null) {
        _log.write(chunk);
      } else {
        _logSink!.add(chunk);
      }
    }
    _terminalSink.add(chunk);
  }

  void _onShellClosed(SshConnection conn) {
    if (_conn != conn || _status != SessionStatus.connected) return;
    _fail(SessionError.closed, null);
  }

  void _fail(SessionError kind, String? detail) {
    _teardown();
    _status = SessionStatus.error;
    _error = kind;
    _errorDetail = detail;
    _notify();
  }

  void _teardown() {
    final conn = _conn;
    _conn = null;
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = _stderrSub = null;
    if (conn != null) unawaited(conn.close());
    if (_log.isLogging) unawaited(_stopLogging());
    final waiter = _cwdWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(null);
  }

  Future<void> disconnect() async {
    _teardown();
    _status = SessionStatus.idle;
    _entries = const [];
    _notify();
  }

  // ───────────────────────── 기록(Recording) ─────────────────────────

  /// 기록을 시작/정지한다. 파일에는 서버에서 받은 출력이 기록된다 — [stripAnsi]가 켜져
  /// 있으면 이스케이프 시퀀스를 뺀 텍스트, 아니면 받은 바이트 그대로. 시작할 때마다
  /// 저장 위치를 묻고, 취소하면 켜지지 않는다. [confirmButtonText]는 저장 대화상자의
  /// 확인 버튼 문구(l10n).
  Future<void> toggleLogging({required String confirmButtonText}) async {
    if (_log.isLogging) {
      await _stopLogging();
      _notify();
      return;
    }
    final host = _profile?.host;
    if (!connected || host == null) return;
    final location = await getSaveLocation(
      initialDirectory: await LogFileService.defaultDirectory(),
      suggestedName: LogFileService.suggestedFileName(host),
      confirmButtonText: confirmButtonText,
    );
    if (location == null) return;
    await _log.start(location.path);
    _resetLogSink();
    _notify();
  }

  /// 이스케이프 제거 모드면 디코더+스트리퍼를 거치는 싱크를, 아니면 null(원본 바이트 기록).
  void _resetLogSink() {
    _logSink?.close();
    if (!_stripAnsi) {
      _logSink = null;
      return;
    }
    final stripper = AnsiStripper();
    _logSink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(
      _FnSink((s) {
        final text = stripper.strip(s);
        if (text.isNotEmpty) _log.write(Uint8List.fromList(utf8.encode(text)));
      }),
    );
  }

  Future<void> _stopLogging() async {
    _logSink?.close();
    _logSink = null;
    await _log.stop();
  }

  // ───────────────────────── 경로 이동 (메뉴로만) ─────────────────────────

  /// "터미널을 이 폴더로 이동": 셸에 `cd`를 입력한다. 앞의 공백은 히스토리에 남지 않게 한다.
  void moveTerminalTo(String path) => _write(utf8.encode(' cd -- ${_shellQuote(path)}\r'));

  /// "탐색기를 터미널 경로로 이동": 셸에 OSC 7로 현재 경로를 출력시키는 명령을 입력하고,
  /// 돌아온 경로로 탐색기를 옮긴다. 성공하면 true.
  Future<bool> syncExplorerToTerminal() async {
    if (!connected) return false;
    final waiter = _cwdWaiter = Completer<String?>();
    _write(utf8.encode('$_cwdProbe\r'));
    final path = await waiter.future.timeout(const Duration(seconds: 3), onTimeout: () => null);
    _cwdWaiter = null;
    if (path == null) return false;
    await loadDir(path);
    return _sftpError == null;
  }

  void _onTerminalCwd(String uri) {
    final waiter = _cwdWaiter;
    if (waiter == null || waiter.isCompleted) return;
    var rest = uri.startsWith('file://') ? uri.substring(7) : uri;
    final slash = rest.indexOf('/');
    if (slash == -1) return;
    rest = rest.substring(slash);
    if (rest.contains('%')) {
      try {
        rest = Uri.decodeFull(rest);
      } on FormatException {
        // 디코딩할 수 없으면 원문 그대로 쓴다.
      }
    }
    waiter.complete(rest);
  }

  /// 셸이 현재 경로를 OSC 7(`ESC ] 7 ; file://호스트/경로 ESC \`)로 출력하게 하는 명령.
  static const _cwdProbe = r''' printf '\033]7;file://%s%s\033\\' "$HOSTNAME" "$PWD"''';

  static String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

  // ───────────────────────── SFTP ─────────────────────────

  String _join(String dir, String name) => p.posix.join(dir, name);

  SftpClient? get _sftp => _conn?.sftp;

  Future<void> loadDir(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    _sftpLoading = true;
    _notify();
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
      _notify();
    }
  }

  Future<RemoteEntry> _toEntry(SftpClient sftp, String dir, SftpName n) async {
    var isDir = n.attr.isDirectory;
    final isLink = n.attr.isSymbolicLink;
    if (isLink) {
      // 심볼릭 링크는 가리키는 대상이 폴더인지 확인해서, 폴더면 들어갈 수 있게 한다.
      try {
        isDir = (await sftp.stat(_join(dir, n.filename))).isDirectory;
      } catch (_) {}
    }
    final mtime = n.attr.modifyTime;
    return RemoteEntry(
      name: n.filename,
      isDirectory: isDir,
      isLink: isLink,
      size: n.attr.size,
      modified: mtime == null ? null : DateTime.fromMillisecondsSinceEpoch(mtime * 1000),
    );
  }

  Future<void> refresh() => loadDir(_remotePath);
  Future<void> goUp() => loadDir(p.posix.dirname(_remotePath));
  Future<void> openEntry(RemoteEntry e) => loadDir(_join(_remotePath, e.name));
  String pathOf(RemoteEntry e) => _join(_remotePath, e.name);

  Future<void> makeDirectory(String name) async {
    await _sftp?.mkdir(_join(_remotePath, name));
    await refresh();
  }

  Future<void> rename(RemoteEntry e, String newName) async {
    await _sftp?.rename(_join(_remotePath, e.name), _join(_remotePath, newName));
    await refresh();
  }

  Future<void> delete(RemoteEntry e) async {
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
      _notify();
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
  List<String> downloadConflicts(List<RemoteEntry> items, String localDir) => [
    for (final e in items)
      if (FileSystemEntity.typeSync(p.join(localDir, e.name)) != FileSystemEntityType.notFound) e.name,
  ];

  /// [items]를 [localDir] 아래로 내려받는다. 같은 이름은 덮어쓴다. [from]은 원격 폴더(기본: 지금 폴더).
  Future<void> download(List<RemoteEntry> items, String localDir, {String? from}) async {
    final sftp = _sftp;
    if (sftp == null) return;
    for (final e in items) {
      await _downloadItem(sftp, _join(from ?? _remotePath, e.name), p.join(localDir, e.name), e);
    }
  }

  /// [e] 하나를 [localPath](전체 경로)로 내려받는다 — 저장 대화상자와 드래그 앤 드롭(macOS 파일 프로미스)용.
  /// 성공하면 true, 실패하면 전송 목록에 오류를 남기고 false.
  Future<bool> downloadEntryTo(RemoteEntry e, String localPath, {String? from}) async {
    final sftp = _sftp;
    if (sftp == null) return false;
    return _downloadItem(sftp, _join(from ?? _remotePath, e.name), localPath, e);
  }

  /// 끌어내기(드래그 아웃)용: macOS 밖에서는 파일 프로미스가 없으므로, 먼저 임시 폴더에 로컬 사본을
  /// 받아 그 경로를 돌려준다. 하나라도 실패하면 예외를 던진다.
  Future<List<String>> stageForDrag(List<RemoteEntry> items, {String? from}) async {
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

  Future<bool> _downloadItem(SftpClient sftp, String remote, String local, RemoteEntry e) async {
    final t = Transfer(e.name, TransferDirection.download);
    _transfers.insert(0, t);
    _notify();
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
    _notify();
  }

  // ───────────────────────── 종료 ─────────────────────────

  /// 앱 종료 요청(⌘Q 등) 시 위젯 dispose가 보장되지 않으므로, 종료 직전에 호출해서
  /// 기록 파일이 확실히 flush/close되게 한다.
  Future<void> prepareForExit() async {
    await _stopLogging();
    await DragStaging.clean();
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
    unawaited(_stopLogging());
    terminal.dispose();
    super.dispose();
  }
}

class _FnSink implements Sink<String> {
  _FnSink(this._onData);
  final void Function(String) _onData;
  @override
  void add(String data) => _onData(data);
  @override
  void close() {}
}
