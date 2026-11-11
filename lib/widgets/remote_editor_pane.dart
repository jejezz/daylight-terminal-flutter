import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/remote_text_file.dart';
import '../services/sender_file.dart';
import '../settings/terminal_prefs.dart';
import '../state/remote_editor_controller.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import '../theme/phosphor_icons.dart';
import '../utils/ui_scale.dart';
import 'file_pane_parts.dart' show PaneDragData;
import 'highlight_controller.dart';

String _errorText(AppLocalizations l10n, Object e) {
  if (e is RemoteEditException) {
    return switch (e.kind) {
      RemoteEditError.notRegular => l10n.editorErrNotFile,
      RemoteEditError.notFound => l10n.editorErrNotFound,
      RemoteEditError.tooLarge => l10n.editorErrTooLarge(SenderFile.maxBytes ~/ (1024 * 1024)),
      RemoteEditError.notUtf8 => l10n.senderFileNotUtf8,
      RemoteEditError.binary => l10n.editorErrBinary,
      RemoteEditError.alreadyOpen => l10n.editorErrAlreadyOpen,
      RemoteEditError.io => l10n.editorErrIo(e.detail),
    };
  }
  return l10n.editorErrIo('$e');
}

/// 탭·대화상자에 보이는 파일 이름 (서버 경로의 파일 이름, 새 파일은 "제목 없음 N").
String editorDocumentName(AppLocalizations l10n, EditorDocument doc) =>
    doc.path == null ? l10n.editorUntitled(doc.number) : doc.pathContext.basename(doc.path!);

/// 파일 [path]를 편집기 칸에 연다 (SSH 탭은 서버 파일, 로컬 셸·시리얼 탭은 이 PC의 파일). 열 수 없으면 이유를 알린다.
Future<void> openRemoteFile(BuildContext context, TerminalSession session, String path) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final editor = session.editor;
  if (editor == null) return;
  try {
    await editor.open(path);
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_errorText(l10n, e)), duration: const Duration(seconds: 4)));
  }
}

/// [doc]을 저장한다. 서버 경로가 아직 없는 새 파일은 경로를 물어 저장한다. 서버에서 그사이 바뀌었으면 덮어쓸지·서버 버전을
/// 불러올지 묻는다. 저장되었으면 true.
Future<bool> saveEditorDocument(BuildContext context, RemoteEditorController controller, EditorDocument doc) async {
  if (doc.isNew) return saveEditorDocumentAs(context, controller, doc);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  try {
    var result = await controller.save(doc);
    if (result.status == RemoteSaveStatus.conflict) {
      if (!context.mounted) return false;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.editorConflictTitle),
          content: Text(l10n.editorConflictBody(doc.pathContext.basename(doc.path!))),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(l10n.commonCancel),
            ),
            TextButton(onPressed: () => Navigator.pop(context, 'reload'), child: Text(l10n.editorConflictReload)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, 'overwrite'),
              child: Text(l10n.editorConflictOverwrite),
            ),
          ],
        ),
      );
      if (choice == 'reload') {
        await controller.reload(doc);
        return false;
      }
      if (choice != 'overwrite') return false;
      result = await controller.save(doc, overwrite: true);
    }
    say(l10n.editorSaved(doc.pathContext.basename(doc.path!)));
    return true;
  } catch (e) {
    say(_errorText(l10n, e));
    return false;
  }
}

/// 서버 경로를 묻는다 ("서버에 저장" / "다른 이름으로 저장"). 파일 이름 부분이 미리 선택되어 있다. 취소하면 null.
Future<String?> _askServerPath(BuildContext context, String initial) {
  final l10n = AppLocalizations.of(context);
  final input = TextEditingController(text: initial);
  final nameStart = initial.lastIndexOf(RegExp(r'[/\\]')) + 1;
  input.selection = TextSelection(baseOffset: nameStart, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.editorSaveToServerTitle),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.editorSavePathLabel),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: Text(l10n.commonOk)),
      ],
    ),
  );
}

