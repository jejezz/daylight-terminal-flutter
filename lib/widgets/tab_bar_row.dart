import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/sessions_controller.dart';
import '../state/ssh_session_provider.dart';
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
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: '${l10n.tabNew} (${AppShortcut.newTab.label})',
            icon: const Icon(Icons.add_rounded),
            onPressed: controller.add,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.session, required this.selected, required this.onSelect, required this.onClose});

  final SshSessionProvider session;
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
