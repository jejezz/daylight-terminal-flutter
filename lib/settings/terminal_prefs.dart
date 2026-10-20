import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm2/ui.dart' show TerminalStyle;

import '../theme/app_theme.dart';
import 'terminal_schemes.dart';

/// 터미널 글꼴·크기·스크롤백 줄 수·색상 구성표. 설정 키는 `terminal_font_family`, `terminal_font_size`,
/// `terminal_scrollback`, `terminal_color_scheme`.
///
/// 기본값은 내장된 Agave Nerd Font Mono (파워라인·아이콘 글리프 포함)다. 사용자는 목록에서 고르거나
/// 설치된 글꼴의 이름을 직접 적을 수 있다. 어느 쪽이든 fallback 목록 맨 앞에 내장 글꼴을 두어,
/// 고른 글꼴에 없는 글리프는 내장 글꼴이, 한글은 OS 한글 글꼴이 채운다.
class TerminalPrefs extends ChangeNotifier {
  TerminalPrefs._(this._prefs, this._family, this._size, this._scrollback, this._scheme);

  static const bundledFamily = 'AgaveNerdFontMono';
  static const defaultSize = 13.0;
  static const minSize = 9.0;
  static const maxSize = 24.0;

  /// 스크롤백(지난 출력으로 되돌아볼 수 있는) 줄 수. xterm2는 터미널을 만들 때만 정할 수 있어서
  /// 새로 여는 탭부터 적용된다.
  static const defaultScrollback = 10000;
  static const minScrollback = 500;
  static const maxScrollback = 100000;
  static const scrollbackPresets = [1000, 5000, 10000, 50000, 100000];

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
  static const _scrollbackKey = 'terminal_scrollback';
  static const _schemeKey = 'terminal_color_scheme';

  final SharedPreferences _prefs;
  String _family;
  double _size;
  int _scrollback;
  TerminalScheme _scheme;

  static Future<TerminalPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final family = prefs.getString(_familyKey);
    final size = prefs.getDouble(_sizeKey);
    return TerminalPrefs._(
      prefs,
      family == null || family.trim().isEmpty ? bundledFamily : family.trim(),
      (size ?? defaultSize).clamp(minSize, maxSize),
      (prefs.getInt(_scrollbackKey) ?? defaultScrollback).clamp(minScrollback, maxScrollback),
      TerminalScheme.byId(prefs.getString(_schemeKey)),
    );
  }

  String get family => _family;
  double get size => _size;
  int get scrollback => _scrollback;
  TerminalScheme get scheme => _scheme;

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

  Future<void> setScrollback(int value) async {
    final v = value.clamp(minScrollback, maxScrollback);
    if (v == _scrollback) return;
    _scrollback = v;
    notifyListeners();
    await _prefs.setInt(_scrollbackKey, v);
  }

  Future<void> setScheme(TerminalScheme value) async {
    if (value.id == _scheme.id) return;
    _scheme = value;
    notifyListeners();
    await _prefs.setString(_schemeKey, value.id);
  }

  Future<void> reset() async {
    _family = bundledFamily;
    _size = defaultSize;
    _scrollback = defaultScrollback;
    _scheme = TerminalScheme.byId(TerminalScheme.defaultId);
    notifyListeners();
    await _prefs.remove(_familyKey);
    await _prefs.remove(_sizeKey);
    await _prefs.remove(_scrollbackKey);
    await _prefs.remove(_schemeKey);
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
