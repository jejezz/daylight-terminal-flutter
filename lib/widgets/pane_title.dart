import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/phosphor_icons.dart';

/// 칸마다 정해진 색 (LineSender와 편집기는 자리를 바꿀 수 있어서, 어느 것이 어느 것인지 제목과 색으로 구별한다).
/// 팔레트(주색)와 겹치지 않도록 팔레트와 상관없이 고정이다. 저장하지 않은 변경 등의 경고색(호박색)과도 다르다.
abstract final class PaneColors {
  /// 라인 전송기(LineSender): 청록.
  static Color sender(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);

  /// 편집기: 보라.
  static Color editor(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? const Color(0xFFB39DFF) : const Color(0xFF6D28D9);
}

/// 칸의 제목: 아이콘 + 굵은 이름, 칸의 색으로.
class PaneTitle extends StatelessWidget {
  const PaneTitle({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2),
        ),
      ],
    );
  }
}
