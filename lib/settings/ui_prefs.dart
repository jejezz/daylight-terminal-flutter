import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 글자 크기(터미널 밖의 메뉴·탭·폴더 이름·상태 줄 등 모든 글자)의 배율. 설정 키는 `ui_text_scale`.
/// 터미널 글자는 따로 `terminal_font_size`로 정한다 (이 배율을 받지 않는다).
class UiPrefs extends ChangeNotifier {
  UiPrefs._(this._prefs, this._scale);

  static const defaultScale = 1.0;
  static const minScale = 0.8;
  static const maxScale = 1.5;

  /// 슬라이더 한 칸 (5%).
  static const step = 0.05;

  static const _key = 'ui_text_scale';

  final SharedPreferences _prefs;
  double _scale;

  static Future<UiPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UiPrefs._(prefs, _clean(prefs.getDouble(_key) ?? defaultScale));
  }

  /// 범위 안으로 넣고 5% 단위로 맞춘다 (부동소수점 찌꺼기 없이 같은 값끼리 같게).
  static double _clean(double v) => ((v.clamp(minScale, maxScale) / step).round() * step * 100).round() / 100;

  double get scale => _scale;

  Future<void> setScale(double value) async {
    final v = _clean(value);
    if (v == _scale) return;
    _scale = v;
    notifyListeners();
    await _prefs.setDouble(_key, v);
  }

  Future<void> reset() async {
    _scale = defaultScale;
    notifyListeners();
    await _prefs.remove(_key);
  }
}
