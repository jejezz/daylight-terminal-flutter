import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/remote_text_file.dart';
import '../services/sender_file.dart';
import '../settings/terminal_prefs.dart';
import '../state/remote_editor_controller.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';
import '../theme/phosphor_icons.dart';
import '../utils/ui_scale.dart';

String _errorText(AppLocalizations l10n, Object e) {
  if (e is RemoteEditException) {
    return switch (e.kind) {
      RemoteEditError.notRegular => l10n.editorErrNotFile,
      RemoteEditError.notFound => l10n.editorErrNotFound,
      RemoteEditError.tooLarge => l10n.editorErrTooLarge(SenderFile.maxBytes ~/ (1024 * 1024)),
      RemoteEditError.notUtf8 => l10n.senderFileNotUtf8,
      RemoteEditError.binary => l10n.editorErrBinary,
      RemoteEditError.io => l10n.editorErrIo(e.detail),
    };
  }
  return l10n.editorErrIo('$e');
}

/// 서버 파일 [path]를 편집기 칸에 연다. 열 수 없으면 이유를 알린다.
Future<void> openRemoteFile(BuildContext context, SshSessionProvider session, String path) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await session.editor.open(path);
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_errorText(l10n, e)), duration: const Duration(seconds: 4)));
  }
}

/// [doc]을 저장한다. 서버에서 그사이 바뀌었으면 덮어쓸지·서버 버전을 불러올지 묻는다. 저장되었으면 true.
Future<bool> saveEditorDocument(BuildContext context, RemoteEditorController controller, EditorDocument doc) async {
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
          content: Text(l10n.editorConflictBody(p.posix.basename(doc.path))),
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
    say(l10n.editorSaved(p.posix.basename(doc.path)));
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
        content: Text(l10n.senderUnsavedBody(p.posix.basename(doc.path))),
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
  if (session is! SshSessionProvider || !session.editor.hasUnsaved) return Future.value(true);
  return confirmEditorClose(context, session.editor, session.editor.documents);
}

/// 서버 탭 오른쪽에 붙는 편집기: 위에 열린 파일 탭, 가운데 본문, 아래에 경로와 저장 버튼.
class RemoteEditorPane extends StatelessWidget {
  const RemoteEditorPane({super.key, required this.controller});

  final RemoteEditorController controller;

  @override
  Widget build(BuildContext context) {
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
                child: Stack(
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
                      return Tooltip(
                        message: doc.path,
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
                                PhosphorIcon(PhosphorIconsDuotone.fileText, size: 15, color: color),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  doc.modified ? '● ${p.posix.basename(doc.path)}' : p.posix.basename(doc.path),
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
      saveEditorDocument(context, widget.controller, widget.doc);
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
    final painter = TextPainter(
      text: TextSpan(text: '0' * 20, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
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
      builder: (context, _) => Container(
        height: context.scaled(36),
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: doc.path,
                child: Text(
                  doc.modified ? '${doc.path}  (${l10n.editorModified})' : doc.path,
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
              tooltip: l10n.editorSave(_command),
              iconSize: 20,
              color: doc.modified ? scheme.primary : null,
              icon: const PhosphorIcon(PhosphorIconsDuotone.floppyDisk),
              onPressed: doc.saving ? null : () => saveEditorDocument(context, controller, doc),
            ),
          ],
        ),
      ),
    );
  }
}
