import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/remote_entry.dart';
import '../models/transfer.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';

/// 진행 중인 끌어내기 한 번의 상태.
class _Drag {
  _Drag(this.items, this.from);

  final List<RemoteEntry> items;

  /// 끌기를 시작할 때의 원격 폴더 (끄는 동안 탐색기가 다른 폴더로 가도 원래 파일을 받는다).
  final String from;

  /// macOS 밖에서 쓰는 임시 로컬 사본 경로. 받는 중에는 아직 끝나지 않은 Future.
  Future<List<String>?>? staged;

  /// OS 끌기 세션으로 넘겼는지.
  bool handedOver = false;
}

/// SFTP 파일 탐색기.
///
/// - 로컬 파일/폴더를 끌어다 놓으면 현재 폴더로 업로드한다.
/// - 항목을 창 밖(Finder/탐색기/바탕화면)으로 끌어내면 내려받는다 (flutter_drag_out).
/// - 터미널 경로와는 자동으로 연동하지 않고, 상단 "경로 이동" 메뉴로만 맞춘다.
class SftpPane extends StatefulWidget {
  const SftpPane({super.key});

  @override
  State<SftpPane> createState() => _SftpPaneState();
}

class _SftpPaneState extends State<SftpPane> {
  bool _dragging = false;
  final Set<String> _selected = {};
  int? _anchor;
  _Drag? _drag;

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

  // ───────────────────────── 선택 ─────────────────────────

