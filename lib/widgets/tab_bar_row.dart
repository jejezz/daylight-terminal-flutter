import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../help/help_mode.dart';
import '../l10n/app_localizations.dart';
import '../models/local_shell.dart';
import '../state/local_shell_session.dart';
import '../state/serial_session.dart';
import '../state/ssh_session_provider.dart';
import '../state/sessions_controller.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import '../utils/app_shortcuts.dart';
import '../utils/tab_label.dart';
import '../utils/ui_scale.dart';

/// 탭 높이: 첫 줄(폴더 이름)과 둘째 줄(실행 중인 명령 / 셸 이름).
const double _tabBaseHeight = 48;

/// 아직 이름이 없는 탭은 종류를 알려 준다. 처음 여는 탭(SSH·시리얼·셸 중 고르는 화면)은 그냥 "새 연결".
String _fallbackTitle(TerminalSession session, AppLocalizations l10n) =>
    session.tabTitle.isNotEmpty
    ? session.tabTitle
    : switch (session) {
        SerialSession() => l10n.tabNewSerial,
        SshSessionProvider(showAllOptions: false) => l10n.tabNewSsh,
        _ => l10n.tabNew,
      };

/// 세션 탭 줄. 탭마다 SSH 연결 하나(터미널 + 탐색기).
class TabBarRow extends StatefulWidget {
  const TabBarRow({super.key});

  @override
  State<TabBarRow> createState() => _TabBarRowState();
}

