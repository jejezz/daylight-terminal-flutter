import 'package:flutter/painting.dart';
import 'package:xterm2/ui.dart' show TerminalTheme, TerminalThemes;

/// 터미널 색상 구성표. [id]가 설정(`terminal_color_scheme`)에 저장되고, [name]은 고유 이름이라 번역하지 않는다.
class TerminalScheme {
  const TerminalScheme(this.id, this.name, this.theme);

  final String id;
  final String name;
  final TerminalTheme theme;

  static const defaultId = 'vscode-dark';

  static final all = <TerminalScheme>[
    const TerminalScheme(defaultId, 'VS Code Dark', TerminalThemes.defaultTheme),
    _make(
      'solarized-dark', 'Solarized Dark',
      fg: 0xFF839496, bg: 0xFF002B36, cursor: 0xFF93A1A1, sel: 0xFF073642,
      ansi: [0xFF586E75, 0xFFDC322F, 0xFF859900, 0xFFB58900, 0xFF268BD2, 0xFFD33682, 0xFF2AA198, 0xFFEEE8D5],
      bright: [0xFF657B83, 0xFFF2605A, 0xFFA4B800, 0xFFDDA800, 0xFF4BA3E8, 0xFFE8599D, 0xFF3CC0B5, 0xFFFDF6E3],
    ),
    _make(
      'solarized-light', 'Solarized Light',
      fg: 0xFF657B83, bg: 0xFFFDF6E3, cursor: 0xFF586E75, sel: 0xFFEEE8D5,
      ansi: [0xFF073642, 0xFFDC322F, 0xFF738A05, 0xFFB58900, 0xFF268BD2, 0xFFD33682, 0xFF2AA198, 0xFF93A1A1],
      bright: [0xFF586E75, 0xFFE0443F, 0xFF859900, 0xFFC99A00, 0xFF1E7DC4, 0xFFE0468F, 0xFF1FB0A4, 0xFF839496],
      searchFg: 0xFF000000,
    ),
    _make(
      'dracula', 'Dracula',
      fg: 0xFFF8F8F2, bg: 0xFF282A36, cursor: 0xFFF8F8F2, sel: 0xFF44475A,
      ansi: [0xFF21222C, 0xFFFF5555, 0xFF50FA7B, 0xFFF1FA8C, 0xFFBD93F9, 0xFFFF79C6, 0xFF8BE9FD, 0xFFF8F8F2],
      bright: [0xFF6272A4, 0xFFFF6E6E, 0xFF69FF94, 0xFFFFFFA5, 0xFFD6ACFF, 0xFFFF92DF, 0xFFA4FFFF, 0xFFFFFFFF],
    ),
    _make(
      'one-dark', 'One Dark',
      fg: 0xFFABB2BF, bg: 0xFF282C34, cursor: 0xFF528BFF, sel: 0xFF3E4451,
      ansi: [0xFF282C34, 0xFFE06C75, 0xFF98C379, 0xFFE5C07B, 0xFF61AFEF, 0xFFC678DD, 0xFF56B6C2, 0xFFABB2BF],
      bright: [0xFF5C6370, 0xFFE06C75, 0xFF98C379, 0xFFE5C07B, 0xFF61AFEF, 0xFFC678DD, 0xFF56B6C2, 0xFFFFFFFF],
    ),
    _make(
      'tokyo-night', 'Tokyo Night',
      fg: 0xFFC0CAF5, bg: 0xFF1A1B26, cursor: 0xFFC0CAF5, sel: 0xFF33467C,
      ansi: [0xFF15161E, 0xFFF7768E, 0xFF9ECE6A, 0xFFE0AF68, 0xFF7AA2F7, 0xFFBB9AF7, 0xFF7DCFFF, 0xFFA9B1D6],
      bright: [0xFF414868, 0xFFF7768E, 0xFF9ECE6A, 0xFFE0AF68, 0xFF7AA2F7, 0xFFBB9AF7, 0xFF7DCFFF, 0xFFC0CAF5],
    ),
    _make(
      'gruvbox-dark', 'Gruvbox Dark',
      fg: 0xFFEBDBB2, bg: 0xFF282828, cursor: 0xFFEBDBB2, sel: 0xFF504945,
      ansi: [0xFF282828, 0xFFCC241D, 0xFF98971A, 0xFFD79921, 0xFF458588, 0xFFB16286, 0xFF689D6A, 0xFFA89984],
      bright: [0xFF928374, 0xFFFB4934, 0xFFB8BB26, 0xFFFABD2F, 0xFF83A598, 0xFFD3869B, 0xFF8EC07C, 0xFFEBDBB2],
    ),
    _make(
      'nord', 'Nord',
      fg: 0xFFD8DEE9, bg: 0xFF2E3440, cursor: 0xFFD8DEE9, sel: 0xFF434C5E,
      ansi: [0xFF3B4252, 0xFFBF616A, 0xFFA3BE8C, 0xFFEBCB8B, 0xFF81A1C1, 0xFFB48EAD, 0xFF88C0D0, 0xFFE5E9F0],
      bright: [0xFF4C566A, 0xFFBF616A, 0xFFA3BE8C, 0xFFEBCB8B, 0xFF81A1C1, 0xFFB48EAD, 0xFF8FBCBB, 0xFFECEFF4],
    ),
    _make(
      'monokai', 'Monokai',
      fg: 0xFFF8F8F2, bg: 0xFF272822, cursor: 0xFFF8F8F0, sel: 0xFF49483E,
      ansi: [0xFF272822, 0xFFF92672, 0xFFA6E22E, 0xFFF4BF75, 0xFF66D9EF, 0xFFAE81FF, 0xFFA1EFE4, 0xFFF8F8F2],
      bright: [0xFF75715E, 0xFFF92672, 0xFFA6E22E, 0xFFF4BF75, 0xFF66D9EF, 0xFFAE81FF, 0xFFA1EFE4, 0xFFF9F8F5],
    ),
    _make(
      'github-light', 'GitHub Light',
      fg: 0xFF24292F, bg: 0xFFFFFFFF, cursor: 0xFF0969DA, sel: 0xFFB6D6FB,
      ansi: [0xFF24292F, 0xFFCF222E, 0xFF1A9F3F, 0xFFB08800, 0xFF0969DA, 0xFF8250DF, 0xFF0E8A9B, 0xFF6E7781],
      bright: [0xFF57606A, 0xFFFA4549, 0xFF2DB24F, 0xFFD4A000, 0xFF218BFF, 0xFFA475F9, 0xFF1CB0C4, 0xFF8C959F],
      searchFg: 0xFF000000,
    ),
  ];

