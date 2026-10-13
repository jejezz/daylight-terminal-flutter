import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 마우스 커서 모양만 정하고, 마우스·터치 이벤트는 그 아래 위젯으로 그대로 통과시키는 영역.
///
/// [MouseRegion]은 항상 이벤트를 받는 대상이 되어서(자식이 없어도) 아래에 있는 위젯이 이벤트를 못 받는다.
/// 그래서 TextField 안의 스크롤바 위에 [MouseRegion]을 겹치면 커서는 바뀌지만 스크롤바를 끌 수 없게 된다.
/// 이 영역은 커서 정보만 마우스 추적기에 올리고 이벤트 대상으로는 잡히지 않는다.
///
/// 커서는 가장 위에 있는 영역의 것이 이긴다 — 위에 겹쳐 두면 아래 위젯(예: TextField의 텍스트 커서)을 덮어쓴다.
class PassThroughCursorRegion extends LeafRenderObjectWidget {
  const PassThroughCursorRegion({super.key, required this.cursor});

  final MouseCursor cursor;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPassThroughCursor(cursor);

  @override
  void updateRenderObject(BuildContext context, covariant RenderPassThroughCursor renderObject) {
    renderObject.cursor = cursor;
  }
}

class RenderPassThroughCursor extends RenderMouseRegion {
  RenderPassThroughCursor(MouseCursor cursor) : super(cursor: cursor, opaque: false);

  /// 마우스 추적기에는 올리되(`result.add`), 이벤트 대상은 아니라고 답한다(`false`) — 아래 형제도 계속 검사된다.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) result.add(BoxHitTestEntry(this, position));
    return false;
  }
}
