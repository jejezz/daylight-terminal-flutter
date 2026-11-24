import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LineSender의 Enter 키 동작. 설정 키는 `sender_enter_sends`(기본 켜짐).
/// 켜짐: Enter = 현재 줄 전송, Shift+Enter = 줄바꿈.
/// 꺼짐: Enter = 줄바꿈, Ctrl+Enter = 현재 줄 전송 (예전 동작).
///
/// LineSender와 편집기의 자리도 여기서 정한다. 설정 키는 `sender_editor_swapped`(기본 꺼짐).
/// 꺼짐: LineSender는 터미널 아래, 편집기는 오른쪽. 켜짐: 편집기가 터미널 아래, LineSender가 오른쪽.
class SenderPrefs extends ChangeNotifier {
  SenderPrefs._(this._prefs, this._enterSends, this._swapped);

  static const _key = 'sender_enter_sends';
  static const _swapKey = 'sender_editor_swapped';

  final SharedPreferences _prefs;
  bool _enterSends;
  bool _swapped;

  static Future<SenderPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SenderPrefs._(prefs, prefs.getBool(_key) ?? true, prefs.getBool(_swapKey) ?? false);
  }

  /// 위젯 트리에 없으면(테스트 등) null. 쓰는 쪽은 null이면 기본값(Enter = 전송)으로 본다.
  static SenderPrefs? maybeOf(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<SenderPrefs>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool get enterSends => _enterSends;

  Future<void> setEnterSends(bool value) async {
    if (value == _enterSends) return;
    _enterSends = value;
    notifyListeners();
    await _prefs.setBool(_key, value);
  }

  /// 켜져 있으면 편집기가 터미널 아래에, LineSender가 오른쪽에 있다.
  bool get swapped => _swapped;

  Future<void> setSwapped(bool value) async {
    if (value == _swapped) return;
    _swapped = value;
    notifyListeners();
    await _prefs.setBool(_swapKey, value);
  }

  Future<void> toggleSwapped() => setSwapped(!_swapped);

  Future<void> reset() async {
    _enterSends = true;
    _swapped = false;
    notifyListeners();
    await _prefs.remove(_key);
    await _prefs.remove(_swapKey);
  }
}
