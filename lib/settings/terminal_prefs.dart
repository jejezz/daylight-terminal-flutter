import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm2/ui.dart' show TerminalStyle;

import '../theme/app_theme.dart';

/// 터미널 글꼴과 크기. 설정 키는 `terminal_font_family`, `terminal_font_size`.
///
/// 기본값은 내장된 Agave Nerd Font Mono (파워라인·아이콘 글리프 포함)다. 사용자는 목록에서 고르거나
/// 설치된 글꼴의 이름을 직접 적을 수 있다. 어느 쪽이든 fallback 목록 맨 앞에 내장 글꼴을 두어,
/// 고른 글꼴에 없는 글리프는 내장 글꼴이, 한글은 OS 한글 글꼴이 채운다.
class TerminalPrefs extends ChangeNotifier {
  TerminalPrefs._(this._prefs, this._family, this._size);

  static const bundledFamily = 'AgaveNerdFontMono';
  static const defaultSize = 13.0;
  static const minSize = 9.0;
  static const maxSize = 24.0;

  /// 목록에 보여 주는 글꼴: (표시 이름, 글꼴 이름). 이름이 null이면 규약의 고정폭 글꼴 목록
  /// (conventions/fonts.md §4).
  static const presets = <(String, String?)>[
    ('Agave Nerd Font Mono', bundledFamily),
    ('Cascadia Mono', 'Cascadia Mono'),
    ('Consolas', 'Consolas'),
    ('Menlo', 'Menlo'),
    ('SF Mono', 'SF Mono'),
    ('DejaVu Sans Mono', 'DejaVu Sans Mono'),
  ];

  static const _familyKey = 'terminal_font_family';
  static const _sizeKey = 'terminal_font_size';

  final SharedPreferences _prefs;
  String _family;
  double _size;

  static Future<TerminalPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString(_familyKey);
    final size = prefs.getDouble(_sizeKey);
    return TerminalPrefs._(
      prefs,
      family == null || family.trim().isEmpty ? bundledFamily : family.trim(),
      (size ?? defaultSize).clamp(minSize, maxSize),
    );
  }

  String get family => _family;
  double get size => _size;

  /// 목록에 있는 글꼴이면 true, 직접 적은 이름이면 false.
  bool get isPreset => presets.any((p) => p.$2 == _family);

  Future<void> setFamily(String value) async {
    final v = value.trim();
    if (v.isEmpty || v == _family) return;
    _family = v;
    notifyListeners();
    await _prefs.setString(_familyKey, v);
  }

  Future<void> setSize(double value) async {
    final v = value.clamp(minSize, maxSize);
    if (v == _size) return;
    _size = v;
    notifyListeners();
    await _prefs.setDouble(_sizeKey, v);
  }

  Future<void> reset() async {
    _family = bundledFamily;
    _size = defaultSize;
    notifyListeners();
    await _prefs.remove(_familyKey);
    await _prefs.remove(_sizeKey);
  }

  /// xterm에 넘길 글자 스타일.
  TerminalStyle get style => TerminalStyle(
    fontSize: _size,
    fontFamily: _family,
    fontFamilyFallback: [
      if (_family != bundledFamily) bundledFamily,
      AppFonts.mono.fontFamily!,
      ...AppFonts.mono.fontFamilyFallback!,
      ...AppFonts.fallback,
    ],
  );
}
