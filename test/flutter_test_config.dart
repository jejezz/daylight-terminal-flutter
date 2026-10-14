import 'dart:async';

import 'package:daylight_terminal/state/terminal_session.dart';

/// 모든 테스트: 탐색기 자동 새로 고침 타이머를 끈다 (`test/auto_refresh_test.dart`만 켠다).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TerminalSession.autoRefreshEnabled = false;
  await testMain();
}
