import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/local_shell.dart';
import '../services/local_shell_finder.dart';
import '../services/profile_store.dart';
import '../services/tab_store.dart';
import '../services/pty_backend.dart';
import '../settings/refresh_prefs.dart';
import '../settings/restore_prefs.dart';
import '../services/serial_service.dart';
import 'local_shell_session.dart';
import 'serial_session.dart';
import 'ssh_session_provider.dart';
import 'terminal_session.dart';

/// 열려 있는 탭(세션) 목록과 선택된 탭. 탭은 SSH(터미널 + SFTP) 또는 로컬 셸(터미널 + 이 PC의 폴더)이다.
class SessionsController extends ChangeNotifier {
  /// [scrollback]은 새 탭을 만들 때마다 불러 스크롤백 줄 수를 얻는다 (설정이 바뀌어도 새 탭부터 적용).
  /// [shellFinder]와 [ptyFactory]는 테스트에서 가짜로 바꿔 끼운다.
  ///
  /// [tabStore]와 [restorePrefs]를 주면 열어 둔 탭을 기억하고 [restoreTabs]로 다시 연다. 없으면 기억하지 않는다.
  SessionsController(
    this.store, {
    this.scrollback,
    this.refreshPrefs,
    this.shellFinder,
    this.ptyFactory,
    this.serialFactory,
    this.tabStore,
    this.restorePrefs,
  }) {
    refreshPrefs?.addListener(_syncActive);
    restorePrefs?.addListener(_onRestorePrefs);
    add(showAllOptions: true);
  }

  final ProfileStore store;
  final int Function()? scrollback;

  /// 탐색기 자동 새로 고침 설정. 없으면 로컬만 켠다.
  final RefreshPrefs? refreshPrefs;
  final LocalShellFinder? shellFinder;
  final PtyFactory? ptyFactory;

  /// 테스트에서 가짜 시리얼 서비스를 끼운다.
  final SerialService Function()? serialFactory;

  /// 열어 둔 탭을 저장하는 곳과 그 설정. 둘 다 있어야 기억한다.
  final TabStore? tabStore;
  final RestorePrefs? restorePrefs;
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

