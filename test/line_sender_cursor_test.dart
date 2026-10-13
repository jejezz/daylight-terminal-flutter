import 'dart:io';
import 'dart:ui';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_pty.dart';

/// flutter_test의 마우스 장치 번호.
const _mouseDevice = 1;

/// 실제 스크롤바 손잡이 위치: 입력 칸 오른쪽 끝에서 안쪽으로 약 21px (측정값 18~24px의 가운데).
const _thumbDx = 21.0;

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);

void main() {
  late LocalShellSession session;

  setUp(() {
    session = LocalShellSession(_bash, ptyFactory: FakePtyFactory().call, startDirectory: Directory.systemTemp.path);
  });

  tearDown(() => session.dispose());

  Future<void> pumpSender(WidgetTester tester, {double height = 120}) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ChangeNotifierProvider<TerminalSession>.value(
        value: session,
        child: MaterialApp(
          // 데스크톱용 스크롤바는 데스크톱 플랫폼에서만 그려진다 (테스트 기본값은 Android).
          theme: AppTheme.dark().copyWith(platform: TargetPlatform.windows),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(height: height, child: LineSender()),
            ),
          ),
        ),
      ),
    );
  }

  /// 글을 넣고 스크롤바가 자리 잡을 때까지 기다린다 (스크롤 크기 알림은 프레임이 끝난 뒤에 오고, 손잡이는 서서히 나타난다).
  Future<void> fill(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(1, 1));
    addTearDown(gesture.removePointer);
    return gesture;
  }

  MouseCursor cursorAt(WidgetTester tester, TestGesture gesture) {
    final cursor = RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);
    expect(cursor, isNotNull);
    return cursor!;
  }

  Rect fieldRect(WidgetTester tester) => tester.getRect(find.byType(TextField));

  testWidgets(
    'with a scrollbar, the right edge of the box shows the normal arrow; the text area keeps the text cursor',
    (tester) async {
      await pumpSender(tester);
      await fill(tester, List.generate(40, (i) => 'line ${i + 1}').join('\n'));

      final box = fieldRect(tester);
      final gesture = await mouse(tester);

      await gesture.moveTo(Offset(box.center.dx, box.center.dy));
      await tester.pump();
      expect(cursorAt(tester, gesture), SystemMouseCursors.text);

      await gesture.moveTo(Offset(box.right - 4, box.center.dy)); // 스크롤바가 있는 오른쪽 가장자리
      await tester.pump();
      expect(cursorAt(tester, gesture), SystemMouseCursors.basic);

      await gesture.moveTo(Offset(box.right - 40, box.center.dy)); // 가장자리를 벗어나면 다시 텍스트 커서
      await tester.pump();
      expect(cursorAt(tester, gesture), SystemMouseCursors.text);
    },
  );

  testWidgets('the arrow region does not block the scrollbar: dragging it still scrolls the text', (tester) async {
    await pumpSender(tester);
    await fill(tester, List.generate(60, (i) => 'line ${i + 1}').join('\n'));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(TextField), matching: find.byType(Scrollable)).first,
    );
    // 스크롤바 손잡이는 스크롤이 일어나거나 마우스가 올라가면 나타난다. 한 번 스크롤해서 보이게 한 뒤 맨 위로 돌려 놓고 시작한다.
    scrollable.position.jumpTo(40);
    await tester.pump();
    scrollable.position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));
    final before = scrollable.position.pixels;

    final box = fieldRect(tester);
    final gesture = await mouse(tester);
    final thumb = Offset(box.right - _thumbDx, box.top + 12);
    await gesture.moveTo(thumb);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.down(thumb);
    await gesture.moveBy(const Offset(0, 40));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(scrollable.position.pixels, greaterThan(before), reason: '스크롤바를 끌었는데 스크롤되지 않았다');
  });

  testWidgets('without a scrollbar (short text) the whole box keeps the text cursor', (tester) async {
    await pumpSender(tester);
    await fill(tester, 'just one line');

    final box = fieldRect(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(Offset(box.right - _thumbDx, box.top + 12));
    await tester.pump();
    expect(cursorAt(tester, gesture), SystemMouseCursors.text);
  });

  testWidgets('when the text shrinks back and the scrollbar goes away, the arrow region goes too', (tester) async {
    await pumpSender(tester);
    await fill(tester, List.generate(40, (i) => 'line $i').join('\n'));
    final box = fieldRect(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(Offset(box.right - _thumbDx, box.top + 12));
    await tester.pump();
    expect(cursorAt(tester, gesture), SystemMouseCursors.basic);

    await fill(tester, 'short');
    await gesture.moveTo(Offset(box.right - _thumbDx - 1, box.top + 12));
    await tester.pump();
    expect(cursorAt(tester, gesture), SystemMouseCursors.text);
  });

  testWidgets('making the box taller (dragging the divider) removes the scrollbar and its arrow region', (
    tester,
  ) async {
    await pumpSender(tester);
    await fill(tester, List.generate(14, (i) => 'line $i').join('\n'));
    var box = fieldRect(tester);
    final gesture = await mouse(tester);
    await gesture.moveTo(Offset(box.right - _thumbDx, box.top + 12));
    await tester.pump();
    expect(cursorAt(tester, gesture), SystemMouseCursors.basic);

    await pumpSender(tester, height: 450); // 14줄이 다 들어가는 높이 (120일 때는 안 들어간다)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    box = fieldRect(tester);
    await gesture.moveTo(Offset(box.right - _thumbDx - 1, box.top + 12));
    await tester.pump();
    expect(cursorAt(tester, gesture), SystemMouseCursors.text);
  });
}
