import 'dart:async';

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

/// 탭 높이: 첫 줄(폴더 이름)과 둘째 줄(실행 중인 명령 / 셸 이름).
const double _tabHeight = 48;

/// 아직 이름이 없는 탭은 종류를 알려 준다. 처음 여는 탭(SSH·시리얼·셸 중 고르는 화면)은 그냥 "새 연결".
String _fallbackTitle(TerminalSession session, AppLocalizations l10n) => session.tabTitle.isNotEmpty
    ? session.tabTitle
    : switch (session) {
        SerialSession() => l10n.tabNewSerial,
        SshSessionProvider(showAllOptions: false) => l10n.tabNewSsh,
        _ => l10n.tabNew,
      };

/// 세션 탭 줄. 탭마다 SSH 연결 하나(터미널 + 탐색기).
class TabBarRow extends StatelessWidget {
  const TabBarRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SessionsController>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: _tabHeight,
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
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.sessions.length,
                  itemBuilder: (context, i) => _Tab(
                    key: ObjectKey(controller.sessions[i]),
                    index: i,
                    session: controller.sessions[i],
                    label: labels[i],
                    selected: i == controller.selected,
                    onSelect: () => controller.select(i),
                    onClose: () => controller.closeAt(i),
                    onMove: controller.move,
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
        return HelpTarget(
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
                          builder: (context, _) => _body(
                            context,
                            scheme,
                            l10n,
                            dragging: true,
                          ),
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
    final tab = InkWell(
      splashFactory: NoSplash.splashFactory,
      onTap: onSelect,
      child: Container(
        height: _tabHeight,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.xs,
        ),
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
            Icon(
              switch (session) {
                LocalShellSession() => Icons.terminal_rounded,
                SerialSession() => Icons.usb_rounded,
                _ => Icons.dns_outlined,
              },
              size: 13,
            ),
            const SizedBox(width: AppSpacing.xs),
            _StatusMark(
              running: label.running,
              color: switch (session.status) {
                // 마지막 명령이 실패로 끝났으면 다음 명령이 시작될 때까지 빨간 점.
                SessionStatus.connected when (label.exitCode ?? 0) != 0 => AppColors.danger,
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
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
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
                        fontWeight: label.running ? FontWeight.w600 : FontWeight.w400,
                        color: label.running ? scheme.primary : scheme.onSurfaceVariant,
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
      ),
    );
    final tip = label.tooltip;
    if (dragging || tip == null || tip.isEmpty) return tab;
    return Tooltip(message: tip, waitDuration: const Duration(milliseconds: 600), child: tab);
  }
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
          ? CircularProgressIndicator(strokeWidth: 1.6, color: Theme.of(context).colorScheme.primary)
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