  /// SSH 탭을 연다 (접속 폼이 보인다). [showAllOptions]이면 시리얼·로컬 셸 선택도 함께 보인다 (처음 여는 탭).
  void add({bool showAllOptions = false}) =>
      _addSession(SshSessionProvider(store, scrollback: scrollback?.call() ?? 10000, showAllOptions: showAllOptions));

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
    _replaceSelected(old, session);
    unawaited(session.start());
    return session;
  }

  SerialSession _newSerial() => SerialSession(scrollback: scrollback?.call() ?? 10000, service: serialFactory?.call());

  /// 시리얼 탭을 연다 (포트를 고르는 폼이 보인다).
  SerialSession addSerial() {
    final session = _newSerial();
    _addSession(session);
    unawaited(session.loadFolder(session.folderPath));
    return session;
  }

  /// 지금 탭이 아직 연결하지 않은 빈 SSH 탭이면 그 자리에서 시리얼 탭으로 바꾼다 ([openLocalHere]와 같다).
  SerialSession openSerialHere() {
    final old = current;
    final reusable = old is SshSessionProvider && !old.connected && old.status != SessionStatus.connecting;
    if (!reusable) return addSerial();
    final session = _newSerial();
    _replaceSelected(old, session);
    unawaited(session.loadFolder(session.folderPath));
    return session;
  }

  /// 선택된 탭 자리를 [session]으로 바꾸고 옛 탭 [old]를 정리한다.
  void _replaceSelected(TerminalSession old, TerminalSession session) {
    old.removeListener(_scheduleSave);
    session.addListener(_scheduleSave);
    sessions[_selected] = session;
    _syncActive();
    notifyListeners();
    // 위젯 트리가 옛 탭을 내려놓은 다음에 정리한다.
    Future<void>.microtask(old.dispose);
  }

  void _addSession(TerminalSession session) {
    session.addListener(_scheduleSave);
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

  /// [from] 자리의 탭을 [to] 자리로 옮긴다 ([to]는 옮긴 뒤의 위치). 선택된 탭은 그대로 유지된다.
  void move(int from, int to) {
    if (from < 0 || from >= sessions.length || to < 0 || to >= sessions.length || from == to) return;
    final keep = sessions[_selected];
    sessions.insert(to, sessions.removeAt(from));
    _selected = sessions.indexOf(keep);
    notifyListeners();
  }

  void closeAt(int index) {
    if (index < 0 || index >= sessions.length) return;
    final removed = sessions.removeAt(index);
    removed.removeListener(_scheduleSave);
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
    await _save(); // 마지막 폴더까지 저장한다
    for (final s in sessions) {
      await s.prepareForExit();
    }
  }

  // ───────────────────────── 열어 둔 탭 기억·복원 ─────────────────────────

  Timer? _saveTimer;

  /// 복원이 끝나기 전에는 저장하지 않는다 (처음 만든 빈 탭이 지난번 기록을 덮어쓰지 않게).
  bool _persistReady = false;

  bool get _persisting => tabStore != null && restorePrefs != null && restorePrefs!.enabled;

  /// 지금 열려 있는 탭을 저장할 모양으로. 접속하지 않은 빈 SSH 탭은 뺀다.
  SavedTabs _snapshot() {
    final tabs = <SavedTab>[];
    var selected = 0;
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final tab = switch (s) {
        final SshSessionProvider ssh when ssh.profile != null => SavedSshTab(ssh.profile!),
        final LocalShellSession local => SavedLocalTab(local.shell.id, local.folderPath),
        final SerialSession serial when (serial.activeSettings ?? serial.pendingSettings) != null => SavedSerialTab(
          (serial.activeSettings ?? serial.pendingSettings)!,
          serial.folderPath,
        ),
        _ => null,
      };
      if (tab == null) continue;
      if (i <= _selected) selected = tabs.length; // 선택된 탭(건너뛰었으면 그 앞의 가장 가까운 탭)
      tabs.add(tab);
    }
    return SavedTabs(tabs, selected.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1));
  }

  void _scheduleSave() {
    if (!_persistReady || !_persisting) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    if (!_persistReady || !_persisting) return;
    try {
      await tabStore!.write(_snapshot());
    } catch (e) {
      debugPrint('saving tabs failed: $e');
    }
  }

  void _onRestorePrefs() {
    if (tabStore == null || restorePrefs == null) return;
    if (restorePrefs!.enabled) {
      unawaited(_save());
    } else {
      _saveTimer?.cancel();
      unawaited(tabStore!.clear()); // 꺼 두는 동안 쌓인 옛 기록이 나중에 되살아나지 않게
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  /// 지난번에 열어 둔 탭을 다시 연다. 앱을 켤 때 [loadShells] 뒤에 한 번 부른다.
  ///
  /// SSH는 접속 정보만 채운 접속 화면으로 연다 (비밀번호를 저장하지 않으니 자동 접속은 못 한다). 시리얼도 설정만 채우고
  /// 장치를 열지는 않는다. 지금은 없는 셸이나 폴더는 건너뛰거나 홈 폴더로 연다. 이미 사용자가 탭을 건드렸으면 하지 않는다.
  Future<void> restoreTabs() async {
    try {
      if (!_persisting) return;
      final saved = tabStore!.read();
      final untouched = sessions.every((s) => s is SshSessionProvider && s.profile == null && !s.connected);
      if (saved == null || saved.tabs.isEmpty || !untouched) return;

      final restored = <TerminalSession>[];
      var selected = -1;
      for (var i = 0; i < saved.tabs.length; i++) {
        final session = _restoreOne(saved.tabs[i]);
        if (session == null) continue;
        if (i == saved.selected) selected = restored.length;
        restored.add(session);
      }
      if (restored.isEmpty) return;

      final old = [...sessions];
      for (final s in old) {
        s.removeListener(_scheduleSave);
      }
      sessions
        ..clear()
        ..addAll(restored);
      for (final s in restored) {
        s.addListener(_scheduleSave);
      }
      _selected = selected >= 0 ? selected : restored.length - 1;
      _syncActive();
      notifyListeners();
      for (final s in restored) {
        if (s is LocalShellSession) unawaited(s.start());
        if (s is SerialSession) unawaited(s.loadFolder(s.folderPath));
      }
      Future<void>.microtask(() {
        for (final s in old) {
          s.dispose();
        }
      });
    } catch (e) {
      debugPrint('restoring tabs failed: $e');
    } finally {
      _persistReady = true;
      unawaited(_save());
    }
  }

  TerminalSession? _restoreOne(SavedTab tab) {
    final lines = scrollback?.call() ?? 10000;
    String? existing(String folder) => Directory(folder).existsSync() ? folder : null;
    switch (tab) {
      case SavedSshTab(:final profile):
        return SshSessionProvider(store, scrollback: lines)..prefill(profile);
      case SavedLocalTab(:final shellId, :final folder):
        final shell = _shells.where((s) => s.id == shellId).firstOrNull;
        if (shell == null) return null;
        return LocalShellSession(shell, scrollback: lines, ptyFactory: ptyFactory, startDirectory: existing(folder));
      case SavedSerialTab(:final settings, :final folder):
        return SerialSession(scrollback: lines, service: serialFactory?.call(), startDirectory: existing(folder))
          ..prefill(settings);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    restorePrefs?.removeListener(_onRestorePrefs);
    for (final s in sessions) {
      s.removeListener(_scheduleSave);
    }
    refreshPrefs?.removeListener(_syncActive);
    for (final s in sessions) {
      s.dispose();
    }
    super.dispose();
  }
}
