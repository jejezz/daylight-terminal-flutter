import 'dart:io';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/line_ending.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_pty.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);

void main() {
  late LocalShellSession session;

  setUp(() {
    session = LocalShellSession(_bash, ptyFactory: FakePtyFactory().call, startDirectory: Directory.systemTemp.path);
  });

  tearDown(() => session.dispose());

  Future<void> pumpSender(WidgetTester tester, {required double height, double width = 700}) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ChangeNotifierProvider<TerminalSession>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: width, height: height, child: const LineSender()),
            ),
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

  Finder newFile() => find.byIcon(Icons.note_add_outlined);
  Finder open() => find.byIcon(Icons.folder_open_rounded);
  Finder save() => find.byIcon(Icons.save_outlined);
  Finder saveAs() => find.byIcon(Icons.save_as_outlined);
  List<Finder> fileButtons() => [newFile(), open(), save(), saveAs()];

  /// 아이콘이 아니라 버튼 전체(누르는 영역)를 찾는다.
  Finder buttonOf(Finder icon) => find.ancestor(of: icon, matching: find.byType(IconButton));
  Finder endingChip() => find.byType(PopupMenuButton<LineEnding>);
  Finder sendButton() => buttonOf(find.byIcon(Icons.send_rounded));

  testWidgets('the four file buttons are in the bottom bar, left-aligned, in editor order, on one line', (
    tester,
  ) async {
    await pumpSender(tester, height: 200);
    final sender = tester.getRect(find.byType(LineSender));
    final field = rectOf(tester, find.byType(TextField));
    final rects = [for (final b in fileButtons()) rectOf(tester, buttonOf(b))];

    // 입력 칸 아래 한 줄에, 왼쪽부터 새로 만들기, 열기, 저장, 다른 이름으로 저장.
    for (var i = 0; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(field.bottom - 1), reason: '버튼 $i가 입력 칸 아래에 있어야 한다');
    }
    for (var i = 0; i < rects.length - 1; i++) {
      expect(rects[i].right, lessThanOrEqualTo(rects[i + 1].left + 1), reason: '버튼 $i가 다음 버튼과 겹친다');
      expect(rects[i].center.dy, closeTo(rects[i + 1].center.dy, 0.01), reason: '한 줄이 아니다');
    }
    // 왼쪽 정렬: 첫 버튼이 왼쪽 안쪽 여백(8)에 붙어 있다.
    expect(rects.first.left, closeTo(sender.left + 8, 1));
  });

  testWidgets('the line ending chip and the send button are right-aligned on the same bar', (tester) async {
    await pumpSender(tester, height: 200);
    final sender = tester.getRect(find.byType(LineSender));
    final chip = rectOf(tester, endingChip());
    final send = rectOf(tester, sendButton());
    final saveAsButton = rectOf(tester, buttonOf(saveAs()));

    expect(send.right, closeTo(sender.right - 8, 1));
    expect(chip.right, lessThan(send.left));
    expect(chip.center.dy, closeTo(send.center.dy, 0.5));
    expect(chip.center.dy, closeTo(saveAsButton.center.dy, 0.5), reason: '파일 버튼과 같은 줄이어야 한다');
    // 왼쪽 그룹과 오른쪽 그룹이 겹치지 않는다.
    expect(saveAsButton.right, lessThan(chip.left));
  });

  Finder box() => find.byKey(const ValueKey('line-sender-box'));

  testWidgets('there is no title bar: the file name sits inside the input box, top-left, above the text', (
    tester,
  ) async {
    await pumpSender(tester, height: 200);
    final sender = tester.getRect(find.byType(LineSender));
    final inputBox = rectOf(tester, box());
    final field = rectOf(tester, find.byType(TextField));
    final name = rectOf(tester, find.text('제목 없음'));

    // 입력 칸이 맨 위(안쪽 여백 8)부터 시작한다 — 그 위에 별도의 제목 줄이 없다.
    expect(inputBox.top, closeTo(sender.top + 8, 1));
    // 이름은 그 상자 안 왼쪽 위에 있고, 글을 쓰는 영역 위에 있다.
    expect(name.left, greaterThanOrEqualTo(inputBox.left));
    expect(name.left, lessThan(inputBox.left + 24));
    expect(name.top, greaterThanOrEqualTo(inputBox.top));
    expect(name.bottom, lessThanOrEqualTo(field.top + 1));
    expect(field.top, greaterThanOrEqualTo(inputBox.top));
    expect(field.bottom, closeTo(inputBox.bottom, 1));
    // 버튼은 모두 상자 아래 하단 줄에 있다.
    for (final b in [...fileButtons(), find.byIcon(Icons.send_rounded)]) {
      expect(rectOf(tester, b).top, greaterThanOrEqualTo(inputBox.bottom - 1), reason: '버튼이 상자 안/위에 있다');
    }
  });

  testWidgets('the name stays put while the text scrolls, and the name row does not scroll away', (tester) async {
    await pumpSender(tester, height: 200);
    final before = rectOf(tester, find.text('제목 없음'));
    await tester.enterText(find.byType(TextField), List.generate(60, (i) => 'line ${i + 1}').join('\n'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(TextField), matching: find.byType(Scrollable)).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    // 글이 맨 끝까지 스크롤되어도 이름은 같은 자리에 있다 (변경 표시는 붙지만 왼쪽 위 위치는 그대로).
    final after = rectOf(tester, find.textContaining('제목 없음'));
    expect(after.left, closeTo(before.left, 0.01));
    expect(after.top, closeTo(before.top, 0.01));
  });

  testWidgets('the buttons are bigger than before (icon 22, 40x40 touch area)', (tester) async {
    await pumpSender(tester, height: 200);
    for (final b in fileButtons()) {
      expect(tester.getSize(buttonOf(b)), const Size(40, 40));
      expect(tester.widget<IconButton>(buttonOf(b)).iconSize, 22);
    }
  });

  testWidgets('the bottom bar stays glued to the bottom edge and keeps its size at any height', (tester) async {
    final fromBottom = <double, List<double>>{};
    final sizes = <double, List<Size>>{};
    final lefts = <double, List<double>>{};
    for (final h in [132.0, 150.0, 220.0, 400.0]) {
      await pumpSender(tester, height: h);
      final sender = tester.getRect(find.byType(LineSender));
      final targets = [...fileButtons().map(buttonOf), endingChip(), sendButton()];
      final rects = [for (final f in targets) rectOf(tester, f)];
      fromBottom[h] = [for (final r in rects) sender.bottom - r.bottom];
      lefts[h] = [for (final r in rects) r.left - sender.left];
      sizes[h] = [for (final r in rects) r.size];
      expect(tester.takeException(), isNull, reason: '높이 $h에서 넘침이 있다');
    }
    for (final h in fromBottom.keys) {
      for (var i = 0; i < fromBottom[h]!.length; i++) {
        expect(fromBottom[h]![i], closeTo(fromBottom[132.0]![i], 0.01), reason: '높이 $h, 컨트롤 $i가 맨 아래에서 떨어졌다');
        expect(lefts[h]![i], closeTo(lefts[132.0]![i], 0.01), reason: '높이 $h, 컨트롤 $i의 가로 위치가 바뀌었다');
        expect(sizes[h]![i], sizes[132.0]![i], reason: '높이 $h, 컨트롤 $i의 크기가 바뀌었다');
      }
    }
  });

  testWidgets('at the smallest height everything is intact and the box still has room for a line', (tester) async {
    await pumpSender(tester, height: 132);
    expect(tester.takeException(), isNull);
    expect(rectOf(tester, find.byType(TextField)).height, greaterThanOrEqualTo(40));
    final sender = tester.getRect(find.byType(LineSender));
    for (final f in [find.text('제목 없음'), ...fileButtons(), endingChip(), sendButton()]) {
      final r = rectOf(tester, f);
      expect(r.top, greaterThanOrEqualTo(sender.top), reason: '위로 잘렸다');
      expect(r.bottom, lessThanOrEqualTo(sender.bottom), reason: '아래로 잘렸다');
    }
  });

  testWidgets('the box uses the full width (no side column)', (tester) async {
    await pumpSender(tester, height: 200);
    final sender = tester.getRect(find.byType(LineSender));
    final field = rectOf(tester, find.byType(TextField));
    expect(field.left, closeTo(sender.left + 8, 1));
    expect(field.right, closeTo(sender.right - 8, 1));
  });

  testWidgets('the send button is a compact filled button, not the big round one', (tester) async {
    await pumpSender(tester, height: 200);
    final send = rectOf(tester, sendButton());
    expect(send.height, lessThanOrEqualTo(40));
    expect(send.width, lessThanOrEqualTo(52));
    // 다른 버튼과 마찬가지로 둥근 사각형이다 (원이 아니다).
    final shape = tester.widget<IconButton>(sendButton()).style?.shape?.resolve({});
    expect(shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('choosing a line ending from the chip changes what the sender appends', (tester) async {
    await pumpSender(tester, height: 200);
    expect(find.text(r'\r'), findsOneWidget);
    await tester.tap(endingChip());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(r'\r\n').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(session.lineEnding, LineEnding.crlf);
    expect(find.text(r'\r\n'), findsOneWidget);
  });

  testWidgets('the narrowest layout the app allows (a sender about 340 wide) does not overflow', (tester) async {
    await pumpSender(tester, height: 150, width: 340);
    expect(tester.takeException(), isNull);
    final sender = tester.getRect(find.byType(LineSender));
    final saveAsButton = rectOf(tester, buttonOf(saveAs()));
    expect(saveAsButton.right, lessThan(rectOf(tester, endingChip()).left), reason: '왼쪽 그룹과 오른쪽 그룹이 겹친다');
    expect(rectOf(tester, sendButton()).right, lessThanOrEqualTo(sender.right));
  });

  /// 하단 줄 위쪽에 선(1px)이 있는 박스 — 버튼들을 감싸고 있다.
  Finder dividerBar() => find.byWidgetPredicate((w) {
    if (w is! Container) return false;
    final d = w.decoration;
    if (d is! BoxDecoration) return false;
    final border = d.border;
    return border is Border &&
        border.top.style == BorderStyle.solid &&
        border.top.width == 1 &&
        border.bottom.style == BorderStyle.none;
  });

  testWidgets('a line above the button bar separates it from the box: below the box, as wide as the box', (
    tester,
  ) async {
    await pumpSender(tester, height: 200);
    final bar = rectOf(tester, dividerBar());
    final field = rectOf(tester, find.byType(TextField));
    // 입력 칸 아래, 칸과 같은 폭의 선이 줄의 맨 위에 있다.
    expect(bar.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(bar.left, closeTo(field.left, 1));
    expect(bar.right, closeTo(field.right, 1));
    // 모든 버튼이 그 선 아래(줄 안)에 있다.
    for (final f in [...fileButtons().map(buttonOf), endingChip(), sendButton()]) {
      final r = rectOf(tester, f);
      expect(r.top, greaterThanOrEqualTo(bar.top + 1), reason: '버튼이 선 위로 올라갔다');
      expect(r.bottom, lessThanOrEqualTo(bar.bottom));
    }
    // 선은 눈에 보이는 색이다 (투명이 아니다).
    final color = ((tester.widget<Container>(dividerBar()).decoration! as BoxDecoration).border! as Border).top.color;
    expect(color.a, greaterThan(0));
  });

  testWidgets('the line stays glued above the bar at any height', (tester) async {
    double? distance;
    for (final h in [132.0, 200.0, 400.0]) {
      await pumpSender(tester, height: h);
      final sender = tester.getRect(find.byType(LineSender));
      final d = sender.bottom - rectOf(tester, dividerBar()).top;
      distance ??= d;
      expect(d, closeTo(distance, 0.01), reason: '높이 $h에서 선의 위치가 달라졌다');
      expect(tester.takeException(), isNull);
    }
  });
}
