/// SFTP 디렉터리의 항목 하나.
class RemoteEntry {
  const RemoteEntry({required this.name, required this.isDirectory, required this.isLink, this.size, this.modified});

  final String name;
  final bool isDirectory;
  final bool isLink;
  final int? size;
  final DateTime? modified;
}
