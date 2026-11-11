import 'package:daylight_terminal/widgets/pane_divider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 왼쪽 칸 + 구분선 + 남은 자리. 구분선을 끌면 왼쪽 칸의 폭이 정해진다 (홈 화면과 같은 방식).
class _Host extends StatefulWidget {
  const _Host({this.min = 100, this.max = 500});

  final double min;
  final double max;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double width = 200;
  double base = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          SizedBox(key: const ValueKey('left'), width: width),
          PaneDivider(
            axis: Axis.vertical,
            color: Colors.grey,
            onDragStart: () => base = width,
            onDrag: (d) => setState(() => width = (base + d).clamp(widget.min, widget.max)),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

void main() {
  Finder divider() => find.byType(PaneDivider);

  testWidgets('the boundary stays exactly under the mouse however the pointer moves', (tester) async {
    await tester.pumpWidget(const _Host());
    // 구분선의 가운데(왼쪽 칸 폭 200 + 3)를 잡고 끈다.
    final start = tester.getCenter(divider());
    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    // 화면이 다시 그려지기 전에 이벤트가 여러 번 와도 (pump 없이) 움직인 양이 빠지지 않아야 한다.
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('left'))).width, 290);
    expect(tester.getCenter(divider()).dx, start.dx + 90);
    await gesture.up();
  });

  testWidgets('going past the limit and coming back does not leave the boundary behind the mouse', (tester) async {
    await tester.pumpWidget(const _Host(max: 300));
    final start = tester.getCenter(divider());
    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(300, 0)); // 한계(300)를 한참 넘는다
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('left'))).width, 300);
    await gesture.moveBy(const Offset(-250, 0)); // 마우스는 누른 자리 +50
    await tester.pump();
    // 누적 거리로 정하므로 마우스가 한계 안으로 돌아오는 순간부터 다시 마우스 아래에 있다.
    expect(tester.getSize(find.byKey(const ValueKey('left'))).width, 250);
    expect(tester.getCenter(divider()).dx, start.dx + 50);
    await gesture.up();
  });

  testWidgets('a second drag starts from the size the pane has then', (tester) async {
    await tester.pumpWidget(const _Host());
    var gesture = await tester.startGesture(tester.getCenter(divider()), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pump();
    gesture = await tester.startGesture(tester.getCenter(divider()), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('left'))).width, 220);
    await gesture.up();
  });
}
