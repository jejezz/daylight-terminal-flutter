import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:provider/provider.dart';

import '../help/help_mode.dart';
import '../l10n/app_localizations.dart';
import '../models/file_item.dart';
import '../services/file_reveal_service.dart';
import '../state/local_folder_session.dart';
import '../theme/app_theme.dart';
import 'file_pane_parts.dart';
import 'list_selection.dart';

/// 로컬 셸 탭의 왼쪽 폴더 뷰 — 이 PC의 폴더를 보여 준다.
///
/// SFTP 탐색기와 같은 모양이다 (다중 선택, 이름 변경, 삭제, 새 폴더, 창 밖으로 끌어내기). 터미널 경로와는
/// 자동으로 연동하지 않고, 상단 "경로 이동" 메뉴로만 맞춘다.
class LocalFolderPane extends StatefulWidget {
  const LocalFolderPane({super.key});

  @override
  State<LocalFolderPane> createState() => _LocalFolderPaneState();
}

class _LocalFolderPaneState extends State<LocalFolderPane> {
  final _selection = ListSelection();
  List<String>? _dragPaths;
  bool _dropping = false;

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

  List<FileItem> _targetsFor(LocalFolderSession session, FileItem e) {
    final targets = _selection.targetsFor(e, session.entries);
    setState(() {});
    return targets;
  }

