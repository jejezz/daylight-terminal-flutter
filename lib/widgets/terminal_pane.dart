// portside-flutter의 terminal_view.dart에서 가져와 고침.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm2/ui.dart' as xterm_ui;
import 'package:xterm2/xterm.dart';

import '../settings/terminal_prefs.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_shortcuts.dart';

/// 렌더링과 키보드(IME 포함) 입력은 xterm2의 [xterm_ui.TerminalView]가 전담한다.
class TerminalPane extends StatefulWidget {
  const TerminalPane({super.key});

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final _controller = xterm_ui.TerminalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 오른쪽 클릭: 선택이 있으면 복사, 없으면 붙여넣기.
  Future<void> _onSecondaryTapDown(Terminal terminal) async {
    final selection = _controller.selection;
    if (selection != null) {
      final text = terminal.buffer.getText(selection);
      _controller.clearSelection();
      await Clipboard.setData(ClipboardData(text: text));
    } else {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text;
      if (text != null) terminal.paste(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminal = context.read<SshSessionProvider>().terminal;
    final prefs = context.watch<TerminalPrefs>();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 리사이즈 중 잠깐 0이 되면 xterm2가 행/열 계산에서 오류를 내므로 그릴 때만 건너뛴다.
        if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) return const SizedBox.shrink();
        return xterm_ui.TerminalView(
          terminal,
          controller: _controller,
          autofocus: true,
          theme: xterm_ui.TerminalThemes.defaultTheme,
          textStyle: prefs.style,
          padding: const EdgeInsets.all(AppSpacing.sm),
          // 앱 전역 단축키는 xterm이 제어 문자로 보내버리기 전에 상위 CallbackShortcuts로 넘긴다.
          onKeyEvent: (_, event) => AppShortcut.all.any((s) => s.activator.accepts(event, HardwareKeyboard.instance))
              ? KeyEventResult.skipRemainingHandlers
              : KeyEventResult.ignored,
          onSecondaryTapDown: (details, offset) => _onSecondaryTapDown(terminal),
        );
      },
    );
  }
}
