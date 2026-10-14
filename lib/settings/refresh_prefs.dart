import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 탐색기 자동 새로 고침 설정. 설정 키는 `auto_refresh_local`(기본 켜짐), `auto_refresh_ssh`(기본 꺼짐).
///
/// 보이는 탭의 목록을 [TerminalSession.autoRefreshInterval]마다 조용히 다시 읽는다. SSH는 네트워크를 타서
/// 오류가 잦으므로 기본은 직접 새로 고칠 때만 읽는다.
class RefreshPrefs extends ChangeNotifier {
  RefreshPrefs._(this._prefs, this._local, this._ssh);

  static const _localKey = 'auto_refresh_local';
  static const _sshKey = 'auto_refresh_ssh';

  final SharedPreferences _prefs;
  bool _local;
  bool _ssh;

  static Future<RefreshPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RefreshPrefs._(prefs, prefs.getBool(_localKey) ?? true, prefs.getBool(_sshKey) ?? false);
  }

  bool get local => _local;
  bool get ssh => _ssh;

  Future<void> setLocal(bool value) async {
    if (value == _local) return;
    _local = value;
    notifyListeners();
    await _prefs.setBool(_localKey, value);
  }

  Future<void> setSsh(bool value) async {
    if (value == _ssh) return;
    _ssh = value;
    notifyListeners();
    await _prefs.setBool(_sshKey, value);
  }

  Future<void> reset() async {
    _local = true;
    _ssh = false;
    notifyListeners();
    await _prefs.remove(_localKey);
    await _prefs.remove(_sshKey);
  }
}
