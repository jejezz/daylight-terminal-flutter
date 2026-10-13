// portside-flutter의 LineSender에서 가져와 SSH에 맞게 고침 (로컬 에코 제거, 줄 끝 기본값 CR).
// 거기에 편집기처럼 스크립트 파일을 열고 저장하는 기능을 더했다.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/line_ending.dart';
import '../services/sender_file.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import 'pass_through_cursor.dart';

/// 여러 줄을 미리 써두고 한 줄씩 순서대로 전송하는 스크립트 러너.
/// 그냥 Enter는 커서가 있는 줄을 전송하고, Ctrl+Enter는 평범한 줄바꿈이다.
/// 전송 후 커서는 다음 줄의 끝으로 이동해서, Enter를 반복해서 누르면
/// 위에서부터 한 줄씩 순서대로 흘러 내려가며 전송된다.
///
/// 편집기처럼 스크립트를 파일에서 불러오고(Ctrl+O) 저장할 수 있다(Ctrl+S, 다른 이름으로: Ctrl+Shift+S).
/// 어느 파일을 편집 중인지와 변경 여부가 입력 칸 위에 보이고, 저장하지 않은 변경이 있으면 열기·새로 만들기 전에 묻는다.
class LineSender extends StatefulWidget {
  const LineSender({super.key});

  @override
  State<LineSender> createState() => _LineSenderState();
}

