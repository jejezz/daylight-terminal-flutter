import 'package:flutter/material.dart';

/// 드래그로 영역 크기를 조절하는 구분선.
///
/// [onDragStart]에서 지금 크기를 기억해 두고, [onDrag]는 **누른 자리에서 얼마나 움직였는지**(누적 거리)를 받는다.
/// 이벤트마다 움직인 양(delta)을 더하면, 화면이 다시 그려지기 전에 이벤트가 여러 번 오거나 최소·최대 크기에 걸렸다
/// 풀릴 때 구분선이 마우스를 못 따라가는 차이가 생긴다. 누적 거리로 정하면 마우스 아래에 늘 구분선이 있다.
class PaneDivider extends StatefulWidget {
  const PaneDivider({
    super.key,
    required this.axis,
    required this.color,
    required this.onDragStart,
    required this.onDrag,
  });

  final Axis axis;
  final Color color;

  /// 끌기를 시작할 때 (마우스를 누른 순간) 불린다. 지금 크기를 기억해 둔다.
  final VoidCallback onDragStart;

  /// 누른 자리에서 움직인 거리 (가로 구분선이면 세로 거리, 세로 구분선이면 가로 거리).
  final void Function(double total) onDrag;

  @override
  State<PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<PaneDivider> {
  double _downAt = 0;

  @override
  Widget build(BuildContext context) {
    final vertical = widget.axis == Axis.vertical;
    return MouseRegion(
      cursor: vertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: vertical
            ? (d) {
                _downAt = d.globalPosition.dx;
                widget.onDragStart();
              }
            : null,
        onHorizontalDragUpdate: vertical ? (d) => widget.onDrag(d.globalPosition.dx - _downAt) : null,
        onVerticalDragDown: vertical
            ? null
            : (d) {
                _downAt = d.globalPosition.dy;
                widget.onDragStart();
              },
        onVerticalDragUpdate: vertical ? null : (d) => widget.onDrag(d.globalPosition.dy - _downAt),
        child: Container(
          width: vertical ? 6 : null,
          height: vertical ? null : 6,
          alignment: Alignment.center,
          child: Container(
            width: vertical ? 1 : null,
            height: vertical ? null : 1,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
