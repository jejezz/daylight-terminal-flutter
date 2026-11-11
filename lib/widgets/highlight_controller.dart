import 'package:flutter/material.dart';

import '../services/syntax_highlight.dart';

/// 구문 강조에 쓰는 색. 밝은/어두운 테마에서 글이 잘 읽히도록 따로 정했다.
class SyntaxPalette {
  const SyntaxPalette(this._colors);

  final Map<SyntaxClass, Color> _colors;

  static const dark = SyntaxPalette({
    SyntaxClass.comment: Color(0xFF7F8FA6),
    SyntaxClass.shebang: Color(0xFF7F8FA6),
    SyntaxClass.string: Color(0xFF98C379),
    SyntaxClass.variable: Color(0xFF56B6C2),
    SyntaxClass.keyword: Color(0xFFC678DD),
    SyntaxClass.builtin: Color(0xFF61AFEF),
    SyntaxClass.number: Color(0xFFD19A66),
    SyntaxClass.option: Color(0xFFE5C07B),
    SyntaxClass.section: Color(0xFFE5C07B),
    SyntaxClass.key: Color(0xFF61AFEF),
  });

  static const light = SyntaxPalette({
    SyntaxClass.comment: Color(0xFF6A737D),
    SyntaxClass.shebang: Color(0xFF6A737D),
    SyntaxClass.string: Color(0xFF22863A),
    SyntaxClass.variable: Color(0xFF0A7A8A),
    SyntaxClass.keyword: Color(0xFF8A3FB5),
    SyntaxClass.builtin: Color(0xFF1B61C2),
    SyntaxClass.number: Color(0xFFB45A00),
    SyntaxClass.option: Color(0xFF8A6D00),
    SyntaxClass.section: Color(0xFF8A6D00),
    SyntaxClass.key: Color(0xFF1B61C2),
  });

  static SyntaxPalette of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  TextStyle styleOf(SyntaxClass c) {
    final color = _colors[c]!;
    return switch (c) {
      SyntaxClass.comment => TextStyle(color: color, fontStyle: FontStyle.italic),
      SyntaxClass.shebang || SyntaxClass.section => TextStyle(color: color, fontWeight: FontWeight.w700),
      SyntaxClass.keyword => TextStyle(color: color, fontWeight: FontWeight.w600),
      _ => TextStyle(color: color),
    };
  }
}

/// 입력 칸의 글에 색을 입히는 컨트롤러. 글은 그대로이고 색만 입힌다 (조각을 이어 붙이면 항상 원래 글과 같다).
/// 입력기(IME)로 조합 중인 글(한글 등)의 밑줄도 그대로 유지한다.
class HighlightController extends TextEditingController {
  HighlightController({super.text});

  /// 파일 이름. 어떤 강조를 쓸지 정하는 데 쓴다 (새 파일은 null).
  String? fileName;

  /// 색. 위젯이 테마에 맞춰 넣어 준다. null이면 강조하지 않는다.
  SyntaxPalette? palette;

  String? _cachedText;
  SyntaxKind? _cachedKind;
  List<SyntaxToken> _cachedTokens = const [];

  SyntaxKind get kind => SyntaxHighlight.detect(fileName, text);

  List<SyntaxToken> _tokens(String text, SyntaxKind kind) {
    if (_cachedKind != kind || _cachedText != text) {
      _cachedText = text;
      _cachedKind = kind;
      _cachedTokens = SyntaxHighlight.tokenize(text, kind);
    }
    return _cachedTokens;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final pal = palette;
    final k = kind;
    if (pal == null || k == SyntaxKind.none || text.length > SyntaxHighlight.maxChars) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final value = this.value;
    final composing = withComposing && value.isComposingRangeValid && !value.composing.isCollapsed
        ? value.composing
        : null;
    final children = <TextSpan>[];

    void add(int start, int end, TextStyle? tokenStyle) {
      if (end <= start) return;
      void piece(int s, int e, TextStyle? st) {
        if (e > s) children.add(TextSpan(text: text.substring(s, e), style: st));
      }

      if (composing == null || composing.end <= start || composing.start >= end) {
        piece(start, end, tokenStyle);
        return;
      }
      final cs = composing.start.clamp(start, end);
      final ce = composing.end.clamp(start, end);
      final under = (tokenStyle ?? const TextStyle()).merge(const TextStyle(decoration: TextDecoration.underline));
      piece(start, cs, tokenStyle);
      piece(cs, ce, under);
      piece(ce, end, tokenStyle);
    }

    var pos = 0;
    for (final t in _tokens(text, k)) {
      add(pos, t.start, null);
      add(t.start, t.end, pal.styleOf(t.kind));
      pos = t.end;
    }
    add(pos, text.length, null);
    return TextSpan(style: style, children: children);
  }
}
