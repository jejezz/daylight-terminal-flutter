import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 시작할 때 마지막에 열어 둔 탭을 다시 여는지. 설정 키는 `restore_tabs`(기본 켜짐).
class RestorePrefs extends ChangeNotifier {
  RestorePrefs._(this._prefs, this._enabled);

  static const _key = 'restore_tabs';

  final SharedPreferences _prefs;
  bool _enabled;

  static Future<RestorePrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RestorePrefs._(prefs, prefs.getBool(_key) ?? true);
  }

  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await _prefs.setBool(_key, value);
  }

  Future<void> reset() async {
    _enabled = true;
    notifyListeners();
    await _prefs.remove(_key);
  }
}
