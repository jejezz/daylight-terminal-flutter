import 'package:daylight_terminal/models/file_item.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

FileItem _file(String name, {bool dir = false}) => FileItem(name: name, isDirectory: dir, isLink: false);

void main() {
  group('server: dragging onto a folder', () {
    test('transferable skips items already in the folder, the folder itself and its own subfolders', () {
      final items = [_file('a.txt'), _file('proj', dir: true)];
      expect(SshSessionProvider.transferable('/home/u', items, '/home/u/dest'), items);
      expect(SshSessionProvider.transferable('/home/u/dest', items, '/home/u/dest'), isEmpty);
      expect(SshSessionProvider.transferable('/home/u', items, '/home/u/proj'), [items.first]); // proj는 자기 자신
      expect(SshSessionProvider.transferable('/home/u', items, '/home/u/proj/sub'), [items.first]); // 자기 안쪽
    });

    test('the copy command is a quoted cp the user runs themselves', () {
      final items = [_file('a b.txt'), _file("it's", dir: true)];
      expect(
        SshSessionProvider.copyCommand('/home/u', items, '/home/u/dest'),
        r"cp -a -- '/home/u/a b.txt' '/home/u/it'\''s' '/home/u/dest/'",
      );
      expect(SshSessionProvider.copyCommand('/', [_file('x')], '/'), "cp -a -- '/x' '/'");
    });
  });
}
