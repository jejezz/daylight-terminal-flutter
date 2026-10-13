import 'package:flutter/foundation.dart';

import '../services/profile_store.dart';
import 'ssh_session_provider.dart';

/// 열려 있는 탭(세션) 목록과 선택된 탭.
class SessionsController extends ChangeNotifier {
  SessionsController(this.store) {
    add();
  }

  final ProfileStore store;
  final List<SshSessionProvider> sessions = [];
  int _selected = 0;

  int get selected => _selected;
  SshSessionProvider? get current => sessions.isEmpty ? null : sessions[_selected];

  void add() {
    sessions.add(SshSessionProvider(store));
    _selected = sessions.length - 1;
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= sessions.length || index == _selected) return;
    _selected = index;
    notifyListeners();
  }

  void closeAt(int index) {
    if (index < 0 || index >= sessions.length) return;
    final removed = sessions.removeAt(index);
    if (_selected > index || _selected >= sessions.length) {
      _selected = (_selected - 1).clamp(0, sessions.isEmpty ? 0 : sessions.length - 1);
    }
    notifyListeners();
    // 위젯 트리가 이 세션을 내려놓은 다음에 정리한다.
    Future<void>.microtask(removed.dispose);
  }

  void closeCurrent() => closeAt(_selected);

  Future<void> prepareForExit() async {
    for (final s in sessions) {
      await s.prepareForExit();
    }
  }

  @override
  void dispose() {
    for (final s in sessions) {
      s.dispose();
    }
    super.dispose();
  }
}
