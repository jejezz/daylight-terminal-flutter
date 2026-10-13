import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/local_shell.dart';
import '../state/local_shell_session.dart';
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
                session: controller.sessions[i],
                selected: i == controller.selected,
                onSelect: () => controller.select(i),
                onClose: () => controller.closeAt(i),
              ),
            ),
          ),
          PopupMenuButton<Object>(
            iconSize: 18,
            tooltip: l10n.tabNew,
            icon: const Icon(Icons.add_rounded),
            onSelected: (choice) => choice is LocalShell ? controller.addLocal(choice) : controller.add(),
            itemBuilder: (context) => [
              PopupMenuItem<Object>(
                value: 'ssh',
                child: _MenuRow(Icons.dns_outlined, l10n.newTabSsh, AppShortcut.newTab.label),
              ),
              const PopupMenuDivider(),
              if (controller.shells.isEmpty)
                PopupMenuItem<Object>(enabled: false, child: Text(l10n.newTabNoShells))
              else
                for (final (i, shell) in controller.shells.indexed)
                  PopupMenuItem<Object>(
                    value: shell,
                    // 첫 번째가 기본 셸이고, 단축키는 그 셸을 연다.
                    child: _MenuRow(Icons.terminal_rounded, shell.name, i == 0 ? AppShortcut.newLocalTab.label : null),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.session, required this.selected, required this.onSelect, required this.onClose});

  final TerminalSession session;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final title = session.tabTitle.isEmpty ? l10n.tabNew : session.tabTitle;
        return InkWell(
          splashFactory: NoSplash.splashFactory,
          onTap: onSelect,
          child: Container(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
            padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : null,
              border: Border(
                bottom: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
                right: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(session is LocalShellSession ? Icons.terminal_rounded : Icons.dns_outlined, size: 13),
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
                ),
              ],
            ),
          ),
        );
      },
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
