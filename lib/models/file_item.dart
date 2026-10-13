/// 폴더 안의 항목 하나 (SFTP 원격 폴더와 로컬 폴더가 함께 쓴다).
class FileItem {
  const FileItem({required this.name, required this.isDirectory, required this.isLink, this.size, this.modified});

  final String name;
  final bool isDirectory;
  final bool isLink;
  final int? size;
  final DateTime? modified;
}