  /// 저장된 id에 맞는 구성표. 저장된 값이 없거나 모르는 id(지워졌거나 바뀐 것)는 기본([defaultId], VS Code Dark)으로 돌아간다.
  static TerminalScheme byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => all.firstWhere((s) => s.id == defaultId));

  /// 8색 + 밝은 8색을 순서대로(검정, 빨강, 초록, 노랑, 파랑, 자홍, 청록, 흰색) 받아 만든다.
  static TerminalScheme _make(
    String id,
    String name, {
    required int fg,
    required int bg,
    required int cursor,
    required int sel,
    required List<int> ansi,
    required List<int> bright,
    int searchFg = 0xFF000000,
  }) {
    Color c(int v) => Color(v);
    return TerminalScheme(
      id,
      name,
      TerminalTheme(
        cursor: c(cursor),
        selection: c(sel),
        foreground: c(fg),
        background: c(bg),
        black: c(ansi[0]),
        red: c(ansi[1]),
        green: c(ansi[2]),
        yellow: c(ansi[3]),
        blue: c(ansi[4]),
        magenta: c(ansi[5]),
        cyan: c(ansi[6]),
        white: c(ansi[7]),
        brightBlack: c(bright[0]),
        brightRed: c(bright[1]),
        brightGreen: c(bright[2]),
        brightYellow: c(bright[3]),
        brightBlue: c(bright[4]),
        brightMagenta: c(bright[5]),
        brightCyan: c(bright[6]),
        brightWhite: c(bright[7]),
        searchHitBackground: const Color(0XFFFFFF2B),
        searchHitBackgroundCurrent: const Color(0XFF31FF26),
        searchHitForeground: c(searchFg),
      ),
    );
  }
}
