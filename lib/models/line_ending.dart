// portside-flutter의 LineSender에서 가져와 SSH에 맞게 고침.

/// LineSender에서 Enter를 눌렀을 때 뒤에 붙일 종단 문자.
/// SSH pty에서 Enter 키는 CR(`\r`)이라 기본값은 [cr]이다.
enum LineEnding { none, lf, cr, crlf }

extension LineEndingX on LineEnding {
  String get suffix => switch (this) {
    LineEnding.none => '',
    LineEnding.lf => '\n',
    LineEnding.cr => '\r',
    LineEnding.crlf => '\r\n',
  };

  /// 드롭다운 표기. [LineEnding.none]은 번역할 문구라서 null — UI가 l10n으로 채운다.
  String? get label => switch (this) {
    LineEnding.none => null,
    LineEnding.lf => r'\n',
    LineEnding.cr => r'\r',
    LineEnding.crlf => r'\r\n',
  };
}
