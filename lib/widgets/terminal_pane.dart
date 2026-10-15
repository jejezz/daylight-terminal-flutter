// portside-flutter의 terminal_view.dart에서 가져와 고침.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm2/ui.dart' as xterm_ui;
import 'package:xterm2/xterm.dart';

import '../settings/terminal_prefs.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import '../utils/app_shortcuts.dart';
import 'file_pane_parts.dart' show PaneDragData;
import 'pass_through_cursor.dart';

/// 렌더링과 키보드(IME 포함) 입력은 xterm2의 [xterm_ui.TerminalView]가 전담한다.
class TerminalPane extends StatefulWidget {
  const TerminalPane({super.key});

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final _controller = xterm_ui.TerminalController();
  final _scroll = ScrollController();
  final _focusNode = FocusNode();
  bool _scrollable = false;

  /// 스크롤바가 있을 때 오른쪽 가장자리의 폭(바깥 여백 + 호버 때 두꺼워진 스크롤바 12px + 여유).
  static const _scrollbarWidth = AppSpacing.sm + 16.0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 끌어놓은 뒤 바로 이어서 칠 수 있게 터미널에 포커스를 돌려준다.
  void _focusTerminal() => _focusNode.requestFocus();

  /// 스크롤 범위가 생기거나 없어졌는지 프레임 뒤에 직접 읽는다.
  void _checkScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final scrollable = _scroll.position.maxScrollExtent > 0;
      if (scrollable != _scrollable) setState(() => _scrollable = scrollable);
    });
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
    final session = context.read<TerminalSession>();
    final terminal = session.terminal;
    final prefs = context.watch<TerminalPrefs>();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 리사이즈 중 잠깐 0이 되면 xterm2가 행/열 계산에서 오류를 내므로 그릴 때만 건너뛴다.
        if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) return const SizedBox.shrink();
        final view = xterm_ui.TerminalView(
          terminal,
          controller: _controller,
          scrollController: _scroll,
          focusNode: _focusNode,
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
        // xterm2는 칸 전체를 I자 커서로 덮어서 스크롤바 위에서도 커서가 안 바뀐다. 스크롤바가 있을 때만
        // 오른쪽 가장자리에 화살표 커서 영역을 겹친다(마우스 이벤트는 통과해서 스크롤바를 끌 수 있다).
        final scheme = Theme.of(context).colorScheme;
        // 탐색기 행을 끌어다 놓으면 인용한 경로를 프롬프트에 입력한다 (Enter는 누르지 않는다).
        return DragTarget<PaneDragData>(
          onWillAcceptWithDetails: (d) => d.data.terminalPaths != null,
          onAcceptWithDetails: (d) {
            session.typePaths(d.data.terminalPaths!());
            _focusTerminal();
          },
          builder: (context, candidates, _) => NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _checkScrollable();
              return false;
            },
            child: Stack(
              children: [
                Positioned.fill(child: view),
                if (_scrollable)
                  const Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: _scrollbarWidth,
                    child: PassThroughCursorRegion(cursor: SystemMouseCursors.basic),
                  ),
                if (candidates.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.primary, width: 2),
                          color: scheme.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
