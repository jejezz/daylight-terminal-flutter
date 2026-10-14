import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';

/// 폴더 뷰 위쪽 줄: 위로, 현재 경로, 새로 고침, 새 폴더, (있으면) 경로 이동 메뉴와 추가 버튼.
/// 경로 이동 메뉴 항목은 콜백을 주지 않으면 숨긴다 — 예: 현재 경로를 알려 줄 수 없는 셸.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.path,
    required this.canGoUp,
    required this.onUp,
    required this.onRefresh,
    required this.onNewFolder,
    this.onTerminalToHere,
    this.onExplorerToTerminal,
    this.extraActions = const [],
  });

  final String path;
  final bool canGoUp;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onNewFolder;
  final VoidCallback? onTerminalToHere;
  final VoidCallback? onExplorerToTerminal;
  final List<Widget> extraActions;

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.pathCopied(path)), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.sftpUp,
            icon: const Icon(Icons.arrow_upward_rounded),
            onPressed: canGoUp ? onUp : null,
          ),
          ...extraActions,
          Expanded(
            // 누르면 전체 경로를 클립보드에 복사한다.
            child: Tooltip(
              message: '$path\n${l10n.pathCopyHint}',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.button),
                onTap: () => _copyPath(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                  child: Text(
                    path,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl, // 길면 앞이 아니라 뒤(현재 폴더)가 보이게
                    style: AppFonts.mono.copyWith(fontSize: 12, color: scheme.onSurface),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.sftpRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRefresh,
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.sftpNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onNewFolder,
          ),
          if (onTerminalToHere != null || onExplorerToTerminal != null)
            PopupMenuButton<String>(
              tooltip: l10n.pathMenuTooltip,
              iconSize: 18,
              icon: const Icon(Icons.sync_alt_rounded),
              onSelected: (v) {
                if (v == 'terminal') onTerminalToHere?.call();
                if (v == 'explorer') onExplorerToTerminal?.call();
              },
              itemBuilder: (context) => [
                if (onTerminalToHere != null)
                  PopupMenuItem(value: 'terminal', child: Text(l10n.pathMenuTerminalToHere)),
                if (onExplorerToTerminal != null)
                  PopupMenuItem(value: 'explorer', child: Text(l10n.pathMenuExplorerToTerminal)),
              ],
            ),
        ],
      ),
    );
  }
}

/// 폴더 안의 항목 한 줄. 눌러서 선택하고, 두 번 눌러서 열고, 오른쪽 클릭으로 메뉴, 끌어서 창 밖으로 내보낸다.
class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.dragCount,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final FileItem entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final void Function(Offset globalPosition) onMenu;
  final int Function() dragCount;
  final VoidCallback onDragStarted;
  final void Function(DragUpdateDetails details) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final content = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: selected ? scheme.primary.withValues(alpha: 0.14) : null,
      child: Row(
        children: [
          Icon(
            entry.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
            size: 18,
            color: entry.isDirectory ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.userContent.copyWith(fontSize: 13, color: scheme.onSurface),
            ),
          ),
          if (!entry.isDirectory && entry.size != null) Text(formatFileSize(entry.size!), style: small),
        ],
      ),
    );
    return GestureDetector(
      onSecondaryTapDown: (d) => onMenu(d.globalPosition),
      child: Draggable<List<FileItem>>(
        maxSimultaneousDrags: 1,
        feedback: Builder(
          builder: (context) {
            final n = dragCount();
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppRadius.button),
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Text(n == 1 ? entry.name : l10n.sftpDragCount(n), style: const TextStyle(fontSize: 13)),
              ),
            );
          },
        ),
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDragEnd: (_) => onDragEnd(),
        child: InkWell(splashFactory: NoSplash.splashFactory, onTap: onTap, onDoubleTap: onOpen, child: content),
      ),
    );
  }
}

String formatFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return i == 0 ? '$bytes B' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[i]}';
}
