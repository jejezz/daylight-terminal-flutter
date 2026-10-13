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
  Finder more() => find.byIcon(Icons.more_horiz_rounded);

  /// LineSender 왼쪽 위 모서리를 기준으로 한 위치 — 영역이 아래쪽에 붙어 있어서 높이가 달라지면 화면 좌표는 바뀐다.
  Offset fromTopLeft(WidgetTester tester, Finder f) => tester.getCenter(f) - tester.getTopLeft(find.byType(LineSender));

  testWidgets('the file buttons sit in a title bar above the box, in order: open, save, more', (tester) async {
    await pumpSender(tester, height: 160);
    final field = rectOf(tester, find.byType(TextField));
    for (final b in [open(), save(), more()]) {
      expect(rectOf(tester, b).bottom, lessThanOrEqualTo(field.top + 1), reason: '버튼이 입력 칸 위(제목 줄)에 있어야 한다');
    }
    expect(rectOf(tester, open()).right, lessThanOrEqualTo(rectOf(tester, save()).left + 1));
    expect(rectOf(tester, save()).right, lessThanOrEqualTo(rectOf(tester, more()).left + 1));
  });

  testWidgets('the buttons are right-aligned on the title bar, with the file name on the left', (tester) async {
    await pumpSender(tester, height: 160);
    final sender = tester.getRect(find.byType(LineSender));
    // 버튼 줄의 오른쪽 끝이 LineSender의 오른쪽 안쪽 여백(8)에 닿아 있다.
    // (아이콘이 아니라 버튼 전체 영역으로 잰다: 아이콘 둘레에 눌리는 여백이 있다.)
    expect(rectOf(tester, find.byType(PopupMenuButton<String>)).right, closeTo(sender.right - 8, 1));
    final name = rectOf(tester, find.text('제목 없음'));
    expect(name.left, lessThan(sender.left + 40));
    expect(name.right, lessThan(rectOf(tester, open()).left));
  });

  testWidgets('their position and size do not depend on the height of the LineSender', (tester) async {
    final positions = <double, List<Offset>>{};
    final sizes = <double, List<Size>>{};
    for (final h in [96.0, 120.0, 200.0, 400.0]) {
      await pumpSender(tester, height: h);
      positions[h] = [
        for (final b in [open(), save(), more()]) fromTopLeft(tester, b),
      ];
      sizes[h] = [
        for (final b in [open(), save(), more()]) tester.getSize(b),
      ];
      expect(tester.takeException(), isNull, reason: '높이 $h에서 넘침이 있다');
    }
    final base = positions[96.0]!;
    for (final h in positions.keys) {
      for (var i = 0; i < 3; i++) {
        expect(positions[h]![i].dx, closeTo(base[i].dx, 0.01), reason: '높이 $h, 버튼 $i의 가로 위치');
        expect(positions[h]![i].dy, closeTo(base[i].dy, 0.01), reason: '높이 $h, 버튼 $i의 세로 위치');
        expect(sizes[h]![i], sizes[96.0]![i], reason: '높이 $h, 버튼 $i의 크기');
      }
    }
  });

  testWidgets('at the smallest height the title bar is intact and the box still has room', (tester) async {
    await pumpSender(tester, height: 96);
    expect(tester.takeException(), isNull);
    expect(rectOf(tester, open()).top, greaterThanOrEqualTo(tester.getTopLeft(find.byType(LineSender)).dy));
    expect(rectOf(tester, find.byType(TextField)).height, greaterThanOrEqualTo(40));
  });

  testWidgets('the side column keeps only the line ending and the send button (no file buttons)', (tester) async {
    await pumpSender(tester, height: 200);
    final field = rectOf(tester, find.byType(TextField));
    final send = rectOf(tester, find.byIcon(Icons.send_rounded));
    final ending = rectOf(tester, find.byType(DropdownButton<LineEnding>));
    expect(send.left, greaterThan(field.right - 1));
    expect(ending.left, greaterThan(field.right - 1));
    // 파일 버튼은 제목 줄에 있어서 옆 열의 위쪽(입력 칸 위)에 놓인다 — 옆 열 안에 끼어 있지 않다.
    for (final b in [open(), save(), more()]) {
      expect(rectOf(tester, b).bottom, lessThanOrEqualTo(field.top + 1));
      expect(rectOf(tester, b).bottom, lessThanOrEqualTo(ending.top + 1), reason: '줄 끝 선택 위쪽이어야 한다');
    }
  });

  testWidgets('a narrow LineSender does not overflow either', (tester) async {
    await pumpSender(tester, height: 120, width: 320);
    expect(tester.takeException(), isNull);
  });
}
