import 'package:daylight_terminal/services/syntax_highlight.dart';
import 'package:daylight_terminal/widgets/highlight_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [text] 안에서 [needle]이 어떤 색 종류로 칠해졌는지 (칠해지지 않았으면 null).
SyntaxClass? classOf(String text, SyntaxKind kind, String needle, {int from = 0}) {
  final start = text.indexOf(needle, from);
  expect(start, isNot(-1), reason: '$needle not found');
  for (final t in SyntaxHighlight.tokenize(text, kind)) {
    if (t.start <= start && start < t.end) return t.kind;
  }
  return null;
}

void main() {
  group('detect', () {
    test('by file name and extension', () {
      expect(SyntaxHighlight.detect('deploy.sh', ''), SyntaxKind.shell);
      expect(SyntaxHighlight.detect('.bashrc', ''), SyntaxKind.shell);
      expect(SyntaxHighlight.detect('DEPLOY.SH', ''), SyntaxKind.shell);
      expect(SyntaxHighlight.detect('nginx.conf', ''), SyntaxKind.config);
      expect(SyntaxHighlight.detect('app.service', ''), SyntaxKind.config);
      expect(SyntaxHighlight.detect('docker-compose.yml', ''), SyntaxKind.config);
      expect(SyntaxHighlight.detect('.env', ''), SyntaxKind.config);
      expect(SyntaxHighlight.detect('sshd_config', ''), SyntaxKind.config);
      expect(SyntaxHighlight.detect('photo.png', ''), SyntaxKind.none);
    });

    test('a shebang decides when the name does not (and for new files)', () {
      expect(SyntaxHighlight.detect(null, '#!/bin/bash\necho'), SyntaxKind.shell);
      expect(SyntaxHighlight.detect('backup', '#!/usr/bin/env zsh\n'), SyntaxKind.shell);
      expect(SyntaxHighlight.detect(null, '#!/usr/bin/python3\n'), SyntaxKind.none);
      expect(SyntaxHighlight.detect(null, 'echo hi'), SyntaxKind.none);
    });
  });

  group('shell', () {
    const script =
        '#!/bin/bash\n'
        '# restart the service\n'
        'NAME="web"\n'
        'if [ -f /etc/app.conf ]; then\n'
        '  echo "restarting \$NAME" && systemctl restart --now \${NAME} 42\n'
        'fi\n'
        "echo 'single \$quoted'\n";

    test('keywords, builtins, comments, strings, variables, options, numbers', () {
      expect(classOf(script, SyntaxKind.shell, '#!/bin/bash'), SyntaxClass.shebang);
      expect(classOf(script, SyntaxKind.shell, '# restart'), SyntaxClass.comment);
      expect(classOf(script, SyntaxKind.shell, 'NAME='), SyntaxClass.variable); // 대입
      expect(classOf(script, SyntaxKind.shell, '"web"'), SyntaxClass.string);
      expect(classOf(script, SyntaxKind.shell, 'if'), SyntaxClass.keyword);
      expect(classOf(script, SyntaxKind.shell, 'then'), SyntaxClass.keyword);
      expect(classOf(script, SyntaxKind.shell, 'fi'), SyntaxClass.keyword);
      expect(classOf(script, SyntaxKind.shell, 'echo'), SyntaxClass.builtin);
      expect(classOf(script, SyntaxKind.shell, '--now'), SyntaxClass.option);
      expect(classOf(script, SyntaxKind.shell, '\${NAME}'), SyntaxClass.variable);
      expect(classOf(script, SyntaxKind.shell, '42'), SyntaxClass.number);
      expect(classOf(script, SyntaxKind.shell, "'single"), SyntaxClass.string);
    });

    test('words inside strings, comments and bigger words are not keywords', () {
      const s = '# if then else\necho "do the done"\ncat my-if-file.txt\nls done.txt\n';
      expect(classOf(s, SyntaxKind.shell, 'if then'), SyntaxClass.comment);
      expect(classOf(s, SyntaxKind.shell, 'do the'), SyntaxClass.string);
      expect(classOf(s, SyntaxKind.shell, 'if-file'), isNull);
      expect(classOf(s, SyntaxKind.shell, 'done.txt'), isNull);
    });

    test('a # inside a word or after \$ is not a comment', () {
      const s = 'echo a#b \${#arr[@]} \$#\n';
      expect(classOf(s, SyntaxKind.shell, '#b'), isNull);
      expect(classOf(s, SyntaxKind.shell, '\${#arr[@]}'), SyntaxClass.variable);
    });

    test('tokens never overlap and are in order', () {
      final tokens = SyntaxHighlight.tokenize(script, SyntaxKind.shell);
      var pos = 0;
      for (final t in tokens) {
        expect(t.start, greaterThanOrEqualTo(pos));
        expect(t.end, greaterThan(t.start));
        pos = t.end;
      }
    });
  });

  group('config', () {
    const conf =
        '# main settings\n'
        '[server]\n'
        'listen = 8080\n'
        'name: "my site"\n'
        'debug = true\n'
        '; old style comment\n'
        'path=/srv/www   # trailing comment\n';

    test('comments, sections, keys, strings, numbers, booleans', () {
      expect(classOf(conf, SyntaxKind.config, '# main'), SyntaxClass.comment);
      expect(classOf(conf, SyntaxKind.config, '[server]'), SyntaxClass.section);
      expect(classOf(conf, SyntaxKind.config, 'listen'), SyntaxClass.key);
      expect(classOf(conf, SyntaxKind.config, '8080'), SyntaxClass.number);
      expect(classOf(conf, SyntaxKind.config, '"my site"'), SyntaxClass.string);
      expect(classOf(conf, SyntaxKind.config, 'true'), SyntaxClass.keyword);
      expect(classOf(conf, SyntaxKind.config, '; old'), SyntaxClass.comment);
      expect(classOf(conf, SyntaxKind.config, '# trailing'), SyntaxClass.comment);
    });
  });

  test('plain kinds and huge texts get no tokens', () {
    expect(SyntaxHighlight.tokenize('echo hi', SyntaxKind.none), isEmpty);
    expect(SyntaxHighlight.tokenize('#' * (SyntaxHighlight.maxChars + 1), SyntaxKind.shell), isEmpty);
  });

  group('HighlightController', () {
    Future<TextSpan> spanOf(WidgetTester tester, HighlightController c, {bool composing = false}) async {
      late TextSpan span;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            span = c.buildTextSpan(context: context, style: const TextStyle(fontSize: 13), withComposing: composing);
            return const SizedBox();
          },
        ),
      );
      return span;
    }

    String flat(TextSpan s) => s.toPlainText(includeSemanticsLabels: false);

    testWidgets('the colored pieces always add up to exactly the text', (tester) async {
      final c = HighlightController(text: '#!/bin/sh\n# hi\nif true; then echo "한글 \$x"; fi\n')
        ..fileName = 'a.sh'
        ..palette = SyntaxPalette.dark;
      final span = await spanOf(tester, c);
      expect(flat(span), c.text);
      expect(span.children, isNotEmpty);
      expect(
        span.children!.whereType<TextSpan>().any(
          (s) => s.style?.color == SyntaxPalette.dark.styleOf(SyntaxClass.keyword).color,
        ),
        isTrue,
      );
      c.dispose();
    });

    testWidgets('no palette or an unknown kind means plain text', (tester) async {
      final plain = HighlightController(text: 'echo hi')..fileName = 'notes.txt';
      plain.palette = SyntaxPalette.dark;
      expect((await spanOf(tester, plain)).children?.length ?? 1, 1);
      final noPalette = HighlightController(text: 'echo hi')..fileName = 'a.sh';
      expect(flat(await spanOf(tester, noPalette)), 'echo hi');
      plain.dispose();
      noPalette.dispose();
    });

    testWidgets('text being composed by the IME (e.g. Korean) keeps its underline', (tester) async {
      final c = HighlightController()
        ..fileName = 'a.sh'
        ..palette = SyntaxPalette.dark;
      c.value = const TextEditingValue(
        text: 'echo 한',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 5, end: 6),
      );
      final span = await spanOf(tester, c, composing: true);
      expect(flat(span), 'echo 한');
      final underlined = span.children!.whereType<TextSpan>().where(
        (s) => s.style?.decoration == TextDecoration.underline,
      );
      expect(underlined.map((s) => s.text).join(), '한');
      c.dispose();
    });

    testWidgets('the kind follows the file name, so saving a new file as foo.sh turns coloring on', (tester) async {
      final c = HighlightController(text: 'echo hi')..palette = SyntaxPalette.dark;
      expect(c.kind, SyntaxKind.none);
      c.fileName = 'foo.sh';
      expect(c.kind, SyntaxKind.shell);
      c.dispose();
    });
  });
}
