import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_profile.dart';
import 'profile_store.dart';

/// 저장된 호스트 키와 다른 키가 왔다 — 중간자 공격일 수 있어 접속을 거부한다.
class HostKeyMismatchException implements Exception {
  HostKeyMismatchException(this.host);
  final String host;
  @override
  String toString() => 'Host key mismatch: $host';
}

/// 하나의 SSH 연결 위에 열린 셸 채널과 SFTP 채널.
class SshConnection {
  SshConnection._(this.client, this.shell, this.sftp);

  final SSHClient client;
  final SSHSession shell;
  final SftpClient sftp;

  /// [password]가 있으면 비밀번호(및 keyboard-interactive)로, 프로필에 키 파일이 있으면
  /// 그 키로 인증한다. 처음 보는 호스트의 키는 신뢰하고 저장하며(TOFU), 이후 달라지면 거부한다.
  static Future<SshConnection> open({
    required SshProfile profile,
    required ProfileStore store,
    required int cols,
    required int rows,
    String? password,
    String? keyPassphrase,
  }) async {
    final socket = await SSHSocket.connect(profile.host, profile.port, timeout: const Duration(seconds: 15));
    var mismatch = false;
    SSHClient? client;
    try {
      List<SSHKeyPair>? identities;
      final keyPath = profile.keyPath;
      if (keyPath != null) {
        identities = SSHKeyPair.fromPem(await File(keyPath).readAsString(), keyPassphrase);
      }
      final c = client = SSHClient(
        socket,
        username: profile.username,
        identities: identities,
        onPasswordRequest: password == null ? null : () => password,
        onUserInfoRequest: password == null ? null : (request) => [for (final _ in request.prompts) password],
        onVerifyHostKey: (type, fingerprint) async {
          final hex = fingerprint.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
          final seen = '$type $hex';
          final known = store.knownHostKey(profile.host, profile.port);
          if (known == null) {
            await store.trustHostKey(profile.host, profile.port, seen);
            return true;
          }
          if (known == seen) return true;
          mismatch = true;
          return false;
        },
      );
      // 닫은 뒤 소켓에서 나오는 오류(상대가 먼저 끊는 경우 등)가 처리되지 않은 비동기 오류로 새지 않게 한다.
      unawaited(c.done.catchError((Object _) {}));
      final shell = await c.shell(
        pty: SSHPtyConfig(width: cols, height: rows),
      );
      final sftp = await c.sftp();
      return SshConnection._(c, shell, sftp);
    } catch (e) {
      // 클라이언트가 만들어졌다면 close()가 소켓도 닫는다.
      if (client != null) {
        client.close();
      } else {
        socket.destroy();
      }
      if (mismatch) throw HostKeyMismatchException(profile.host);
      rethrow;
    }
  }

  Future<void> close() async {
    client.close();
    try {
      await client.done;
    } catch (_) {}
  }
}
