import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'sender_file.dart';

/// 원격 파일의 종류와 크기·시각·권한. 편집기는 이 값으로 "그사이 서버에서 바뀌었는가"를 판단한다.
enum RemoteFileType { regular, directory, other }

class RemoteStat {
  const RemoteStat({required this.type, required this.size, this.mtime, this.mode, this.uid, this.gid});

  final RemoteFileType type;
  final int size;

  /// 수정 시각(초). SFTP v3는 초 단위만 알려 준다.
  final int? mtime;

  /// 권한 비트(0o7777). 모르면 null.
  final int? mode;
  final int? uid;
  final int? gid;

  /// 편집기가 열 때의 상태와 같은가 (크기와 수정 시각이 같다).
  bool sameAs(RemoteStat other) => size == other.size && mtime == other.mtime;
}

/// 원격 편집에 필요한 서버 파일 동작만 모은 얇은 계층. 실제로는 SFTP이고, 테스트는 메모리 가짜를 쓴다.
abstract interface class RemoteFs {
  /// 심볼릭 링크를 따라간 실제 경로.
  Future<String> resolve(String path);

  /// 링크를 따라간 상태. 없으면 [RemoteNotFound].
  Future<RemoteStat> stat(String path);
  Future<Uint8List> read(String path);

  /// [path]를 만들거나 비우고 [data]를 쓴다.
  Future<void> write(String path, Uint8List data);
  Future<void> rename(String from, String to);
  Future<void> remove(String path);

  /// 가능한 것만 바꾼다. 권한이 없으면 던질 수 있다.
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid});
}

class RemoteNotFound implements Exception {
  const RemoteNotFound(this.path);

  final String path;

  @override
  String toString() => 'RemoteNotFound($path)';
}

/// [SftpClient] 위의 [RemoteFs].
class SftpRemoteFs implements RemoteFs {
  SftpRemoteFs(this._sftp);

  final SftpClient _sftp;

  @override
  Future<String> resolve(String path) => _sftp.absolute(path);