  void _select(int index, List<RemoteEntry> entries) {
    final kb = HardwareKeyboard.instance;
    setState(() {
      final name = entries[index].name;
      if (kb.isShiftPressed && _anchor != null) {
        final a = _anchor!.clamp(0, entries.length - 1), b = index;
        _selected
          ..clear()
          ..addAll([for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) entries[i].name]);
      } else if (kb.isControlPressed || kb.isMetaPressed) {
        if (!_selected.remove(name)) _selected.add(name);
        _anchor = index;
      } else {
        _selected
          ..clear()
          ..add(name);
        _anchor = index;
      }
    });
  }

  List<RemoteEntry> _selectedEntries(SshSessionProvider session) => [
    for (final e in session.entries)
      if (_selected.contains(e.name)) e,
  ];

  /// 우클릭/끌기를 시작한 항목이 선택에 없으면 그 항목만 선택한다. 있으면 선택 전체가 대상이다.
  List<RemoteEntry> _targetsFor(SshSessionProvider session, RemoteEntry e) {
    if (!_selected.contains(e.name)) {
      setState(() {
        _selected
          ..clear()
          ..add(e.name);
        _anchor = session.entries.indexWhere((x) => x.name == e.name);
      });
    }
    return _selectedEntries(session);
  }

  // ───────────────────────── 대화상자 ─────────────────────────

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

  // ───────────────────────── 동작 ─────────────────────────

  Future<void> _onDrop(List<String> paths) async {
    // 이 앱에서 끌어낸 것이 다시 들어온 경우는 무시한다.
    if (FlutterDragOut.inProgress) return;
    final session = context.read<SshSessionProvider>();
    if (paths.isEmpty || !session.connected) return;
    if (!await _confirmOverwrite(session.uploadConflicts(paths))) return;
    await _guard(() => session.upload(paths));
  }

  Future<void> _download(List<RemoteEntry> items) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    if (items.length == 1 && !items.single.isDirectory) {
      // 저장 대화상자가 덮어쓰기 확인을 한다.
      final e = items.single;
      final location = await getSaveLocation(suggestedName: e.name, confirmButtonText: l10n.sftpDownload);
      if (location == null) return;
      await _guard(() async {
        if (!await session.downloadEntryTo(e, location.path)) throw FileSystemException('download failed', e.name);
      });
      return;
    }
    final dir = await getDirectoryPath(confirmButtonText: l10n.sftpDownloadConfirm);
    if (dir == null) return;
    if (!await _confirmOverwrite(session.downloadConflicts(items, dir))) return;
    await _guard(() => session.download(items, dir));
  }

  Future<void> _delete(List<RemoteEntry> items) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sftpDelete),
        content: Text(
          items.length == 1 ? l10n.sftpDeleteConfirm(items.single.name) : l10n.sftpDeleteConfirmMany(items.length),
        ),
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
    if (ok != true) return;
    await _guard(() async {
      for (final e in items) {
        await session.delete(e);
      }
    });
    if (mounted) setState(_selected.clear);
  }

  Future<void> _rename(RemoteEntry e) async {
    final session = context.read<SshSessionProvider>();
    final l10n = AppLocalizations.of(context);
    final name = await _askText(l10n.sftpRename, l10n.sftpNewName, initial: e.name);
    if (name == null || name.isEmpty || name == e.name) return;
    await _guard(() => session.rename(e, name));
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..add(name);
    });
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
    final targets = _targetsFor(session, e);
    final single = targets.length == 1;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'download', child: Text(l10n.sftpDownload)),
        if (single && e.isDirectory) PopupMenuItem(value: 'terminal', child: Text(l10n.pathMenuTerminalToHere)),
        if (single) PopupMenuItem(value: 'rename', child: Text(l10n.sftpRename)),
        PopupMenuItem(value: 'delete', child: Text(l10n.sftpDelete)),
      ],
    );
    switch (choice) {
      case 'download':
        await _download(targets);
      case 'terminal':
        session.moveTerminalTo(session.pathOf(e));
      case 'rename':
        await _rename(e);
      case 'delete':
        await _delete(targets);
    }
  }

  // ───────────────────────── 끌어내기 (flutter_drag_out) ─────────────────────────

  void _onDragStarted(SshSessionProvider session, RemoteEntry e) {
    final items = _targetsFor(session, e);
    final drag = _Drag(items, session.remotePath);
    _drag = drag;
    // 파일 프로미스가 없는 플랫폼(Windows/Linux)은 로컬 사본이 있어야 끌어낼 수 있다.
    // 끌기가 창을 벗어나기 전에 미리 받기 시작해서 기다리는 시간을 줄인다.
    if (!FlutterDragOut.supportsPromises) {
      drag.staged = session
          .stageForDrag(items, from: drag.from)
          .then<List<String>?>(
            (paths) => paths,
            onError: (Object err) {
              _toast('$err');
              return null;
            },
          );
    }
  }

  void _onDragUpdate(SshSessionProvider session, DragUpdateDetails details) {
    final drag = _drag;
    if (drag == null || drag.handedOver) return;
    final viewSize = MediaQuery.sizeOf(context);
    if (FlutterDragOut.supportsPromises) {
      // macOS: 아무것도 미리 받지 않는다. 놓는 곳에서 바로 받는다.
      FlutterDragOut.maybeStartOnExit(
        details.globalPosition,
        viewSize: viewSize,
        items: () {
          drag.handedOver = true;
          return [
            for (final e in drag.items)
              DragOutItem.promise(
                name: e.name,
                isDirectory: e.isDirectory,
                write: (request) async {
                  if (!await session.downloadEntryTo(e, request.targetPath, from: drag.from)) {
                    throw FileSystemException('download failed', e.name);
                  }
                },
              ),
          ];
        },
      );
    } else if (!(Offset.zero & viewSize).contains(details.globalPosition)) {
      drag.handedOver = true;
      unawaited(_handOver(drag));
    }
  }

  /// 로컬 사본이 다 받아지면 OS 끌기 세션을 시작한다. 그 사이 마우스를 놓았다면 아무것도 하지 않는다.
  Future<void> _handOver(_Drag drag) async {
    final paths = await drag.staged;
    if (paths == null || !identical(_drag, drag)) return;
    await FlutterDragOut.start(paths);
  }

  // ───────────────────────── 화면 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SshSessionProvider>();
    final scheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) {
        if (!FlutterDragOut.inProgress) setState(() => _dragging = true);
      },
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
                            selected: _selected.contains(e.name),
                            onTap: () => _select(i, session.entries),
                            onOpen: () => e.isDirectory ? session.openEntry(e) : _download([e]),
                            onMenu: (pos) => _rowMenu(e, pos),
                            dragCount: () => _selected.contains(e.name) ? _selected.length : 1,
                            onDragStarted: () => _onDragStarted(session, e),
                            onDragUpdate: (d) => _onDragUpdate(session, d),
                            onDragEnd: () => _drag = null,
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
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.dragCount,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final RemoteEntry entry;
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
          if (!entry.isDirectory && entry.size != null) Text(_formatSize(entry.size!), style: small),
        ],
      ),
    );
    return GestureDetector(
      onSecondaryTapDown: (d) => onMenu(d.globalPosition),
      child: Draggable<List<RemoteEntry>>(
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