  /// 이 PC의 파일을 놓았을 때: 지금 폴더로 복사한다.
  Future<void> _onDrop(List<String> paths) async {
    // 이 앱에서 끌어낸 것이 다시 들어온 경우는 무시한다.
    if (FlutterDragOut.inProgress || paths.isEmpty) return;
    final session = context.read<LocalFolderSession>();
    if (!await confirmOverwriteDialog(context, session.copyConflicts(paths))) return;
    await _guard(() => session.copyIn(paths));
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

  Future<void> _newFolder(LocalFolderSession session) async {
    final l10n = AppLocalizations.of(context);
    final name = await _askText(l10n.sftpNewFolder, l10n.sftpFolderName);
    if (name == null || name.isEmpty) return;
    await _guard(() => session.makeDirectory(name));
  }

  Future<void> _rename(LocalFolderSession session, FileItem e) async {
    final l10n = AppLocalizations.of(context);
    final name = await _askText(l10n.sftpRename, l10n.sftpNewName, initial: e.name);
    if (name == null || name.isEmpty || name == e.name) return;
    await _guard(() => session.rename(e, name));
    if (mounted) setState(() => _selection.setOnly(name));
  }

  Future<void> _delete(LocalFolderSession session, List<FileItem> items) async {
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
    if (mounted) setState(_selection.clear);
  }

  Future<void> _syncExplorer(LocalFolderSession session) async {
    final l10n = AppLocalizations.of(context);
    if (!await session.syncExplorerToTerminal()) _toast(l10n.pathCwdFailed);
  }

  Future<void> _rowMenu(LocalFolderSession session, FileItem e, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final targets = _targetsFor(session, e);
    final single = targets.length == 1;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        if (single) PopupMenuItem(value: 'open', child: Text(l10n.localOpen)),
        if (single) PopupMenuItem(value: 'reveal', child: Text(l10n.localReveal)),
        if (single && e.isDirectory && session.canMoveTerminal)
          PopupMenuItem(value: 'terminal', child: Text(l10n.pathMenuTerminalToHere)),
        if (single) PopupMenuItem(value: 'rename', child: Text(l10n.sftpRename)),
        PopupMenuItem(value: 'delete', child: Text(l10n.sftpDelete)),
      ],
    );
    switch (choice) {
      case 'open':
        await _guard(() => FileRevealService.open(session.pathOf(e)));
      case 'reveal':
        await _guard(() => FileRevealService.reveal(session.pathOf(e)));
      case 'terminal':
        session.moveTerminalTo(session.pathOf(e));
      case 'rename':
        await _rename(session, e);
      case 'delete':
        await _delete(session, targets);
    }
  }

  Future<void> _showPlaces(LocalFolderSession session, BuildContext buttonContext) async {
    final places = await session.places();
    if (!mounted || !buttonContext.mounted) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height));
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(origin.dx, origin.dy, origin.dx, origin.dy),
      items: [for (final (label, path) in places) PopupMenuItem(value: path, child: Text(label))],
    );
    if (choice != null) await session.loadFolder(choice);
  }

  // ───────────────────────── 끌어내기 (flutter_drag_out) ─────────────────────────

  void _onDragStarted(LocalFolderSession session, FileItem e) {
    final items = _targetsFor(session, e);
    _dragPaths = [for (final i in items) session.pathOf(i)];
  }

  /// 로컬 파일은 이미 이 PC에 있으니 미리 받을 것 없이 경로만 넘기면 된다.
  void _onDragUpdate(DragUpdateDetails details) {
    final paths = _dragPaths;
    if (paths == null) return;
    FlutterDragOut.maybeStartOnExit(details.globalPosition, viewSize: MediaQuery.sizeOf(context), paths: () => paths);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<LocalFolderSession>();
    final scheme = Theme.of(context).colorScheme;

    return DropTarget(
      enable: session.isActive,
      onDragEntered: (_) {
        if (!FlutterDragOut.inProgress) setState(() => _dropping = true);
      },
      onDragExited: (_) => setState(() => _dropping = false),
      onDragDone: (details) {
        setState(() => _dropping = false);
        _onDrop([for (final f in details.files) f.path]);
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaneHeader(
                path: session.folderPath,
                canGoUp: session.canGoUp,
                onUp: session.goUp,
                onRefresh: session.refreshFolder,
                onNewFolder: () => _newFolder(session),
                onTerminalToHere: session.canMoveTerminal ? () => session.moveTerminalTo(session.folderPath) : null,
                // 현재 경로를 알려 줄 수 없는 셸(cmd)은 이 항목을 숨긴다.
                onExplorerToTerminal: session.canSyncExplorer ? () => _syncExplorer(session) : null,
                extraActions: [
                  Builder(
                    builder: (buttonContext) => IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.localPlaces,
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () => _showPlaces(session, buttonContext),
                    ).help(HelpId.panePlaces),
                  ),
                ],
              ),
              if (session.folderError != null) _FolderErrorBanner(session: session),
              Expanded(
                child: session.entries.isEmpty && !session.folderLoading
                    ? Center(
                        child: Text(l10n.sftpEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        itemCount: session.entries.length,
                        itemBuilder: (context, i) {
                          final e = session.entries[i];
                          return FileRow(
                            entry: e,
                            selected: _selection.contains(e.name),
                            onTap: () =>
                                setState(() => _selection.click(i, session.entries, HardwareKeyboard.instance)),
                            onOpen: () => _guard(
                              () => e.isDirectory ? session.openEntry(e) : FileRevealService.open(session.pathOf(e)),
                            ),
                            onMenu: (pos) => _rowMenu(session, e, pos),
                            dragCount: () => _selection.contains(e.name) ? _selection.length : 1,
                            onDragStarted: () => _onDragStarted(session, e),
                            onDragUpdate: _onDragUpdate,
                            onDragEnd: () => _dragPaths = null,
                            dragData: PaneDragData(
                              (accept) async => [
                                for (final i in _targetsFor(session, e))
                                  if (accept(i)) session.pathOf(i),
                              ],
                              terminalPaths: () => [for (final i in _targetsFor(session, e)) session.pathOf(i)],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (session.folderLoading)
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
          if (_dropping)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.localDropActive,
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 폴더를 못 읽었을 때 목록 위에 붙는 안내. 오류는 목록과 따로 보이고, 대신 열어 준 폴더가 있으면 함께 알려 준다.
class _FolderErrorBanner extends StatelessWidget {
  const _FolderErrorBanner({required this.session});

  final LocalFolderSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final path = session.folderErrorPath ?? '';
    final style = TextStyle(color: scheme.onErrorContainer, fontSize: 12);
    final moved = session.folderErrorMovedTo;
    final buttonStyle = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: scheme.onErrorContainer,
      side: BorderSide(color: scheme.onErrorContainer),
    );
    return Container(
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.folderErrorDenied ? l10n.localFolderErrorDenied(path) : l10n.localFolderErrorFailed(path),
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (moved != null) Text(l10n.localFolderErrorMoved(moved), style: style),
                  if (session.folderErrorDenied) Text(l10n.localFolderErrorHint, style: style),
                  Text(l10n.localFolderError(session.folderError!), style: style.copyWith(fontSize: 11)),
                  if (session.folderErrorDenied && path.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          // 탐색기가 권한 상승(UAC) 창을 띄워 준다. 앱을 관리자로 올리지 않고 그 폴더만 허용받는다.
                          if (Platform.isWindows)
                            OutlinedButton.icon(
                              style: buttonStyle,
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: Text(l10n.localFolderErrorOpenExplorer),
                              onPressed: () => unawaited(FileRevealService.open(path).catchError((_) {})),
                            ),
                          OutlinedButton.icon(
                            style: buttonStyle,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(l10n.localFolderErrorRetry),
                            onPressed: () => unawaited(session.loadFolder(path)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.localFolderErrorDismiss,
            color: scheme.onErrorContainer,
            icon: const Icon(Icons.close),
            onPressed: session.dismissFolderError,
          ),
        ],
      ),
    );
  }
}