class _TabBarRowState extends State<TabBarRow> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 마우스 휠(세로)로 탭 줄을 가로로 민다. 탭이 화면보다 많아도 오른쪽 탭에 갈 수 있게.
  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    final position = _scroll.position;
    _scroll.jumpTo(
      (_scroll.offset + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SessionsController>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: context.scaled(_tabBaseHeight),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            // 폴더 이름이 겹치는 탭을 구분하려면 모든 탭의 상태를 함께 봐야 한다.
            child: ListenableBuilder(
              listenable: Listenable.merge(controller.sessions),
              builder: (context, _) {
                final labels = TabLabels.compute(
                  controller.sessions,
                  fallbackTitle: (s) => _fallbackTitle(s, l10n),
                );
                // 탭 수는 많지 않으므로 모두 만들어 둔다 (선택한 탭을 보이는 곳으로 가져오려면 만들어져 있어야 한다).
                return Listener(
                  onPointerSignal: _onWheel,
                  child: Scrollbar(
                    controller: _scroll,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    thickness: 3,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (i, session)
                              in controller.sessions.indexed)
                            _Tab(
                              key: ObjectKey(session),
                              index: i,
                              session: session,
                              label: labels[i],
                              selected: i == controller.selected,
                              onSelect: () => controller.select(i),
                              onClose: () => controller.closeAt(i),
                              onMove: controller.move,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          HelpTarget(
            id: HelpId.tabNew,
            child: PopupMenuButton<Object>(
              iconSize: 18,
              tooltip: l10n.tabNew,
              icon: const Icon(Icons.add_rounded),
              onSelected: (choice) => switch (choice) {
                LocalShell() => controller.addLocal(choice),
                'serial' => controller.addSerial(),
                _ => controller.add(),
              },
              itemBuilder: (context) => [
                PopupMenuItem<Object>(
                  value: 'ssh',
                  child: _MenuRow(
                    Icons.dns_outlined,
                    l10n.newTabSsh,
                    AppShortcut.newTab.label,
                  ),
                ),
                PopupMenuItem<Object>(
                  value: 'serial',
                  child: _MenuRow(Icons.usb_rounded, l10n.newTabSerial, null),
                ),
                const PopupMenuDivider(),
                if (controller.shells.isEmpty)
                  PopupMenuItem<Object>(
                    enabled: false,
                    child: Text(l10n.newTabNoShells),
                  )
                else
                  for (final (i, shell) in controller.shells.indexed)
                    PopupMenuItem<Object>(
                      value: shell,
                      // 첫 번째가 기본 셸이고, 단축키는 그 셸을 연다.
                      child: _MenuRow(
                        Icons.terminal_rounded,
                        shell.name,
                        i == 0 ? AppShortcut.newLocalTab.label : null,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.index,
    required this.session,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
  });

  final int index;
  final TerminalSession session;
  final TabLabel label;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  /// (옮기는 탭의 자리, 놓은 자리)
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final body = _body(context, scheme, l10n);
        return _EnsureVisible(
          active: selected,
          child: HelpTarget(
            id: HelpId.tabItem,
            child: DragTarget<int>(
              onWillAcceptWithDetails: (d) => d.data != index,
              onAcceptWithDetails: (d) => onMove(d.data, index),
              builder: (context, candidates, _) {
                final from = candidates.isEmpty ? null : candidates.first;
                // 놓을 자리 표시: 오른쪽으로 끌면 이 탭의 오른쪽, 왼쪽으로 끌면 왼쪽에 들어간다.
                final bar = Container(width: 3, color: scheme.primary);
                return Stack(
                  children: [
                    Draggable<int>(
                      data: index,
                      axis: Axis.horizontal,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Opacity(
                          opacity: 0.85,
                          child: ListenableBuilder(
                            listenable: session,
                            builder: (context, _) =>
                                _body(context, scheme, l10n, dragging: true),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.35, child: body),
                      child: body,
                    ),
                    if (from != null)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: from > index ? 0 : null,
                        right: from > index ? null : 0,
                        child: IgnorePointer(child: bar),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n, {
    bool dragging = false,
  }) {
    final content = Container(
      height: context.scaled(_tabBaseHeight),
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: selected || dragging ? scheme.surface : null,
        border: Border(
          bottom: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
          right: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아이콘 색이 탭마다 다르다 (옆 탭과 구분). 고른 탭이라고 색을 바꾸지 않는다 — 아래 밑줄이 알려 준다.
          Icon(
            switch (session) {
              LocalShellSession() => Icons.terminal_rounded,
              SerialSession() => Icons.usb_rounded,
              _ => Icons.dns_outlined,
            },
            size: 16,
            color: TabLabels.colorFor(
              label.colorIndex,
              Theme.of(context).brightness,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatusMark(
            running: label.running,
            color: switch (session.status) {
              // 마지막 명령이 실패로 끝났으면 다음 명령이 시작될 때까지 빨간 점.
              SessionStatus.connected when (label.exitCode ?? 0) != 0 =>
                AppColors.danger,
              SessionStatus.connected => AppColors.success,
              SessionStatus.connecting => AppColors.warning,
              SessionStatus.error => AppColors.danger,
              SessionStatus.idle => scheme.outline,
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      // 셸 이름이 앞, 폴더 이름이 뒤. 좁으면 폴더 쪽이 먼저 잘린다.
                      if (label.shell != null)
                        TextSpan(
                          text: '${label.shell}  ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: scheme.primary,
                          ),
                        ),
                      TextSpan(
                        text: label.primary,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (label.secondary != null)
                  Text(
                    label.secondary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: label.running
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: label.running
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            iconSize: 14,
            visualDensity: VisualDensity.compact,
            tooltip: '${l10n.tabClose} (${AppShortcut.closeTab.label})',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ).help(HelpId.tabClose),
        ],
      ),
    );
    final tab = InkWell(
      splashFactory: NoSplash.splashFactory,
      onTap: onSelect,
      child: content,
    );
    final tip = label.tooltip;
    if (dragging || tip == null || tip.isEmpty) return tab;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 600),
      child: tab,
    );
  }
}

/// [active]가 되면(탭을 고르거나 새 탭이 열리면) 이 위젯을 가로 스크롤 안에서 보이는 곳으로 가져온다.
class _EnsureVisible extends StatefulWidget {
  const _EnsureVisible({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_EnsureVisible> createState() => _EnsureVisibleState();
}

class _EnsureVisibleState extends State<_EnsureVisible> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule();
  }

  @override
  void didUpdateWidget(_EnsureVisible old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 탭 앞의 상태 표시: 명령이 실행 중이면 (조금 기다린 뒤) 돌아가는 표시, 아니면 연결 상태 점.
/// 금방 끝나는 명령(`ls` 등)에는 깜빡이지 않게 [delay] 뒤에야 보인다.
class _StatusMark extends StatefulWidget {
  const _StatusMark({required this.running, required this.color});

  final bool running;
  final Color color;

  @visibleForTesting
  static Duration delay = const Duration(milliseconds: 500);

  @override
  State<_StatusMark> createState() => _StatusMarkState();
}

class _StatusMarkState extends State<_StatusMark> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_StatusMark old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.running) {
      _show = false;
    } else if (!_show) {
      _timer = Timer(_StatusMark.delay, () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: widget.running && _show
          ? CircularProgressIndicator(
              strokeWidth: 1.6,
              color: Theme.of(context).colorScheme.primary,
            )
          : Icon(Icons.circle, size: 8, color: widget.color),
    );
  }
}

/// 새 탭 메뉴의 한 줄: 아이콘, 이름, (있으면) 단축키.
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, this.shortcut);

  final IconData icon;
  final String label;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        if (shortcut != null) ...[
          const SizedBox(width: AppSpacing.lg),
          Text(shortcut!, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ],
    );
  }
}
