import 'package:flutter/services.dart';

import '../models/file_item.dart';

/// 폴더 뷰의 다중 선택. 그냥 누르면 하나, Ctrl/⌘는 더하기·빼기, Shift는 마지막으로 누른 곳부터 범위.
/// 항목은 이름으로 기억한다 (목록을 새로 불러와도 선택이 유지되게).
class ListSelection {
  final Set<String> _names = {};
  int? _anchor;

  int get length => _names.length;
  bool contains(String name) => _names.contains(name);
  bool get isEmpty => _names.isEmpty;

  void clear() => _names.clear();

  void setOnly(String name) {
    _names
      ..clear()
      ..add(name);
  }

  /// [index]번 항목을 눌렀을 때. [keyboard]는 눌린 보조 키를 알려 준다.
  void click(int index, List<FileItem> items, HardwareKeyboard keyboard) {
    final name = items[index].name;
    if (keyboard.isShiftPressed && _anchor != null) {
      final a = _anchor!.clamp(0, items.length - 1);
      final from = a < index ? a : index;
      final to = a < index ? index : a;
      _names
        ..clear()
        ..addAll([for (var i = from; i <= to; i++) items[i].name]);
    } else if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (!_names.remove(name)) _names.add(name);
      _anchor = index;
    } else {
      setOnly(name);
      _anchor = index;
    }
  }

  /// 우클릭하거나 끌기를 시작한 항목 [item]이 선택에 없으면 그것만 선택한다. 있으면 선택은 그대로다.
  /// 어느 쪽이든 동작 대상인 선택된 항목들을 돌려준다.
  List<FileItem> targetsFor(FileItem item, List<FileItem> items) {
    if (!_names.contains(item.name)) {
      setOnly(item.name);
      _anchor = items.indexWhere((x) => x.name == item.name);
    }
    return picked(items);
  }

  List<FileItem> picked(List<FileItem> items) => [
    for (final e in items)
      if (_names.contains(e.name)) e,
  ];
}