class _LineSenderState extends State<LineSender> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();

  /// 편집 중인 파일. 아직 저장한 적 없는 새 스크립트면 null.
  String? _path;

  /// 파일에 저장된(또는 방금 불러온) 내용과 그 파일의 줄바꿈.
  String _savedText = '';
  String _eol = '\n';
  bool _modified = false;

  /// 내용이 칸보다 길어서 스크롤바가 생겼는가.
  bool _scrollable = false;

  /// 입력 칸 안쪽 여백. 스크롤바는 이 여백 안쪽에 그려지므로(손잡이가 상자 오른쪽 끝에서 18~24px 안쪽) 스크롤바
  /// 영역을 잡을 때 여백을 더해야 한다.
  static const _contentPadding = 10.0;

  /// 스크롤바 위에서 화살표 커서를 보여 줄 오른쪽 가장자리의 폭: 여백 + 스크롤바(손잡이와 여백) 약 18px.
  static const _scrollbarWidth = _contentPadding + 18.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateModified);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ───────────────────────── 파일: 열기 / 저장 ─────────────────────────

  /// 끝에 붙은 빈 줄은 무시하고 비교한다 — 마지막 줄을 보내면 자동으로 새 줄이 붙는데, 그것만으로 "변경됨"이
  /// 되면 스크립트를 끝까지 실행할 때마다 저장하라는 표시가 뜨기 때문이다.
  static String _trimEnd(String s) => s.replaceFirst(RegExp(r'\n+$'), '');

  void _updateModified() {
    _checkScrollable();
    final modified = _path != null ? _trimEnd(_controller.text) != _trimEnd(_savedText) : _controller.text.isNotEmpty;
    if (modified != _modified) setState(() => _modified = modified);
  }

  String get _displayName => _path == null ? AppLocalizations.of(context).senderUntitled : p.basename(_path!);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  String _errorText(Object e) {
    final l10n = AppLocalizations.of(context);
    if (e is SenderFileException) {
      return switch (e.kind) {
        SenderFileError.tooLarge => l10n.senderFileTooLarge(SenderFile.maxBytes ~/ (1024 * 1024)),
        SenderFileError.notUtf8 => l10n.senderFileNotUtf8,
        SenderFileError.io => l10n.senderFileError(e.detail),
      };
    }
    return l10n.senderFileError('$e');
  }

  /// 저장하지 않은 변경이 있으면 물어본다. 계속해도 되면 true. ("저장"을 골랐는데 저장을 취소하면 false)
  Future<bool> _confirmDiscard() async {
    if (!_modified) return true;
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.senderUnsavedTitle),
        content: Text(l10n.senderUnsavedBody(_displayName)),
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
    return switch (choice) {
      'discard' => true,
      'save' => await _save(),
      _ => false,
    };
  }

  Future<void> _new() async {
    if (!await _confirmDiscard()) return;
    _setDocument(null, '', '\n');
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    final file = await openFile();
    if (file == null) return;
    try {
      final doc = await SenderFile.read(file.path);
      _setDocument(file.path, doc.text, doc.eol);
    } catch (e) {
      _toast(_errorText(e));
    }
  }

  /// 편집 중인 파일에 저장한다. 파일이 아직 없으면 "다른 이름으로 저장". 저장했으면 true.
  Future<bool> _save() => _path == null ? _saveAs() : _write(_path!);

  Future<bool> _saveAs() async {
    final location = await getSaveLocation(
      suggestedName: _path == null ? SenderFile.suggestedName : p.basename(_path!),
      confirmButtonText: AppLocalizations.of(context).senderSaveFirst,
    );
    if (location == null) return false;
    return _write(location.path);
  }

  Future<bool> _write(String path) async {
    final text = _controller.text;
    try {
      await SenderFile.write(path, text, eol: _eol);
    } catch (e) {
      _toast(_errorText(e));
      return false;
    }
    if (!mounted) return true;
    setState(() {
      _path = path;
      _savedText = text;
      _modified = false;
    });
    return true;
  }

  /// 칸의 내용을 문서로 바꾼다. 커서는 맨 앞에 두어서 Enter를 누르면 첫 줄부터 보내진다.
  void _setDocument(String? path, String text, String eol) {
    _path = path;
    _savedText = text;
    _eol = eol;
    _modified = false;
    _controller.value = TextEditingValue(text: text, selection: const TextSelection.collapsed(offset: 0));
    setState(() {});
  }

  // ───────────────────────── 키보드 ─────────────────────────

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    // 파일 단축키: Windows/Linux는 Ctrl, macOS는 ⌘. (앱 전역 단축키는 Ctrl+Shift라 겹치지 않는다.)
    final kb = HardwareKeyboard.instance;
    final command = defaultTargetPlatform == TargetPlatform.macOS ? kb.isMetaPressed : kb.isControlPressed;
    if (command && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        kb.isShiftPressed ? _saveAs() : _save();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyO) {
        _open();
        return KeyEventResult.handled;
      }
    }

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;

    final connected = context.read<TerminalSession>().connected;
    // 연결 전에는 전송할 대상이 없으므로 Enter도 보통의 줄바꿈으로만 동작해서
    // 스크립트를 미리 자유롭게 써둘 수 있다.
    if (!connected || HardwareKeyboard.instance.isControlPressed) {
      _insertNewlineAtCursor();
    } else {
      _sendCurrentLine();
    }
    return KeyEventResult.handled;
  }

  // TextField의 기본 동작에 기대지 않고 직접 줄바꿈을 넣는다 — 플랫폼 텍스트 입력
  // 채널이 raw 키 이벤트 처리와 별개로 움직여서 Ctrl+Enter를 무시(ignored)하면
  // 줄바꿈이 전혀 안 들어가는 문제가 있었다.
  void _insertNewlineAtCursor() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  void _sendCurrentLine() {
    final session = context.read<TerminalSession>();
    if (!session.connected) return;

    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final safeCursor = cursor < 0 ? text.length : cursor;

    var lineStart = 0;
    if (safeCursor > 0) {
      final idx = text.lastIndexOf('\n', safeCursor - 1);
      lineStart = idx == -1 ? 0 : idx + 1;
    }
    var lineEnd = text.indexOf('\n', safeCursor);
    if (lineEnd == -1) lineEnd = text.length;

    session.send(text.substring(lineStart, lineEnd));

    if (lineEnd == text.length) {
      // 마지막 줄이었다 — 새 빈 줄을 만들고 거기로 이동해서 바로 이어 쓸 수 있게.
      final newText = '$text\n';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else {
      var nextLineEnd = text.indexOf('\n', lineEnd + 1);
      if (nextLineEnd == -1) nextLineEnd = text.length;
      _controller.selection = TextSelection.collapsed(offset: nextLineEnd);
    }
  }

  // ───────────────────────── 화면 ─────────────────────────

  bool _scrollCheckQueued = false;

  /// 프레임이 끝난 뒤 칸이 스크롤되는지(= 스크롤바가 있는지) 다시 읽는다. Flutter의 스크롤 크기 알림은 글이 짧아져서
  /// 스크롤할 필요가 없어진 경우에는 오지 않기도 해서(측정으로 확인), 알림만 믿으면 화살표 영역이 남는다.
  /// 글이 바뀔 때, 칸의 크기가 바뀔 때, 알림이 올 때 부른다. 한 프레임에 한 번만 확인한다.
  void _checkScrollable() {
    if (_scrollCheckQueued) return;
    _scrollCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCheckQueued = false;
      if (!mounted || !_scroll.hasClients) return;
      final scrollable = _scroll.position.maxScrollExtent > 0;
      if (scrollable != _scrollable) setState(() => _scrollable = scrollable);
    });
  }

  /// TextField는 칸 전체를 텍스트 입력용 I자 커서로 덮어서, 그 안의 스크롤바 위에서도 커서가 바뀌지 않는다.
  /// 스크롤바가 있을 때만 오른쪽 가장자리에 화살표 커서 영역을 겹친다. 이 영역은 마우스 이벤트를 가로채지
  /// 않아서([PassThroughCursorRegion]) 스크롤바를 눌러 끄는 동작은 그대로 된다.
  Widget _withScrollbarCursor(Widget field) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _checkScrollable();
        return false;
      },
      // 칸 크기가 바뀌면(스크립트 영역을 끌어서 키우거나 줄일 때) 스크롤바가 생기거나 사라질 수 있다.
      child: LayoutBuilder(
        builder: (context, _) {
          _checkScrollable();
          return Stack(
            children: [
              Positioned.fill(child: field),
              if (_scrollable)
                const Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: _scrollbarWidth,
                  child: PassThroughCursorRegion(cursor: SystemMouseCursors.basic),
                ),
            ],
          );
        },
      ),
    );
  }

  static String get _commandKey => defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl+';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TerminalSession>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        // 부모가 드래그로 조절하는 높이를 주므로, 입력 칸도 그 높이에 맞춰 늘어난다.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 어느 파일을 편집 중인지, 저장하지 않은 변경이 있는지. 파일과 연결되지 않았으면 자리를 차지하지 않는다.
                if (_path != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Tooltip(
                      message: _path!,
                      child: Text(
                        _modified ? '● $_displayName (${l10n.senderModified})' : _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.userContent.copyWith(
                          fontSize: 11.5,
                          color: _modified ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Focus(
                    onKeyEvent: _onKeyEvent,
                    child: _withScrollbarCursor(
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scroll,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppFonts.mono.copyWith(fontSize: 13, color: scheme.onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l10n.senderHint,
                          contentPadding: const EdgeInsets.all(_contentPadding),
                          filled: true,
                          fillColor: scheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 132,
            // 높이를 줄여도 넘치지 않게, 안 들어가면 통째로 줄여서 보여 준다.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 132,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: l10n.senderLineEndingTooltip,
                      child: DropdownButton<LineEnding>(
                        value: session.lineEnding,
                        isDense: true,
                        items: [
                          for (final e in LineEnding.values)
                            DropdownMenuItem(value: e, child: Text(e.label ?? l10n.senderLineEndingNone)),
                        ],
                        onChanged: (value) {
                          if (value != null) session.setLineEnding(value);
                        },
                      ),
                    ),
                    // 스크립트 파일: 열기, 저장, 그 밖(다른 이름으로 저장, 새로 만들기)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          tooltip: l10n.senderOpen('${_commandKey}O'),
                          icon: const Icon(Icons.folder_open_rounded),
                          onPressed: _open,
                        ),
                        IconButton(
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          tooltip: l10n.senderSave('${_commandKey}S'),
                          icon: const Icon(Icons.save_outlined),
                          color: _modified ? scheme.primary : null,
                          onPressed: _save,
                        ),
                        PopupMenuButton<String>(
                          tooltip: l10n.senderMore,
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_horiz_rounded),
                          onSelected: (v) => v == 'saveAs' ? _saveAs() : _new(),
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'saveAs', child: Text(l10n.senderSaveAs)),
                            PopupMenuItem(value: 'new', child: Text(l10n.senderNew)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    IconButton.filledTonal(
                      tooltip: l10n.senderSend,
                      onPressed: session.connected ? _sendCurrentLine : null,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
