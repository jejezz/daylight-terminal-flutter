/// 주소록에 저장되는 접속 정보. 비밀번호와 키 암호는 저장하지 않는다 — 접속할 때마다 입력한다.
class SshProfile {
  const SshProfile({
    required this.id,
    required this.host,
    required this.port,
    required this.username,
    this.keyPath,
    this.name = '',
    this.group = '',
    this.note = '',
  });

  final String id;
  final String host;
  final int port;
  final String username;

  /// 개인 키 파일 경로. 없으면 비밀번호로 인증한다.
  final String? keyPath;

  /// 주소록에 보이는 이름. 비어 있으면 [address]를 보여 준다.
  final String name;

  /// 주소록에서 묶는 그룹 이름. 비어 있으면 그룹 없음.
  final String group;

  final String note;

  /// `user@host` (기본 포트가 아니면 `:port`까지).
  String get address => '$username@$host${port == 22 ? '' : ':$port'}';

  /// 탭과 상태 바에 보이는 이름.
  String get label => name.isEmpty ? address : name;

  SshProfile copyWith({
    String? host,
    int? port,
    String? username,
    String? keyPath,
    bool clearKey = false,
    String? name,
    String? group,
    String? note,
  }) => SshProfile(
    id: id,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    keyPath: clearKey ? null : (keyPath ?? this.keyPath),
    name: name ?? this.name,
    group: group ?? this.group,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'username': username,
    if (keyPath != null) 'keyPath': keyPath,
    if (name.isNotEmpty) 'name': name,
    if (group.isNotEmpty) 'group': group,
    if (note.isNotEmpty) 'note': note,
  };

  static SshProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], host = json['host'], port = json['port'], user = json['username'];
    if (id is! String || host is! String || port is! int || user is! String) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    final key = json['keyPath'];
    return SshProfile(
      id: id,
      host: host,
      port: port,
      username: user,
      keyPath: key is String ? key : null,
      name: text('name'),
      group: text('group'),
      note: text('note'),
    );
  }
}
