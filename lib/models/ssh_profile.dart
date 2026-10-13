/// 저장되는 접속 정보. 비밀번호와 키 암호는 저장하지 않는다 — 접속할 때마다 입력한다.
class SshProfile {
  const SshProfile({required this.id, required this.host, required this.port, required this.username, this.keyPath});

  final String id;
  final String host;
  final int port;
  final String username;

  /// 개인 키 파일 경로. 없으면 비밀번호로 인증한다.
  final String? keyPath;

  String get label => '$username@$host${port == 22 ? '' : ':$port'}';

  SshProfile copyWith({String? host, int? port, String? username, String? keyPath, bool clearKey = false}) =>
      SshProfile(
        id: id,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        keyPath: clearKey ? null : (keyPath ?? this.keyPath),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'username': username,
    if (keyPath != null) 'keyPath': keyPath,
  };

  static SshProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], host = json['host'], port = json['port'], user = json['username'];
    if (id is! String || host is! String || port is! int || user is! String) return null;
    final key = json['keyPath'];
    return SshProfile(id: id, host: host, port: port, username: user, keyPath: key is String ? key : null);
  }
}
