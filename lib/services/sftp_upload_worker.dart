import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

/// 업로드 워커에게 보내는 요청. 메인 연결과 같은 서버에 **따로** 접속해서 올린다.
///
/// dartssh2는 암호화·무결성 검사를 순수 Dart로 해서, 메인 isolate에서 올리면 그동안 화면 그리기와
/// 키 입력까지 느려진다. 그래서 올리기는 별도 isolate의 별도 SSH 연결에서 하고 메인은 진행 상황만 받는다.
class UploadRequest {
  UploadRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.keyPath,
    required this.password,
    required this.keyPassphrase,
    required this.hostKey,
    required this.items,
    required this.events,
    this.download = false,
  });

  final String host;
  final int port;
  final String username;
  final String? keyPath;
  final String? password;
  final String? keyPassphrase;

  /// 메인 연결이 믿고 있는 호스트 키(`종류 지문`). 다르면 접속하지 않는다.
  final String hostKey;

  /// 올릴 (로컬 경로, 원격 경로) 쌍. 파일이나 폴더.
  /// [download]가 true면 반대로 내려받을 (원격 경로, 로컬 경로) 쌍이다.
  final List<(String, String)> items;
  final SendPort events;

  /// true면 [items]를 서버에서 내려받는다 (같은 워커·같은 메시지를 쓴다).
  final bool download;
}

/// 워커가 보내는 메시지의 종류. 메시지는 `[종류, 항목 번호, 값]` 꼴의 리스트다.
abstract final class UploadEvent {
  /// 접속하지 못했다 (아무것도 올리지 않았다). 메인이 직접 올리는 쪽으로 돌아간다. 값은 오류 글.
  static const connectFailed = 'connectFailed';

  /// 서버에 붙었고 올리기를 시작한다. 값은 취소를 보낼 `SendPort`(항목 번호를 보내면 그 항목이 멈춘다).
  static const ready = 'ready';

  /// 항목에 올릴 바이트가 [값]만큼 늘었다 (폴더 안의 파일을 찾을 때마다).
  static const total = 'total';

  /// 항목에서 지금까지 올린 바이트 (누적).
  static const done = 'done';

  /// 항목을 다 올렸다.
  static const itemOk = 'itemOk';

  /// 사용자가 항목을 취소해서 멈췄다 (올라가던 파일은 서버에서 지운다).
  static const itemCancelled = 'itemCancelled';

  /// 항목 올리기가 실패했다. 값은 오류 글.
  static const itemFailed = 'itemFailed';

  /// 모든 항목이 끝났고 워커가 닫힌다.
  static const finished = 'finished';
}

/// [Isolate.spawn]의 진입점.
Future<void> sftpUploadMain(UploadRequest req) async {
  void send(String kind, [int index = -1, Object? value]) => req.events.send([kind, index, value]);

  SSHClient? client;
  final SftpClient sftp;
  try {
    final socket = await SSHSocket.connect(req.host, req.port, timeout: const Duration(seconds: 15));
    List<SSHKeyPair>? identities;
    final keyPath = req.keyPath;
    if (keyPath != null) {
      identities = SSHKeyPair.fromPem(await File(keyPath).readAsString(), req.keyPassphrase);
    }
    final password = req.password;
    final c = client = SSHClient(
      socket,
      username: req.username,
      identities: identities,
      onPasswordRequest: password == null ? null : () => password,
      onUserInfoRequest: password == null ? null : (request) => [for (final _ in request.prompts) password],
      onVerifyHostKey: (type, fingerprint) {
        final hex = fingerprint.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
        return '$type $hex' == req.hostKey;
      },
    );
    unawaited(c.done.catchError((Object _) {}));
    sftp = await c.sftp();
  } catch (e) {
    client?.close();
    send(UploadEvent.connectFailed, -1, '$e');
    return;
  }
  final commands = ReceivePort();
  final cancels = [for (final _ in req.items) UploadCancel()];
  commands.listen((Object? i) {
    if (i is int && i >= 0 && i < cancels.length) cancels[i].cancel();
  });
  send(UploadEvent.ready, -1, commands.sendPort);

  try {
    for (var i = 0; i < req.items.length; i++) {
      final (from, to) = req.items[i];
      var done = 0;
      final throttle = ProgressThrottle(() => send(UploadEvent.done, i, done));
      try {
        final run = req.download ? downloadPath : uploadPath;
        await run(
          sftp,
          from,
          to,
          cancel: cancels[i],
          onTotal: (n) => send(UploadEvent.total, i, n),
          onProgress: (n) {
            done = n;
            throttle.poke();
          },
        );
        send(UploadEvent.done, i, done);
        send(UploadEvent.itemOk, i);
      } on UploadCancelled {
        send(UploadEvent.itemCancelled, i);
      } catch (e) {
        send(UploadEvent.itemFailed, i, '$e');
      }
    }
  } finally {
    client.close();
    commands.close();
    send(UploadEvent.finished);
  }
}

/// 진행 알림을 0.1초에 한 번으로 줄인다 (32KB마다 화면을 다시 그리지 않게).
class ProgressThrottle {
  ProgressThrottle(this.fire, {this.interval = const Duration(milliseconds: 100)});

