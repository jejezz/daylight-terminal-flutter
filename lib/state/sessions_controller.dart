import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/local_shell.dart';
import '../services/local_shell_finder.dart';
import '../services/profile_store.dart';
import '../services/pty_backend.dart';
import '../settings/refresh_prefs.dart';
import 'local_shell_session.dart';
import 'ssh_session_provider.dart';
import 'terminal_session.dart';

/// 열려 있는 탭(세션) 목록과 선택된 탭. 탭은 SSH(터미널 + SFTP) 또는 로컬 셸(터미널 + 이 PC의 폴더)이다.
class SessionsController extends ChangeNotifier {
  /// [scrollback]은 새 탭을 만들 때마다 불러 스크롤백 줄 수를 얻는다 (설정이 바뀌어도 새 탭부터 적용).
  /// [shellFinder]와 [ptyFactory]는 테스트에서 가짜로 바꿔 끼운다.
  SessionsController(this.store, {this.scrollback, this.refreshPrefs, this.shellFinder, this.ptyFactory}) {
    refreshPrefs?.addListener(_syncActive);
    add();
  }

  final ProfileStore store;
  final int Function()? scrollback;

  /// 탐색기 자동 새로 고침 설정. 없으면 로컬만 켠다.
  final RefreshPrefs? refreshPrefs;
  final LocalShellFinder? shellFinder;
  final PtyFactory? ptyFactory;
  final List<TerminalSession> sessions = [];
  int _selected = 0;
  List<LocalShell> _shells = const [];

  int get selected => _selected;
  TerminalSession? get current => sessions.isEmpty ? null : sessions[_selected];

  /// 이 컴퓨터에서 탭으로 열 수 있는 로컬 셸. [loadShells]가 끝나기 전에는 비어 있다. 첫 번째가 기본 셸.
  List<LocalShell> get shells => _shells;

  /// 설치된 셸을 찾는다 (Windows에서는 WSL 배포판을 묻느라 잠깐 걸린다). 앱을 켤 때 한 번 부른다.
  Future<void> loadShells() async {
    try {
      _shells = await (shellFinder ?? LocalShellFinder()).find();
    } catch (e) {
      debugPrint('shell discovery failed: $e');
      _shells = const [];
    }
    notifyListeners();
  }

  /// SSH 탭을 연다 (접속 폼이 보인다).
  void add() => _addSession(SshSessionProvider(store, scrollback: scrollback?.call() ?? 10000));

  /// 로컬 셸 탭을 열고 셸을 띄운다. [shell]을 안 주면 기본 셸. 쓸 수 있는 셸이 없으면 null.
  LocalShellSession? addLocal([LocalShell? shell]) {
    final chosen = shell ?? (_shells.isEmpty ? null : _shells.first);
    if (chosen == null) return null;
    final session = LocalShellSession(chosen, scrollback: scrollback?.call() ?? 10000, ptyFactory: ptyFactory);
    _addSession(session);
    unawaited(session.start());
    return session;
  }

  /// 지금 탭이 아직 연결하지 않은 빈 SSH 탭이면 그 자리에서 로컬 셸 탭으로 바꾼다 (빈 탭이 남지 않게).
  /// 연결 중이거나 이미 연결되어 있거나 다른 종류의 탭이면 새 탭으로 연다.
  LocalShellSession openLocalHere(LocalShell shell) {
    final old = current;
    final reusable = old is SshSessionProvider && !old.connected && old.status != SessionStatus.connecting;
    if (!reusable) return addLocal(shell)!;
    final session = LocalShellSession(shell, scrollback: scrollback?.call() ?? 10000, ptyFactory: ptyFactory);
    sessions[_selected] = session;
    _syncActive();
    notifyListeners();
    unawaited(session.start());
    // 위젯 트리가 옛 탭을 내려놓은 다음에 정리한다.
    Future<void>.microtask(old.dispose);
    return session;
  }

  void _addSession(TerminalSession session) {
    sessions.add(session);
    _selected = sessions.length - 1;
    _syncActive();
    notifyListeners();
  }

  /// 선택된 탭만, 설정이 허용한 종류의 탭만 탐색기를 자동으로 새로 고치게 한다.
  void _syncActive() {
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      s.setAutoRefreshAllowed(s is SshSessionProvider ? refreshPrefs?.ssh ?? false : refreshPrefs?.local ?? true);
      s.setActive(i == _selected);
    }
  }

  void select(int index) {
    if (index < 0 || index >= sessions.length || index == _selected) return;
    _selected = index;
    _syncActive();
    notifyListeners();
  }

  void closeAt(int index) {
    if (index < 0 || index >= sessions.length) return;
    final removed = sessions.removeAt(index);
    if (_selected > index || _selected >= sessions.length) {
      _selected = (_selected - 1).clamp(0, sessions.isEmpty ? 0 : sessions.length - 1);
    }
    _syncActive();
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
    refreshPrefs?.removeListener(_syncActive);
    for (final s in sessions) {
      s.dispose();
    }
    super.dispose();
  }
}