  @override
  Future<RemoteStat> stat(String path) async {
    final SftpFileAttrs a;
    try {
      a = await _sftp.stat(path);
    } on SftpStatusError catch (e) {
      if (e.code == SftpStatusCode.noSuchFile) throw RemoteNotFound(path);
      rethrow;
    }
    return RemoteStat(
      type: a.isFile
          ? RemoteFileType.regular
          : a.isDirectory
          ? RemoteFileType.directory
          : RemoteFileType.other,
      size: a.size ?? 0,
      mtime: a.modifyTime,
      mode: a.mode == null ? null : a.mode!.value & 0xFFF,
      uid: a.userID,
      gid: a.groupID,
    );
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = await _sftp.open(path);
    try {
      return await file.readBytes();
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> write(String path, Uint8List data) async {
    final file = await _sftp.open(
      path,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(data);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> rename(String from, String to) => _sftp.rename(from, to);

  @override
  Future<void> remove(String path) => _sftp.remove(path);

  @override
  Future<void> setAttrs(String path, {int? mode, int? uid, int? gid}) async {
    // SFTP 속성은 uid/gid를 짝으로만 보낼 수 있다.
    await _sftp.setStat(
      path,
      SftpFileAttrs(
        mode: mode == null ? null : SftpFileMode.value(mode),
        userID: uid != null && gid != null ? uid : null,
        groupID: uid != null && gid != null ? gid : null,
      ),
    );
  }
}

enum RemoteEditError { notRegular, notFound, tooLarge, notUtf8, binary, io }

class RemoteEditException implements Exception {
  const RemoteEditException(this.kind, [this.detail = '']);

  final RemoteEditError kind;
  final String detail;

  @override
  String toString() => 'RemoteEditException($kind, $detail)';
}

/// 서버에서 읽어 온 편집 대상 하나. [path]는 링크를 따라간 실제 경로이고, [stat]은 읽었을 때의 상태다.
class RemoteTextFile {
  const RemoteTextFile(this.path, this.document, this.stat);

  final String path;
  final SenderDocument document;
  final RemoteStat stat;
}

enum RemoteSaveStatus { saved, conflict }

class RemoteSaveResult {
  const RemoteSaveResult.saved(RemoteStat this.stat) : status = RemoteSaveStatus.saved;
  const RemoteSaveResult.conflict() : status = RemoteSaveStatus.conflict, stat = null;

  final RemoteSaveStatus status;

  /// 저장한 뒤의 서버 상태 (충돌이면 null).
  final RemoteStat? stat;
}

/// 원격 텍스트 파일 편집: 열기와 안전한 저장.
abstract final class RemoteText {
  /// 서버 파일을 연다. 일반 파일이 아니거나(폴더·장치·소켓), 크기 한도를 넘거나, UTF-8 텍스트가 아니면
  /// 내용을 받기 전에(가능하면) 거부한다.
  static Future<RemoteTextFile> open(RemoteFs fs, String path) async {
    try {
      final real = await fs.resolve(path);
      final RemoteStat stat;
      try {
        stat = await fs.stat(real);
      } on RemoteNotFound {
        throw RemoteEditException(RemoteEditError.notFound, real);
      }
      if (stat.type != RemoteFileType.regular) throw RemoteEditException(RemoteEditError.notRegular, real);
      if (stat.size > SenderFile.maxBytes) throw const RemoteEditException(RemoteEditError.tooLarge);
      final bytes = await fs.read(real);
      final SenderDocument doc;
      try {
        doc = SenderFile.decode(bytes, rejectBinary: true);
      } on SenderFileException catch (e) {
        throw RemoteEditException(switch (e.kind) {
          SenderFileError.tooLarge => RemoteEditError.tooLarge,
          SenderFileError.notUtf8 => RemoteEditError.notUtf8,
          SenderFileError.binary => RemoteEditError.binary,
          SenderFileError.io => RemoteEditError.io,
        });
      }
      return RemoteTextFile(real, doc, stat);
    } on RemoteEditException {
      rethrow;
    } catch (e) {
      throw RemoteEditException(RemoteEditError.io, '$e');
    }
  }

  /// [doc]을 [file]이 있던 자리에 저장한다.
  ///
  /// 저장 직전에 서버 파일의 크기·수정 시각을 다시 확인해서 열 때와 다르면(다른 사람이나 프로세스가 고쳤거나 지워졌으면)
  /// 아무것도 쓰지 않고 [RemoteSaveStatus.conflict]를 돌려준다. [overwrite]이면 확인을 건너뛴다.
  ///
  /// 임시 이름에 쓴 뒤 `rename`으로 바꿔 끼워서 도중에 끊겨도 원본이 반쯤 쓰인 채 남지 않고, 원본의 권한(과 가능하면
  /// 소유자)을 그대로 이어받는다. 폴더에 쓸 수 없으면 파일에 바로 쓴다. [backup]이면 `이름.bak`에 이전 내용을 남긴다.
  static Future<RemoteSaveResult> save(
    RemoteFs fs,
    RemoteTextFile file,
    SenderDocument doc, {
    bool overwrite = false,
    bool backup = false,
  }) async {
    final path = file.path;
    try {
      final RemoteStat current;
      try {
        current = await fs.stat(path);
      } on RemoteNotFound {
        if (!overwrite) return const RemoteSaveResult.conflict();
        return RemoteSaveResult.saved(await _writeFresh(fs, path, SenderFile.encode(doc), null));
      }
      if (!overwrite && !current.sameAs(file.stat)) return const RemoteSaveResult.conflict();
      if (backup) await fs.write('$path.bak', await fs.read(path));
      return RemoteSaveResult.saved(await _writeFresh(fs, path, SenderFile.encode(doc), current));
    } on RemoteEditException {
      rethrow;
    } catch (e) {
      throw RemoteEditException(RemoteEditError.io, '$e');
    }
  }

  static Future<RemoteStat> _writeFresh(RemoteFs fs, String path, Uint8List data, RemoteStat? old) async {
    final tmp = '$path.dlt-${DateTime.now().microsecondsSinceEpoch}.tmp';
    var wroteTmp = false;
    try {
      await fs.write(tmp, data);
      wroteTmp = true;
    } catch (_) {
      // 폴더에 쓸 수 없다: 파일에 바로 쓴다 (권한·소유자는 그대로다).
      try {
        await fs.remove(tmp);
      } catch (_) {}
    }
    if (!wroteTmp) {
      await fs.write(path, data);
    } else {
      try {
        if (old?.mode != null) await fs.setAttrs(tmp, mode: old!.mode);
        if (old?.uid != null && old?.gid != null) {
          try {
            await fs.setAttrs(tmp, uid: old!.uid, gid: old.gid);
          } catch (_) {} // 소유자를 바꿀 권한이 없으면 그냥 둔다.
        }
        await fs.rename(tmp, path);
      } catch (_) {
        try {
          await fs.remove(tmp);
        } catch (_) {}
        rethrow;
      }
    }
    return fs.stat(path);
  }
}