  final void Function() fire;
  final Duration interval;
  final _clock = Stopwatch()..start();
  int _lastMs = -1 << 30;

  void poke() {
    final now = _clock.elapsedMilliseconds;
    if (now - _lastMs < interval.inMilliseconds) return;
    _lastMs = now;
    fire();
  }
}

/// 업로드를 취소했다.
class UploadCancelled implements Exception {
  const UploadCancelled();
  @override
  String toString() => 'cancelled';
}

/// 올리는 도중에 멈추게 하는 손잡이. [cancel]을 부르면 지금 쓰던 파일을 바로 끊는다.
class UploadCancel {
  bool requested = false;
  Future<void> Function()? _abort;

  void cancel() {
    requested = true;
    final abort = _abort;
    if (abort != null) unawaited(abort());
  }
}

/// [local](파일 또는 폴더)을 원격 [remote]로 올린다. 폴더는 안을 따라 내려가며 올린다.
/// [onTotal]은 올릴 바이트가 늘 때마다, [onProgress]는 이 항목에서 지금까지 올린 바이트(누적)와 함께 불린다.
/// [cancel]이 불리면 [UploadCancelled]를 던지고, 쓰던 원격 파일은 지운다.
Future<void> uploadPath(
  SftpClient sftp,
  String local,
  String remote, {
  required UploadCancel cancel,
  required void Function(int addTotal) onTotal,
  required void Function(int done) onProgress,
}) async {
  var done = 0;
  Future<void> walk(String l, String r) async {
    if (cancel.requested) throw const UploadCancelled();
    if (await FileSystemEntity.isDirectory(l)) {
      try {
        await sftp.mkdir(r);
      } catch (_) {
        // 이미 있는 폴더면 그 안에 이어서 올린다.
      }
      await for (final child in Directory(l).list(followLinks: false)) {
        await walk(child.path, p.posix.join(r, p.basename(child.path)));
      }
      return;
    }
    final file = File(l);
    final length = await file.length();
    onTotal(length);
    final base = done;
    final remoteFile = await sftp.open(
      r,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
    var cancelled = false;
    try {
      final stream = file.openRead().map((c) => c is Uint8List ? c : Uint8List.fromList(c));
      final writer = remoteFile.write(stream, onProgress: (n) => onProgress(base + n));
      cancel._abort = writer.abort;
      if (cancel.requested) unawaited(writer.abort());
      await writer.done;
      cancelled = cancel.requested;
      done = base + length;
    } finally {
      cancel._abort = null;
      try {
        await remoteFile.close();
      } catch (_) {}
    }
    if (cancelled) {
      // 반쯤 올라간 파일은 남기지 않는다.
      try {
        await sftp.remove(r);
      } catch (_) {}
      throw const UploadCancelled();
    }
  }

  await walk(local, remote);
}

/// 서버의 [remote](파일 또는 폴더)를 로컬 [local]로 내려받는다. 폴더는 안을 따라 내려가며 받는다.
/// 콜백과 취소는 [uploadPath]와 같다. 취소하면 받던 로컬 파일은 지운다.
Future<void> downloadPath(
  SftpClient sftp,
  String remote,
  String local, {
  required UploadCancel cancel,
  required void Function(int addTotal) onTotal,
  required void Function(int done) onProgress,
}) async {
  var done = 0;
  Future<void> walk(String r, String l, SftpFileAttrs attr) async {
    if (cancel.requested) throw const UploadCancelled();
    if (attr.isDirectory) {
      await Directory(l).create(recursive: true);
      for (final n in await sftp.listdir(r)) {
        if (n.filename == '.' || n.filename == '..') continue;
        await walk(p.posix.join(r, n.filename), p.join(l, n.filename), n.attr);
      }
      return;
    }
    onTotal(attr.size ?? 0);
    final base = done;
    final remoteFile = await sftp.open(r, mode: SftpFileOpenMode.read);
    final out = File(l).openSync(mode: FileMode.write);
    final finished = Completer<void>();
    StreamSubscription<Uint8List>? sub;
    var cancelled = false;
    try {
      var received = 0;
      sub = remoteFile
          .read(chunkSize: 64 * 1024, maxPendingRequests: 128, onProgress: (n) => onProgress(base + n))
          .listen(
            (chunk) {
              out.writeFromSync(chunk);
              received += chunk.length;
            },
            onDone: () => finished.complete(),
            onError: (Object e, StackTrace s) => finished.completeError(e, s),
            cancelOnError: true,
          );
      cancel._abort = () async {
        cancelled = true;
        await sub?.cancel();
        if (!finished.isCompleted) finished.complete();
      };
      if (cancel.requested) unawaited(cancel._abort!());
      await finished.future;
      cancelled = cancelled || cancel.requested;
      done = base + received;
    } finally {
      cancel._abort = null;
      out.closeSync();
      try {
        await remoteFile.close();
      } catch (_) {}
    }
    if (cancelled) {
      // 반쯤 받은 파일은 남기지 않는다.
      try {
        File(l).deleteSync();
      } catch (_) {}
      throw const UploadCancelled();
    }
  }

  await walk(remote, local, await sftp.stat(remote));
}
