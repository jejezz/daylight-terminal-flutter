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
  Finder open() => find.byIcon(Icons.folder_open_rounded);
  Finder save() => find.byIcon(Icons.save_outlined);
  Finder saveAs() => find.byIcon(Icons.save_as_outlined);
  Finder newFile() => find.byIcon(Icons.note_add_outlined);
  List<Finder> buttons() => [newFile(), open(), save(), saveAs()];

  /// LineSender 왼쪽 위 모서리를 기준으로 한 위치 — 영역이 아래쪽에 붙어 있어서 높이가 달라지면 화면 좌표는 바뀐다.
  Offset fromTopLeft(WidgetTester tester, Finder f) => tester.getCenter(f) - tester.getTopLeft(find.byType(LineSender));

  testWidgets('the file buttons sit in a title bar above the box, in order: new, open, save, save as', (tester) async {
    await pumpSender(tester, height: 160);
    final field = rectOf(tester, find.byType(TextField));
    for (final b in buttons()) {
      expect(rectOf(tester, b).bottom, lessThanOrEqualTo(field.top + 1), reason: '버튼이 입력 칸 위(제목 줄)에 있어야 한다');
    }
    // 한 줄에 쭉 — 모두 같은 높이에 놓이고 왼쪽부터 새로 만들기, 열기, 저장, 다른 이름으로 저장 순서다.
    final rects = [for (final b in buttons()) rectOf(tester, b)];
    for (var i = 0; i < rects.length - 1; i++) {
      expect(rects[i].right, lessThanOrEqualTo(rects[i + 1].left + 1), reason: '버튼 $i가 다음 버튼과 겹친다');
      expect(rects[i].center.dy, closeTo(rects[i + 1].center.dy, 0.01), reason: '한 줄이 아니다');
    }
  });

  testWidgets('the buttons are right-aligned on the title bar, with the file name on the left', (tester) async {
    await pumpSender(tester, height: 160);
    final sender = tester.getRect(find.byType(LineSender));
    // 버튼 줄의 오른쪽 끝이 LineSender의 오른쪽 안쪽 여백(8)에 닿아 있다.
    // (아이콘이 아니라 버튼 전체 영역으로 잰다: 아이콘 둘레에 눌리는 여백이 있다.)
    final lastButton = find.ancestor(of: saveAs(), matching: find.byType(IconButton));
    expect(rectOf(tester, lastButton).right, closeTo(sender.right - 8, 1));
    final name = rectOf(tester, find.text('제목 없음'));
    expect(name.left, lessThan(sender.left + 40));
    expect(name.right, lessThan(rectOf(tester, newFile()).left));
  });

  testWidgets('their position and size do not depend on the height of the LineSender', (tester) async {
    final positions = <double, List<Offset>>{};
    final sizes = <double, List<Size>>{};
    for (final h in [132.0, 150.0, 220.0, 400.0]) {
      await pumpSender(tester, height: h);
      positions[h] = [for (final b in buttons()) fromTopLeft(tester, b)];
      sizes[h] = [for (final b in buttons()) tester.getSize(b)];
      expect(tester.takeException(), isNull, reason: '높이 $h에서 넘침이 있다');
    }
    final base = positions[132.0]!;
    for (final h in positions.keys) {
      for (var i = 0; i < base.length; i++) {
        expect(positions[h]![i].dx, closeTo(base[i].dx, 0.01), reason: '높이 $h, 버튼 $i의 가로 위치');
        expect(positions[h]![i].dy, closeTo(base[i].dy, 0.01), reason: '높이 $h, 버튼 $i의 세로 위치');
        expect(sizes[h]![i], sizes[132.0]![i], reason: '높이 $h, 버튼 $i의 크기');
      }
    }
  });

  testWidgets('at the smallest height the title bar is intact and the box still has room', (tester) async {
    await pumpSender(tester, height: 132);
    expect(tester.takeException(), isNull);
    expect(rectOf(tester, open()).top, greaterThanOrEqualTo(tester.getTopLeft(find.byType(LineSender)).dy));
    expect(rectOf(tester, find.byType(TextField)).height, greaterThanOrEqualTo(40));
  });

  Finder endingChip() => find.byType(PopupMenuButton<LineEnding>);
  Finder sendButton() => find.ancestor(of: find.byIcon(Icons.send_rounded), matching: find.byType(IconButton));

  testWidgets('the line ending chip and the send button share one bar under the box; the box uses the full width', (
    tester,
  ) async {
    await pumpSender(tester, height: 200);
    final sender = tester.getRect(find.byType(LineSender));
    final field = rectOf(tester, find.byType(TextField));
    final chip = rectOf(tester, endingChip());
    final send = rectOf(tester, sendButton());

    // 입력 칸은 옆 열에 폭을 내주지 않고 전체 폭을 쓴다.
    expect(field.left, closeTo(sender.left + 8, 1));
    expect(field.right, closeTo(sender.right - 8, 1));
    // 둘 다 칸 아래, 같은 줄이다. 줄 끝 선택은 왼쪽, 전송은 오른쪽 끝.
    expect(chip.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(send.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(chip.center.dy, closeTo(send.center.dy, 0.5));
    expect(chip.left, closeTo(sender.left + 8, 1));
    expect(send.right, closeTo(sender.right - 8, 1));
    expect(chip.right, lessThan(send.left));
    // 위쪽 파일 버튼은 제목 줄에 그대로.
    for (final b in buttons()) {
      expect(rectOf(tester, b).bottom, lessThanOrEqualTo(field.top + 1));
    }
  });

  testWidgets('the bottom bar stays glued to the bottom edge and keeps its size at any height', (tester) async {
    final fromBottom = <double, List<double>>{};
    final sizes = <double, List<Size>>{};
    for (final h in [132.0, 200.0, 400.0]) {
      await pumpSender(tester, height: h);
      final sender = tester.getRect(find.byType(LineSender));
      final chip = rectOf(tester, endingChip());
      final send = rectOf(tester, sendButton());
      fromBottom[h] = [sender.bottom - chip.bottom, sender.bottom - send.bottom];
      sizes[h] = [chip.size, send.size];
      expect(tester.takeException(), isNull, reason: '높이 $h에서 넘침이 있다');
    }
    for (final h in fromBottom.keys) {
      expect(fromBottom[h]![0], closeTo(fromBottom[132.0]![0], 0.01), reason: '높이 $h: 줄 끝 선택이 맨 아래에서 떨어졌다');
      expect(fromBottom[h]![1], closeTo(fromBottom[132.0]![1], 0.01), reason: '높이 $h: 전송 버튼이 맨 아래에서 떨어졌다');
      expect(sizes[h], sizes[132.0], reason: '높이 $h: 크기가 달라졌다');
    }
  });

  testWidgets('the send button is a compact filled button, not the big round one', (tester) async {
    await pumpSender(tester, height: 200);
    final send = rectOf(tester, sendButton());
    expect(send.height, lessThanOrEqualTo(36));
    expect(send.width, lessThanOrEqualTo(48));
    // 다른 아이콘 버튼과 마찬가지로 둥근 사각형이다 (원이 아니다).
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

  testWidgets('a narrow LineSender does not overflow either', (tester) async {
    await pumpSender(tester, height: 120, width: 320);
    expect(tester.takeException(), isNull);
  });
}