/// [doc]을 서버의 다른 경로에 저장한다 (새 파일의 첫 저장, 또는 다른 이름으로 저장). 이미 있는 파일이면 덮어쓸지 묻는다.
/// 저장되었으면 true.
Future<bool> saveEditorDocumentAs(BuildContext context, RemoteEditorController controller, EditorDocument doc) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  final ctx = controller.pathContext;
  final dir = controller.suggestedDirectory;
  final entered = await _askServerPath(context, doc.path ?? ctx.join(dir, doc.suggestedName ?? 'untitled.txt'));
  if (entered == null || entered.isEmpty) return false;
  final path = ctx.normalize(ctx.isAbsolute(entered) ? entered : ctx.join(dir, entered));
  if (!context.mounted) return false;
  // 같은 이름으로 저장하면 보통 저장과 같다 (그사이 서버에서 바뀌었는지도 확인한다).
  if (path == doc.path) return saveEditorDocument(context, controller, doc);
  try {
    var result = await controller.saveAs(doc, path);
    if (result.status == RemoteSaveStatus.conflict) {
      if (!context.mounted) return false;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.editorExistsTitle),
          content: Text(l10n.editorExistsBody(path)),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.editorConflictOverwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return false;
      result = await controller.saveAs(doc, path, overwrite: true);
    }
    say(l10n.editorSaved(ctx.basename(path)));
    return true;
  } catch (e) {
    say(_errorText(l10n, e));
    return false;
  }
}

/// [docs] 중 저장하지 않은 것이 있으면 하나씩 저장/버리기/취소를 묻는다. 모두 정리되어 계속해도 되면 true.
Future<bool> confirmEditorClose(
  BuildContext context,
  RemoteEditorController controller,
  Iterable<EditorDocument> docs,
) async {
  for (final doc in docs.where((d) => d.modified).toList()) {
    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.senderUnsavedTitle),
        content: Text(l10n.senderUnsavedBody(editorDocumentName(l10n, doc))),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.commonCancel),
          ),
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: Text(l10n.senderDiscard)),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: Text(l10n.senderSaveFirst)),
        ],
      ),
    );
    if (choice == 'save') {
      if (!context.mounted || !await saveEditorDocument(context, controller, doc)) return false;
    } else if (choice != 'discard') {
      return false;
    }
  }
  return true;
}

/// 탭을 닫기 전에 이 탭의 편집기에 저장하지 않은 파일이 있으면 묻는다. 닫아도 되면 true.
Future<bool> confirmCloseSessionEditor(BuildContext context, Object session) {
  final editor = session is TerminalSession ? session.editor : null;
  if (editor == null || !editor.hasUnsaved) return Future.value(true);
  return confirmEditorClose(context, editor, editor.documents);
}

/// 편집기 칸에 끌어놓은 파일들의 경로를 연다. 서버 편집기에서는 서버 파일(이 앱의 탐색기에서 끌어온 것)이면 그대로 열고,
/// 이 PC의 파일([localFiles], OS 탐색기에서 끌어온 것)이면 내용을 새 파일로 열어 서버 경로를 묻고 저장하게 한다. 로컬 편집기는
/// 둘 다 이 PC의 파일을 바로 연다. 여러 개를 끌었을 때 섞여 있는 폴더는 건너뛰고, 한 개만 끌었는데 열 수 없으면 이유를 알린다.
Future<void> openDroppedPaths(
  BuildContext context,
  RemoteEditorController controller,
  List<String> paths, {
  required bool localFiles,
}) async {
  if (paths.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  Object? firstError;
  for (final path in paths) {
    try {
      if (localFiles && !controller.local) {
        await controller.openLocalFileAsNew(path);
      } else {
        await controller.open(path);
      }
    } catch (e) {
      if (paths.length > 1 && e is RemoteEditException && e.kind == RemoteEditError.notRegular) continue;
      firstError ??= e;
    }
  }
  if (firstError != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_errorText(l10n, firstError)), duration: const Duration(seconds: 4)));
  }
}

