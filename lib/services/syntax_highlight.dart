/// 원격 편집기의 간단한 구문 강조 (vim처럼 키워드·문자열·주석에 색을 입힌다). 서버 관리에서 가장 많이 고치는
/// 셸 스크립트와 설정 파일(ini·conf·yaml·.env·systemd 유닛 등)만 다룬다. 정규식 한 번으로 글 전체를 훑는다.
enum SyntaxKind { none, shell, config }

enum SyntaxClass { comment, shebang, string, variable, keyword, builtin, number, option, section, key }

class SyntaxToken {
  const SyntaxToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final SyntaxClass kind;

  @override
  String toString() => 'SyntaxToken($start-$end $kind)';
}

abstract final class SyntaxHighlight {
  /// 이보다 긴 글은 강조하지 않는다 (키를 칠 때마다 글 전체를 다시 훑기 때문이다).
  static const maxChars = 400000;

  static const _shellExts = {'sh', 'bash', 'zsh', 'ksh', 'dash', 'ash'};
  static const _shellNames = {
    '.bashrc',
    '.bash_profile',
    '.bash_login',
    '.bash_logout',
    '.bash_aliases',
    '.profile',
    '.zshrc',
    '.zprofile',
    '.zshenv',
    '.zlogin',
    'bashrc',
    'profile',
    'bash.bashrc',
  };
  static const _configExts = {
    'conf',
    'cfg',
    'config',
    'ini',
    'env',
    'toml',
    'yaml',
    'yml',
    'properties',
    'cnf',
    'service',
    'timer',
    'socket',
    'mount',
    'target',
    'path',
    'repo',
  };
  static const _configNames = {'crontab', 'fstab', 'hosts', 'sudoers', 'environment', 'resolv.conf', '.gitconfig'};

  /// 파일 이름(과 글 앞부분의 `#!`)으로 어떤 강조를 쓸지 정한다. 이름을 모르면(새 파일) 첫 줄의 shebang만 본다.
  static SyntaxKind detect(String? fileName, String text) {
    if (fileName != null) {
      final name = fileName.toLowerCase();
      if (_shellNames.contains(name)) return SyntaxKind.shell;
      if (_configNames.contains(name) || name.endsWith('_config')) return SyntaxKind.config;
      final dot = name.lastIndexOf('.');
      if (dot > 0) {
        final ext = name.substring(dot + 1);
        if (_shellExts.contains(ext)) return SyntaxKind.shell;
        if (_configExts.contains(ext)) return SyntaxKind.config;
      } else if (dot == 0 && _configExts.contains(name.substring(1))) {
        return SyntaxKind.config; // `.env`
      }
    }
    if (text.startsWith('#!')) {
      final end = text.indexOf('\n');
      final first = end == -1 ? text : text.substring(0, end);
      if (RegExp(r'\b(?:ba|z|k|da|a)?sh\b').hasMatch(first)) return SyntaxKind.shell;
    }
    return SyntaxKind.none;
  }

  static const _shellKeywords =
      'if|then|else|elif|fi|for|while|until|do|done|case|esac|in|function|select|time|coproc|return|break|continue|exit';
  static const _shellBuiltins =
      'echo|printf|read|cd|pwd|export|local|readonly|declare|typeset|unset|shift|source|alias|unalias|eval|exec|set|'
      'trap|test|true|false|wait|kill|umask|ulimit|type|command|builtin|getopts|let|mapfile|pushd|popd|dirs|history';

  static final _shell = RegExp(
    r'(?<shebang>^#![^\n]*)'
    r'|(?<comment>(?:^|(?<=[\s;&|(]))#[^\n]*)'
    r'|(?<string>"(?:\\[\s\S]|[^"\\])*"?|\x27[^\x27]*\x27?)'
    r'|(?<variable>\$(?:\{[^}\n]*\}?|[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-]))'
    r'|(?<assign>(?<=^|[\s;&|(])[A-Za-z_][A-Za-z0-9_]*(?==))'
    '|(?<keyword>(?<![\\w.\$/-])(?:$_shellKeywords)(?![\\w.-]))'
    '|(?<builtin>(?<![\\w.\$/-])(?:$_shellBuiltins)(?![\\w.-])|\\[\\[|\\]\\])'
    r'|(?<option>(?<=\s)--?[A-Za-z][\w-]*)'
    r'|(?<number>(?<![\w.-])\d+(?:\.\d+)?(?![\w.-]))',
    multiLine: true,
  );

  static final _config = RegExp(
    r'(?<comment>^[ \t]*[#;][^\n]*|(?<=\s)#[^\n]*)'
    r'|(?<section>^[ \t]*\[[^\]\n]*\])'
    r'|(?<string>"(?:\\.|[^"\\\n])*"?|\x27[^\x27\n]*\x27?)'
    r'|(?<key>^[ \t]*(?:-[ \t]+)?[A-Za-z_][\w.\-]*(?=[ \t]*[=:]))'
    r'|(?<keyword>(?<![\w.-])(?:true|false|yes|no|on|off|null)(?![\w-]))'
    r'|(?<number>(?<![\w.-])\d+(?:\.\d+)?(?![\w.-]))',
    multiLine: true,
  );

  /// [text]의 색칠할 조각들 (겹치지 않고 앞에서부터 차례로).
  static List<SyntaxToken> tokenize(String text, SyntaxKind kind) {
    if (kind == SyntaxKind.none || text.isEmpty || text.length > maxChars) return const [];
    final re = kind == SyntaxKind.shell ? _shell : _config;
    final names = kind == SyntaxKind.shell
        ? const [
            'shebang',
            'comment',
            'string',
            'variable',
            'assign',
            'keyword',
            'builtin',
            'option',
            'number',
          ]
        : const ['comment', 'section', 'string', 'key', 'keyword', 'number'];
    final out = <SyntaxToken>[];
    for (final m in re.allMatches(text)) {
      if (m.end == m.start) continue;
      for (final name in names) {
        if (m.namedGroup(name) == null) continue;
        out.add(SyntaxToken(m.start, m.end, _classOf(name)));
        break;
      }
    }
    return out;
  }

  static SyntaxClass _classOf(String group) => switch (group) {
    'shebang' => SyntaxClass.shebang,
    'comment' => SyntaxClass.comment,
    'string' => SyntaxClass.string,
    'variable' || 'assign' => SyntaxClass.variable,
    'keyword' => SyntaxClass.keyword,
    'builtin' => SyntaxClass.builtin,
    'option' => SyntaxClass.option,
    'number' => SyntaxClass.number,
    'section' => SyntaxClass.section,
    _ => SyntaxClass.key,
  };
}
