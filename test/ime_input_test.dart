import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/src/ui/custom_text_edit.dart';

/// 터미널 입력(IME)이 확정된 글자를 되풀이해서 보내지 않는지: Windows 한글 IME는 앞 글자를 확정하면서 곧바로
/// 다음 글자 조합을 시작해서 확정된 글과 조합 중인 글이 한 값에 같이 온다.
void main() {
  Future<(CustomTextEditState, List<String>, List<String?>)> pump(
    WidgetTester tester, {
    bool deleteDetection = false,
  }) async {
    final inserted = <String>[];
    final composing = <String?>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomTextEdit(
          viewId: 0,
          focusNode: focus,
          deleteDetection: deleteDetection,
          onInsert: inserted.add,
          onDelete: () => inserted.add('<del>'),
          onComposing: composing.add,
          onAction: (_) {},
          onKeyEvent: (_, _) => KeyEventResult.ignored,
          child: const SizedBox(),
        ),
      ),
    );
    final state = tester.state<CustomTextEditState>(
      find.byType(CustomTextEdit),
    );
    return (state, inserted, composing);
  }

  TextEditingValue composingValue(String text, int start, int end) =>
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: end),
        composing: TextRange(start: start, end: end),
      );
  TextEditingValue committed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  testWidgets('한글 입력: 확정된 글자가 한 번씩만 전달된다 (엔진이 글을 비우지 않을 때)', (tester) async {
    final (s, inserted, _) = await pump(tester);
    // ㅎ ㅏ ㄴ → (ㄱ: 한 확정 + ㄱ 조합) → ㅡ → ㄹ → (스페이스: 글 확정)
    s.updateEditingValue(composingValue('ㅎ', 0, 1));
    s.updateEditingValue(composingValue('하', 0, 1));
    s.updateEditingValue(composingValue('한', 0, 1));
    s.updateEditingValue(composingValue('한ㄱ', 1, 2));
    s.updateEditingValue(composingValue('한그', 1, 2));
    s.updateEditingValue(composingValue('한글', 1, 2));
    s.updateEditingValue(committed('한글 '));
    expect(inserted.join(), '한글 ');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('한글 입력: 확정 때마다 글이 비워져도 되풀이되지 않는다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(composingValue('한', 0, 1));
    s.updateEditingValue(committed('한')); // 확정 → 우리가 글을 비운다
    s.updateEditingValue(composingValue('ㄱ', 0, 1));
    s.updateEditingValue(composingValue('그', 0, 1));
    s.updateEditingValue(composingValue('글', 0, 1));
    s.updateEditingValue(committed('글'));
    s.updateEditingValue(committed(' '));
    expect(inserted.join(), '한글 ');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('한글 입력: 엔진이 비우기를 늦게 반영해 이어지지 않는 글이 와도 되풀이되지 않는다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(composingValue('한', 0, 1));
    s.updateEditingValue(composingValue('한ㄱ', 1, 2)); // 한 확정 + ㄱ 조합
    s.updateEditingValue(composingValue('ㄱ', 0, 1)); // 엔진이 글을 비운 뒤의 조합
    s.updateEditingValue(composingValue('글', 0, 1));
    s.updateEditingValue(committed('글'));
    expect(inserted.join(), '한글');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  // Windows에서 실제로 기록한 순서 (한글 IME). 확정된 글이 우리가 비운 뒤에도 남아 오고(`글`이 여러 번),
  // 커서 뒤에 같은 글이 한 번 더 붙어 오기도 한다.
  TextEditingValue raw(
    String text,
    int caret, [
    TextRange composing = TextRange.empty,
  ]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
    composing: composing,
  );

  testWidgets('Windows 한글 IME 기록: 확정한 글이 남아 와도 한 번만 전달된다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(raw('ㄱ', 1, const TextRange(start: 0, end: 1)));
    s.updateEditingValue(raw('그', 1, const TextRange(start: 0, end: 1)));
    s.updateEditingValue(raw('글', 1, const TextRange(start: 0, end: 1)));
    s.updateEditingValue(raw('글', 1, const TextRange(start: 1, end: 1))); // 확정
    s.updateEditingValue(
      raw('글윈', 2, const TextRange(start: 1, end: 2)),
    ); // 우리가 비웠는데도 남아 있다
    s.updateEditingValue(raw('글', 1, const TextRange(start: 1, end: 1)));
    s.updateEditingValue(raw('글', 1, const TextRange(start: -1, end: -1)));
    s.updateEditingValue(
      raw('', 0, const TextRange(start: -1, end: -1)),
    ); // 비우기가 반영됨
    expect(inserted.join(), '글');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows 한글 IME 기록: 커서 뒤에 되풀이돼 붙은 글은 쓰지 않는다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(raw('산산', 1));
    s.updateEditingValue(raw('산산', 1));
    s.updateEditingValue(raw('', 0));
    s.updateEditingValue(raw('값값', 1));
    s.updateEditingValue(raw('값값', 1));
    expect(inserted.join(), '산값');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('한글 입력: 글을 비우지 않고 이어 붙는 값을 그대로 받아도 한 번씩만 전달된다', (tester) async {
    final (s, inserted, composing) = await pump(tester);
    TextRange r(int a, int b) => TextRange(start: a, end: b);
    s.updateEditingValue(raw('ㅎ', 1, r(0, 1)));
    s.updateEditingValue(raw('하', 1, r(0, 1)));
    s.updateEditingValue(raw('한', 1, r(0, 1)));
    s.updateEditingValue(raw('한', 1)); // 확정
    s.updateEditingValue(raw('한ㄱ', 2, r(1, 2)));
    s.updateEditingValue(raw('한그', 2, r(1, 2)));
    s.updateEditingValue(raw('한글', 2, r(1, 2)));
    s.updateEditingValue(raw('한글', 2)); // 확정
    s.updateEditingValue(raw('한글ㅇ', 3, r(2, 3)));
    s.updateEditingValue(raw('한글으', 3, r(2, 3)));
    s.updateEditingValue(raw('한글을', 3, r(2, 3)));
    s.updateEditingValue(raw('한글을', 3));
    expect(inserted.join(), '한글을');
    expect(composing.last, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('영문 입력과 지우기', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('a'));
    s.updateEditingValue(committed('b'));
    expect(inserted, ['a', 'b']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('지우기 감지(deleteDetection): 초기 글보다 짧아지면 삭제', (tester) async {
    final (s, inserted, _) = await pump(tester, deleteDetection: true);
    s.updateEditingValue(committed('  x'));
    s.updateEditingValue(committed(' '));
    expect(inserted, ['x', '<del>']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  // macOS 한글 IME: 조합 표시 없이 글자마다 "앞 글자를 바꿔 달라"(replacementRange)는 insertText로 온다. 엔진의 글이 이어지는 값으로 들어온다.
  testWidgets('macOS: 글자가 바뀌면 백스페이스 + 새 글로 터미널에 전달된다 (ㅎ → 하 → 한)', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('ㅎ'));
    s.updateEditingValue(committed('하'));
    s.updateEditingValue(committed('한'));
    expect(inserted, ['ㅎ', '<del>', '하', '<del>', '한']);
    expect(s.imeBufferActive, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 다음 글자가 이어 붙으면 앞 글자는 그대로 두고 덧붙인다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('한'));
    s.updateEditingValue(committed('한ㄱ'));
    s.updateEditingValue(committed('한그'));
    s.updateEditingValue(committed('한글'));
    expect(inserted, ['한', 'ㄱ', '<del>', '그', '<del>', '글']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 공백 같은 한글이 아닌 글이 오면 글을 비운다 (이어 쓰지 않게)', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('한'));
    s.updateEditingValue(committed('한 '));
    expect(inserted, ['한', ' ']);
    expect(s.imeBufferActive, isFalse);
    s.updateEditingValue(committed('ㄱ')); // 비운 뒤라 새로 시작
    expect(inserted, ['한', ' ', 'ㄱ']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: Backspace로 자모가 지워지면 백스페이스로 전달되고, 다 지우면 비운다', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('한'));
    s.updateEditingValue(committed('하')); // IME가 한 → 하로 고침
    s.updateEditingValue(committed('')); // ㅎ까지 지움
    expect(inserted, ['한', '<del>', '하', '<del>']);
    expect(s.imeBufferActive, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 영문은 글을 남기지 않고 그대로 전달된다', (tester) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('a'));
    s.updateEditingValue(committed('b'));
    expect(inserted, ['a', 'b']);
    expect(s.imeBufferActive, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 한글 쓰는 중 Backspace를 IME가 처리하지 않으면 직접 한 글자를 지우고 글을 비운다', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('ㅎ'));
    s.backspaceFallback();
    await tester.pump(const Duration(milliseconds: 100));
    expect(inserted, ['ㅎ', '<del>']);
    expect(s.imeBufferActive, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 한글 쓰는 중 Backspace를 IME가 처리하면(입력이 오면) 따로 지우지 않는다', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('하'));
    s.backspaceFallback();
    s.updateEditingValue(committed('ㅎ')); // IME가 고친 결과
    await tester.pump(const Duration(milliseconds: 100));
    expect(inserted, ['하', '<del>', 'ㅎ']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: Backspace에 IME가 같은 글을 다시 보내기만 하면 글이 안 바뀐 것이라 직접 지운다', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.updateEditingValue(committed('ㅎ'));
    s.backspaceFallback();
    s.updateEditingValue(committed('ㅎ')); // 같은 글
    await tester.pump(const Duration(milliseconds: 100));
    expect(inserted, ['ㅎ', '<del>']);
    expect(s.imeBufferActive, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS: 조합 중인 자음 하나에서 Backspace를 누르면 확정돼 오는 글을 입력으로 보내지 않는다', (
    tester,
  ) async {
    final (s, inserted, _) = await pump(tester);
    s.widget.focusNode.requestFocus();
    await tester.pump();
    s.updateEditingValue(composingValue('ㅎ', 0, 1));
    // Backspace 키(조합 중이라 CustomTextEdit이 먼저 받는다)
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    s.updateEditingValue(committed('ㅎ')); // IME가 지우지 않고 그대로 확정
    expect(inserted, isEmpty);
    expect(s.imeBufferActive, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