/// 서버 탭 오른쪽에 붙는 편집기: 위에 열린 파일 탭, 가운데 본문, 아래에 경로와 저장 버튼. 열린 파일이 없으면 안내와
/// "새 파일" 버튼이 보인다.
class RemoteEditorPane extends StatefulWidget {
  const RemoteEditorPane({super.key, required this.controller, this.dropEnabled = true});

  final RemoteEditorController controller;

  /// 파일을 끌어놓아 열 수 있는가 (보이지 않는 탭에서는 끈다).
  final bool dropEnabled;

  @override
  State<RemoteEditorPane> createState() => _RemoteEditorPaneState();
}

class _RemoteEditorPaneState extends State<RemoteEditorPane> {
  bool _dropping = false;

  RemoteEditorController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // 이 앱의 탐색기 행을 끌어온 것(서버 경로 또는 이 PC 경로)과 OS 탐색기에서 끌어온 이 PC의 파일을 둘 다 받는다.
    return DropTarget(
      enable: widget.dropEnabled,
      onDragEntered: (_) {
        if (!FlutterDragOut.inProgress) setState(() => _dropping = true);
      },
      onDragExited: (_) => setState(() => _dropping = false),
      onDragDone: (details) {
        setState(() => _dropping = false);
        // 이 앱에서 끌어낸 것이 다시 들어온 경우는 무시한다.
        if (FlutterDragOut.inProgress) return;
        openDroppedPaths(context, controller, [for (final f in details.files) f.path], localFiles: true);
      },
      child: DragTarget<PaneDragData>(
        onWillAcceptWithDetails: (d) => widget.dropEnabled && d.data.terminalPaths != null,
        onAcceptWithDetails: (d) {
          final paths = d.data.terminalPaths?.call() ?? const <String>[];
          // 같은 편집기의 파일 시스템 안의 경로다 (SSH 탭의 탐색기는 서버 경로, 로컬 탭의 폴더 뷰는 이 PC의 경로).
          openDroppedPaths(context, controller, paths, localFiles: false);
        },
        builder: (context, candidates, _) => Stack(
          children: [
            Positioned.fill(child: _content(context)),
            if (_dropping || candidates.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.editorDropActive,
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final current = controller.current;
        return ColoredBox(
          color: scheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TabStrip(controller: controller),
              Expanded(
                child: controller.documents.isEmpty
                    ? _EmptyEditor(controller: controller)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          // 파일을 바꿔도 각 파일의 스크롤·실행 취소 기록이 남도록 모두 살려 두고 현재 것만 보인다.
                          for (final doc in controller.documents)
                            Offstage(
                              key: ObjectKey(doc),
                              offstage: doc != current,
                              child: _EditorField(controller: controller, doc: doc, active: doc == current),
                            ),
                        ],
                      ),
              ),
              if (current != null) _StatusRow(controller: controller, doc: current),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.controller});

  final RemoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(PhosphorIconsDuotone.notePencil, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.editorEmptyTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.editorEmptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              icon: const PhosphorIcon(PhosphorIconsDuotone.filePlus, size: 18),
              label: Text(l10n.editorNewFile),
              onPressed: controller.newDocument,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.controller});

  final RemoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final warn = dark ? AppColors.warning : AppColors.warningTextLight;
    return Container(
      height: context.scaled(36),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final doc in controller.documents)
                  ListenableBuilder(
                    listenable: doc,
                    builder: (context, _) {
                      final selected = doc == controller.current;
                      final color = doc.modified ? warn : (selected ? scheme.primary : scheme.onSurfaceVariant);
                      final name = editorDocumentName(l10n, doc);
                      return Tooltip(
                        message: doc.path ?? l10n.editorNotSavedYet,
                        child: InkWell(
                          onTap: () => controller.select(doc),
                          child: Container(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  doc.isNew ? PhosphorIconsDuotone.notePencil : PhosphorIconsDuotone.fileText,
                                  size: 15,
                                  color: color,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  doc.modified ? '● $name' : name,
                                  style: AppFonts.userContent.copyWith(
                                    fontSize: 12.5,
                                    color: color,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                IconButton(
                                  tooltip: l10n.editorClose,
                                  iconSize: 14,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                                  padding: EdgeInsets.zero,
                                  icon: const PhosphorIcon(PhosphorIconsDuotone.x),
                                  onPressed: () async {
                                    if (await confirmEditorClose(context, controller, [doc])) controller.close(doc);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  tooltip: l10n.editorNewFile,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const PhosphorIcon(PhosphorIconsDuotone.filePlus),
                  onPressed: controller.newDocument,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.editorHide,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const PhosphorIcon(PhosphorIconsDuotone.caretRight),
            onPressed: () => controller.setVisible(false),
          ),
        ],
      ),
    );
  }
}

/// 접혀 있을 때 오른쪽 끝에 남는 가는 손잡이. 눌러서 편집기를 다시 편다.
class RemoteEditorHandle extends StatelessWidget {
  const RemoteEditorHandle({super.key, required this.controller});

  final RemoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final warn = scheme.brightness == Brightness.dark ? AppColors.warning : AppColors.warningTextLight;
    return Container(
      width: 36,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: l10n.editorEdit,
          icon: PhosphorIcon(PhosphorIconsDuotone.notePencil, color: controller.hasUnsaved ? warn : null),
          onPressed: () => controller.setVisible(true),
        ),
      ),
    );
  }
}

class _EditorField extends StatefulWidget {
  const _EditorField({required this.controller, required this.doc, required this.active});

