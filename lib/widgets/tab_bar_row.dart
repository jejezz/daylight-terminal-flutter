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

/// 세션 탭 줄. 탭마다 SSH 연결 하나(터미널 + 탐색기).
class TabBarRow extends StatelessWidget {
  const TabBarRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SessionsController>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.sessions.length,
              itemBuilder: (context, i) => _Tab(
                key: ObjectKey(controller.sessions[i]),
                index: i,
                session: controller.sessions[i],
                selected: i == controller.selected,
                onSelect: () => controller.select(i),
                onClose: () => controller.closeAt(i),
                onMove: controller.move,
              ),
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
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
  });

  final int index;
  final TerminalSession session;
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
        // 아직 이름이 없는 탭은 종류를 알려 준다. 처음 여는 탭(SSH·시리얼·셸 중 고르는 화면)은 그냥 "새 연결".
        final title = session.tabTitle.isNotEmpty
            ? session.tabTitle
            : switch (session) {
                SerialSession() => l10n.tabNewSerial,
                SshSessionProvider(showAllOptions: false) => l10n.tabNewSsh,
                _ => l10n.tabNew,
              };
        final body = _body(context, title, scheme, l10n);
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
                            title,
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
    String title,
    ColorScheme scheme,
    AppLocalizations l10n, {
    bool dragging = false,
  }) {
    return InkWell(
      splashFactory: NoSplash.splashFactory,
      onTap: onSelect,
      child: Container(
        height: 36,
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
            Icon(
              Icons.circle,
              size: 8,
              color: switch (session.status) {
                SessionStatus.connected => AppColors.success,
                SessionStatus.connecting => AppColors.warning,
                SessionStatus.error => AppColors.danger,
                SessionStatus.idle => scheme.outline,
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
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
