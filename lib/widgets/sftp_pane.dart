import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/remote_entry.dart';
import '../models/transfer.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';

/// SFTP 파일 탐색기. 로컬 파일/폴더를 끌어다 놓으면 현재 폴더로 업로드한다.
/// 터미널 경로와는 자동으로 연동하지 않고, 상단 "경로 이동" 메뉴로만 맞춘다.
class SftpPane extends StatefulWidget {
  const SftpPane({super.key});

  @override
  State<SftpPane> createState() => _SftpPaneState();
}

class _SftpPaneState extends State<SftpPane> {
  bool _dragging = false;
  String? _selected;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _toast('$e');
    }
  }

  Future<bool> _confirmOverwrite(List<String> names) async {
    if (names.isEmpty) return true;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sftpOverwriteTitle),
        content: Text(l10n.sftpOverwriteBody(names.join(', '))),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sftpOverwrite),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _askText(String title, String label, {String initial = ''}) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(l10n.commonOk)),
        ],
      ),
    );
  }

  Future<void> _onDrop(List<String> paths) async {
    final session = context.read<SshSessionProvider>();
    if (paths.isEmpty || !session.connected) return;
    if (!await _confirmOverwrite(session.uploadConflicts(paths))) return;
    await _guard(() => session.upload(paths));
  }

  Future<void> _download(RemoteEntry e) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    if (e.isDirectory) {
      final dir = await getDirectoryPath(confirmButtonText: l10n.sftpDownloadConfirm);
      if (dir == null) return;
      if (!await _confirmOverwrite(session.downloadConflicts([e], dir))) return;
      await _guard(() => session.download([e], dir));
    } else {
      // 저장 대화상자가 덮어쓰기 확인을 한다.
      final location = await getSaveLocation(suggestedName: e.name, confirmButtonText: l10n.sftpDownload);
      if (location == null) return;
      await _guard(() => session.downloadFileTo(e, location.path));
    }
  }

  Future<void> _delete(RemoteEntry e) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sftpDelete),
        content: Text(l10n.sftpDeleteConfirm(e.name)),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sftpDelete),
          ),
        ],
      ),
    );
    if (ok == true) await _guard(() => session.delete(e));
  }

  Future<void> _rename(RemoteEntry e) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    final name = await _askText(l10n.sftpRename, l10n.sftpNewName, initial: e.name);
    if (name == null || name.isEmpty || name == e.name) return;
    await _guard(() => session.rename(e, name));
  }

  Future<void> _newFolder() async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    final name = await _askText(l10n.sftpNewFolder, l10n.sftpFolderName);
    if (name == null || name.isEmpty) return;
    await _guard(() => session.makeDirectory(name));
  }

  Future<void> _syncExplorer() async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    if (!await session.syncExplorerToTerminal()) _toast(l10n.pathCwdFailed);
  }

  Future<void> _rowMenu(RemoteEntry e, Offset position) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    setState(() => _selected = e.name);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'download', child: Text(l10n.sftpDownload)),
        if (e.isDirectory) PopupMenuItem(value: 'terminal', child: Text(l10n.pathMenuTerminalToHere)),
        PopupMenuItem(value: 'rename', child: Text(l10n.sftpRename)),
        PopupMenuItem(value: 'delete', child: Text(l10n.sftpDelete)),
      ],
    );
    switch (choice) {
      case 'download':
        await _download(e);
      case 'terminal':
        session.moveTerminalTo(session.pathOf(e));
      case 'rename':
        await _rename(e);
      case 'delete':
        await _delete(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SshSessionProvider>();
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale).add_Hm();

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _onDrop([for (final f in details.files) f.path]);
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onNewFolder: _newFolder, onSyncExplorer: _syncExplorer),
              Expanded(
                child: session.sftpError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: SelectableText(
                            l10n.sftpError(session.sftpError!),
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      )
                    : session.entries.isEmpty && !session.sftpLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.sftpEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.sftpDropHint,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: session.entries.length,
                        itemBuilder: (context, i) {
                          final e = session.entries[i];
                          return _Row(
                            entry: e,
                            selected: _selected == e.name,
                            dateFormat: dateFormat,
                            onTap: () => setState(() => _selected = e.name),
                            onOpen: () => e.isDirectory ? session.openEntry(e) : _download(e),
                            onMenu: (pos) => _rowMenu(e, pos),
                          );
                        },
                      ),
              ),
              if (session.transfers.isNotEmpty) _TransferList(session: session),
            ],
          ),
          if (session.sftpLoading)
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.sftpDropActive,
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNewFolder, required this.onSyncExplorer});

  final VoidCallback onNewFolder;
  final VoidCallback onSyncExplorer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SshSessionProvider>();
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
            onPressed: session.remotePath == '/' ? null : session.goUp,
          ),
          Expanded(
            child: Tooltip(
              message: session.remotePath,
              child: Text(
                session.remotePath,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl, // 길면 앞이 아니라 뒤(현재 폴더)가 보이게
                style: AppFonts.mono.copyWith(fontSize: 12, color: scheme.onSurface),
              ),
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.sftpRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: session.refresh,
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.sftpNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onNewFolder,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.pathMenuTooltip,
            iconSize: 18,
            icon: const Icon(Icons.sync_alt_rounded),
            onSelected: (v) {
              if (v == 'terminal') session.moveTerminalTo(session.remotePath);
              if (v == 'explorer') onSyncExplorer();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'terminal', child: Text(l10n.pathMenuTerminalToHere)),
              PopupMenuItem(value: 'explorer', child: Text(l10n.pathMenuExplorerToTerminal)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.selected,
    required this.dateFormat,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
  });

  final RemoteEntry entry;
  final bool selected;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final void Function(Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return GestureDetector(
      onSecondaryTapDown: (d) => onMenu(d.globalPosition),
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
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
              if (!entry.isDirectory && entry.size != null) Text(_formatSize(entry.size!), style: small),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return i == 0 ? '$bytes B' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[i]}';
}

class _TransferList extends StatelessWidget {
  const _TransferList({required this.session});

  final SshSessionProvider session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 132),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: ListView(shrinkWrap: true, children: [for (final t in session.transfers) _TransferTile(t)])),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: session.clearFinishedTransfers,
              child: Text(l10n.transferClear, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile(this.transfer);

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: transfer,
      builder: (context, _) {
        final running = transfer.status == TransferStatus.running;
        final label = switch (transfer.status) {
          TransferStatus.running =>
            transfer.direction == TransferDirection.upload
                ? l10n.transferUploading(transfer.name)
                : l10n.transferDownloading(transfer.name),
          TransferStatus.done => '${transfer.name} · ${l10n.transferDone}',
          TransferStatus.failed => '${transfer.name} · ${l10n.transferFailed(transfer.error ?? '')}',
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    transfer.direction == TransferDirection.upload ? Icons.upload_rounded : Icons.download_rounded,
                    size: 14,
                    color: transfer.status == TransferStatus.failed ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: transfer.status == TransferStatus.failed ? scheme.error : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              if (running) LinearProgressIndicator(value: transfer.progress, minHeight: 3),
            ],
          ),
        );
      },
    );
  }
}