  final RemoteEditorController controller;
  final EditorDocument doc;
  final bool active;

  @override
  State<_EditorField> createState() => _EditorFieldState();
}

class _EditorFieldState extends State<_EditorField> {
  final _focus = FocusNode();
  final _vScroll = ScrollController();
  final _hScroll = ScrollController();
  final _gutterScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 본문이 세로로 스크롤되면 줄 번호도 같이 움직인다.
    _vScroll.addListener(() {
      if (!_gutterScroll.hasClients) return;
      final max = _gutterScroll.position.maxScrollExtent;
      _gutterScroll.jumpTo(_vScroll.offset.clamp(0.0, max));
    });
    // 방금 열었거나 탭을 눌러 이 파일로 왔으면 바로 쓸 수 있게 포커스를 준다.
    if (widget.active) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _focus.requestFocus() : null);
  }

  @override
  void didUpdateWidget(_EditorField old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _focus.requestFocus() : null);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _vScroll.dispose();
    _hScroll.dispose();
    _gutterScroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    final command = defaultTargetPlatform == TargetPlatform.macOS ? kb.isMetaPressed : kb.isControlPressed;
    if (command && event.logicalKey == LogicalKeyboardKey.keyS) {
      if (kb.isShiftPressed) {
        saveEditorDocumentAs(context, widget.controller, widget.doc);
      } else {
        saveEditorDocument(context, widget.controller, widget.doc);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 글자 하나(고정폭)의 너비. 글꼴·크기가 바뀔 때만 다시 잰다.
  double _charWidth = 8;
  String? _measuredFor;

  void _measure(TextStyle style) {
    final key = '${style.fontFamily}/${style.fontSize}';
    if (_measuredFor == key) return;
    _measuredFor = key;
    final painter = TextPainter(text: TextSpan(text: '0' * 20, style: style), textDirection: TextDirection.ltr)
      ..layout();
    _charWidth = painter.width / 20;
    painter.dispose();
  }

  /// 줄 수(마지막 줄 포함)와, 가장 긴 줄의 칸 수 (한글 같은 넓은 글자는 2칸으로 센다 — 줄을 넘기지 않으므로 가로 스크롤 폭을 정한다).
  static (int, int) _lineStats(String text) {
    var lines = 1;
    var longest = 0;
    var cells = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x0A) {
        lines++;
        if (cells > longest) longest = cells;
        cells = 0;
      } else {
        cells += c >= 0x1100 ? 2 : 1;
      }
    }
    return (lines, cells > longest ? cells : longest);
  }

  String _gutterText = '1';
  int _gutterLines = 1;

  String _numbers(int lines) {
    if (lines != _gutterLines) {
      _gutterLines = lines;
      _gutterText = [for (var i = 1; i <= lines; i++) i].join('\n');
    }
    return _gutterText;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<TerminalPrefs>();
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: prefs.family,
      fontFamilyFallback: prefs.style.fontFamilyFallback,
      fontSize: prefs.size,
      height: 1.3,
      color: scheme.onSurface,
    );
    // 줄 번호와 본문의 줄 높이가 어긋나지 않도록 둘 다 같은 고정 줄 높이(strut)를 쓴다.
    final strut = StrutStyle(
      fontFamily: prefs.family,
      fontFamilyFallback: prefs.style.fontFamilyFallback,
      fontSize: prefs.size,
      height: 1.3,
      forceStrutHeight: true,
    );
    _measure(style);
    widget.doc.text.palette = SyntaxPalette.of(scheme.brightness);
    // 편집기 글자는 터미널과 같은 글꼴·크기를 쓴다 ("화면 글자 크기" 배율은 받지 않는다).
    // 줄은 넘기지 않고 가로로 스크롤한다 — 한 줄이 화면 한 줄이라 줄 번호가 정확하다.
    return MediaQuery.withNoTextScaling(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Focus(
          onKeyEvent: _onKey,
          child: ListenableBuilder(
            listenable: widget.doc.text,
            builder: (context, _) {
              final (lines, longest) = _lineStats(widget.doc.text.text);
              final digits = lines.toString().length < 2 ? 2 : lines.toString().length;
              final gutterWidth = digits * _charWidth + AppSpacing.sm + AppSpacing.md;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: gutterWidth,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border(right: BorderSide(color: scheme.outlineVariant)),
                    ),
                    child: SingleChildScrollView(
                      controller: _gutterScroll,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Text(
                          _numbers(lines),
                          key: const ValueKey('editor-line-numbers'),
                          textAlign: TextAlign.right,
                          softWrap: false,
                          style: style.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          strutStyle: strut,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final width = (longest + 4) * _charWidth + AppSpacing.md * 2;
                        return Scrollbar(
                          controller: _vScroll,
                          notificationPredicate: (n) => n.depth == 1,
                          child: Scrollbar(
                            controller: _hScroll,
                            child: SingleChildScrollView(
                              controller: _hScroll,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: width < box.maxWidth ? box.maxWidth : width,
                                child: TextField(
                                  controller: widget.doc.text,
                                  focusNode: _focus,
                                  scrollController: _vScroll,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: style,
                                  strutStyle: strut,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.all(AppSpacing.md),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller, required this.doc});

  final RemoteEditorController controller;
  final EditorDocument doc;

  static String get _command => defaultTargetPlatform == TargetPlatform.macOS ? '⌘S' : 'Ctrl+S';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final warn = scheme.brightness == Brightness.dark ? AppColors.warning : AppColors.warningTextLight;
    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        final where = doc.path ?? l10n.editorNotSavedYet;
        return Container(
          height: context.scaled(36),
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: where,
                  child: Text(
                    doc.modified && !doc.isNew ? '$where  (${l10n.editorModified})' : where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: doc.modified ? warn : scheme.onSurfaceVariant),
                  ),
                ),
              ),
              if (doc.saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                tooltip: l10n.editorSaveAs,
                iconSize: 20,
                icon: const PhosphorIcon(PhosphorIconsDuotone.floppyDiskBack),
                onPressed: doc.saving ? null : () => saveEditorDocumentAs(context, controller, doc),
              ),
              IconButton(
                tooltip: l10n.editorSave(_command),
                iconSize: 20,
                color: doc.modified ? scheme.primary : null,
                icon: const PhosphorIcon(PhosphorIconsDuotone.floppyDisk),
                onPressed: doc.saving ? null : () => saveEditorDocument(context, controller, doc),
              ),
            ],
          ),
        );
      },
    );
  }
}
