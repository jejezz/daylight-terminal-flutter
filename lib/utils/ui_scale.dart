import 'package:flutter/widgets.dart';

extension UiScale on BuildContext {
  /// 글자 배율(설정의 "화면 글자 크기")에 맞춰 키운 길이. 글자가 들어가는 고정 높이(탭, 목록 줄, 상태 줄)에 쓴다.
  double scaled(double logical) => MediaQuery.textScalerOf(this).scale(logical);
}
