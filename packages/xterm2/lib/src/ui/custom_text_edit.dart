import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextEdit extends StatefulWidget {
  CustomTextEdit({
    super.key,
    required this.child,
    required this.onInsert,
    required this.onDelete,
    required this.onComposing,
    required this.onAction,
    required this.onKeyEvent,
    required this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    // this.initEditingState = TextEditingValue.empty,
    int? viewId,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.newline,
    this.keyboardAppearance = Brightness.light,
    this.deleteDetection = false,
  }) : viewId = viewId ?? PlatformDispatcher.instance.implicitView?.viewId {
    if (this.viewId == null) {
      throw Exception('Cannot open input connection without a valid viewId.');
    }
  }

  final Widget child;

  final void Function(String) onInsert;

  final void Function() onDelete;

  final void Function(String?) onComposing;

  final void Function(TextInputAction) onAction;

  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  final FocusNode focusNode;

  final bool autofocus;

  final bool readOnly;

  final TextInputType inputType;

  final TextInputAction inputAction;

  final Brightness keyboardAppearance;

  final bool deleteDetection;

  final int? viewId;

  @override
  CustomTextEditState createState() => CustomTextEditState();
}

class CustomTextEditState extends State<CustomTextEdit> with TextInputClient {
  TextInputConnection? _connection;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

  @override
  void didUpdateWidget(CustomTextEdit oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (!_shouldCreateInputConnection) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        _openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _closeInputConnectionIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }

  bool get hasInputConnection => _connection != null && _connection!.attached;

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void closeKeyboard() {
    if (hasInputConnection) {
      _connection?.close();
    }
  }

  void setEditingState(TextEditingValue value) {
    _currentEditingState = value;
    _connection?.setEditingState(value);
  }

  void setEditableRect(Rect rect, Rect caretRect) {
    if (!hasInputConnection) {
      return;
    }

    _connection?.setEditableSizeAndTransform(
      rect.size,
      Matrix4.translationValues(0, 0, 0),
    );

    _connection?.setCaretRect(caretRect);
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (_currentEditingState.composing.isCollapsed) {
      return widget.onKeyEvent(focusNode, event);
    }

    // macOS: 조합 중에 Backspace를 누르면 자모가 하나 남은 마지막 한 번은 IME가 지우지 않고 그 글자를 그대로 확정해 버린다.
    // 그 확정이 Backspace 때문인지 알아보려고, 누른 때와 그때 조합 중이던 글을 기억해 둔다(_updateEditingValueMac 참고).
    if (_macImeMode &&
        event is! KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _macBackspaceAt = DateTime.now();
      _macBackspaceComposing =
          _currentEditingState.composing.textInside(_currentEditingState.text);
    }

    return KeyEventResult.skipRemainingHandlers;
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (hasInputConnection) {
      _connection!.show();
    } else {
      final config = TextInputConfiguration(
        viewId: widget.viewId,
        inputType: widget.inputType,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
      );

      _connection = TextInput.attach(this, config);

      _connection!.show();

      // setEditableRect(Rect.zero, Rect.zero);

      _connection!.setEditingState(_initEditingState);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_connection != null && _connection!.attached) {
      _connection!.close();
      _connection = null;
    }
  }

  TextEditingValue get _initEditingState => widget.deleteDetection
      ? const TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        )
      : const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );

  late var _currentEditingState = _initEditingState.copyWith();

  @override
  TextEditingValue? get currentTextEditingValue {
    return _currentEditingState;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null;
  }

  /// 지금까지 터미널로 이미 보낸 편집 상태의 글(초기 글 포함). Windows 한글 IME는 글자를 확정하면서 곧바로 다음 글자
  /// 조합을 시작해서 확정된 글과 조합 중인 글을 한 값에 담아 보내고, 우리가 편집 상태를 비운 뒤에도 한동안 이전 글을 그대로
  /// 보내며, 커서 뒤에 같은 글이 한 번 더 붙어 오기도 한다. 값 전체를 새 입력으로 보면 이미 보낸 글자가 되풀이되므로,
  /// 커서 앞의 글에서 아직 안 보낸 부분만 보낸다.
  late String _sentText = _initEditingState.text;

  /// 편집 상태를 비우라고 엔진에 요청했고 아직 반영된 것을 못 본 상태. 그동안 오는 글은 이전 글을 포함할 수 있다.
  bool _resetPending = false;

  void _resetSent() => _sentText = _initEditingState.text;

  /// 보낸 글을 기억하며 되풀이를 막는 처리는 Windows 한글 IME 때문에 넣은 것이다.
  bool get _trackSentText => defaultTargetPlatform == TargetPlatform.windows;

  /// macOS 한글 IME는 편집 상태가 비어 있으면 글자를 따로따로 확정해서(ㅎ, ㅏ, ㄴ) 보내고, 글이 남아 있으면 앞 글자와 이어 쓴다
  /// (조합 표시(setMarkedText) 또는 앞 글자를 바꿔 달라는 insertText + replacementRange: ㅎ → 하 → 한). 그래서 한글이 이어지는
  /// 동안은 편집 상태를 비우지 않고, 확정된 글 중 바뀐 부분만 터미널로 보낸다(바뀌면 백스페이스 + 새 글).
  bool get _macImeMode => defaultTargetPlatform == TargetPlatform.macOS;

  /// macOS: 엔진 편집 상태에 남겨 둔 글(이미 터미널로 보낸 것).
  String _macText = '';

  DateTime? _macBackspaceAt;
  String _macBackspaceComposing = '';

  /// macOS: 한글을 쓰는 중이라 편집 상태에 글이 남아 있다. 이때 Backspace는 IME가 처리해야 한다.
  bool get imeBufferActive => _macImeMode && _macText.isNotEmpty;

  /// macOS: 한글 입력이 끝났을 때(공백·영문·Enter·방향키 등) 편집 상태를 비워서, IME가 앞 글자와 이어 쓰지 않게 한다.
  void resetImeBuffer() {
    if (!_macImeMode || _macText.isEmpty) return;
    _macText = '';
    _connection?.setEditingState(_initEditingState);
  }

  /// macOS: 한글 쓰는 중의 Backspace를 IME에 넘긴 뒤 부른다. IME가 글을 고치면(자모 하나 지움 등) 그 결과가 입력으로 들어오지만,
  /// 고칠 조합이 없으면(자음 하나만 남은 때 등) 아무 일도 없거나 같은 글이 다시 온다. 잠시 기다려도 글이 그대로면 우리가 직접
  /// 한 글자를 지운다.
  void backspaceFallback() {
    if (!_macImeMode) return;
    final before = _macText;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || _macText != before) return;
      widget.onDelete();
      resetImeBuffer();
    });
  }

  static bool _isHangul(int r) =>
      (r >= 0x1100 && r <= 0x11FF) ||
      (r >= 0x3130 && r <= 0x318F) ||
      (r >= 0xA960 && r <= 0xA97F) ||
      (r >= 0xAC00 && r <= 0xD7FF);

  void _updateEditingValueMac(TextEditingValue value) {
    _currentEditingState = value;
    widget.onComposing(null);

    final text = value.text;

    // 조합 중이던 글이 Backspace 직후 그대로 확정돼 왔다면 지운 것이다(위 _onKeyEvent 설명). 입력으로 보내지 않고 글을 비운다.
    final bsAt = _macBackspaceAt;
    if (bsAt != null) {
      _macBackspaceAt = null;
      if (DateTime.now().difference(bsAt) < const Duration(milliseconds: 300) &&
          _macBackspaceComposing.isNotEmpty &&
          text == _macText + _macBackspaceComposing) {
        _macText = '';
        _connection?.setEditingState(_initEditingState);
        return;
      }
    }

    final prev = _macText;
    var p = 0;
    final n = prev.length < text.length ? prev.length : text.length;
    while (p < n && prev.codeUnitAt(p) == text.codeUnitAt(p)) {
      p++;
    }
    // 서로게이트 쌍 가운데서 자르지 않는다.
    if (p > 0 &&
        p < prev.length &&
        prev.codeUnitAt(p - 1) >= 0xD800 &&
        prev.codeUnitAt(p - 1) <= 0xDBFF) p--;

    for (var i = prev.substring(p).runes.length; i > 0; i--) {
      widget.onDelete();
    }
    final added = text.substring(p);
    if (added.isNotEmpty) widget.onInsert(added);
    _macText = text;

    if (text.isEmpty || !_isHangul(text.runes.last)) {
      _macText = '';
      _connection?.setEditingState(_initEditingState);
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (!_trackSentText) {
      if (_macImeMode && value.composing.isCollapsed)
        return _updateEditingValueMac(value);
      return _updateEditingValueSimple(value);
    }
    _currentEditingState = value;
    final base = _initEditingState.text.length;
    final caret = value.selection.isValid
        ? value.selection.end.clamp(0, value.text.length)
        : value.text.length;
    final text =
        value.text.substring(0, caret); // 커서 뒤는 쓰지 않는다 (엔진이 되풀이해서 붙이기도 한다)

    // 비우기 요청이 반영돼서 이전 글을 더 이상 포함하지 않는다.
    if (_resetPending && !text.startsWith(_sentText)) {
      _resetPending = false;
      _resetSent();
    }

    if (!value.composing.isCollapsed) {
      // 조합 중: 조합 앞에 확정된 글이 아직 안 보낸 것이면 먼저 보낸다.
      if (!text.startsWith(_sentText)) _resetSent();
      final start = value.composing.start.clamp(0, text.length);
      if (start > _sentText.length) {
        widget.onInsert(text.substring(_sentText.length, start));
        _sentText = text.substring(0, start);
      }
      widget.onComposing(value.composing.textInside(value.text));
      return;
    }

    widget.onComposing(null);

    if (text.length < base) {
      widget.onDelete();
      _resetSent();
    } else if (text.startsWith(_sentText)) {
      if (text.length > _sentText.length) {
        widget.onInsert(text.substring(_sentText.length));
        _sentText = text;
      }
    } else if (_sentText.startsWith(text)) {
      // 보낸 글이 줄었다. 지우기 감지를 쓸 때만 지우기로 알린다 (아니면 Backspace는 키 이벤트로 이미 갔다).
      if (widget.deleteDetection) widget.onDelete();
      _sentText = text;
    } else {
      // 엔진의 글이 우리가 보낸 것과 이어지지 않는다: 새로 시작한 글로 본다.
      _resetSent();
      if (text.length > base) widget.onInsert(text.substring(base));
      _sentText = text;
    }

    // 편집 상태를 비우지 않는다: 확정하자마자 다음 글자 조합이 시작되는 Windows 한글 IME에서는 그 사이에 비우면 엔진이
    // 조합 범위를 잃어서 이후 글자가 조합 중인 값 대신 확정된 값으로 쏟아져 들어온다 (한그글으을…). 글이 너무 길어졌을 때만,
    // 그것도 끝이 영문·숫자·공백이라 조합이 끝나 있을 때 비운다.
    if (text.length > _maxEditingLength && text.runes.last < 0x80) {
      _connection?.setEditingState(_initEditingState);
      _resetPending = true;
    }
  }

  static const _maxEditingLength = 500;

  /// 원래 방식(조합 표시가 있는 IME): 조합이 끝나면 새로 생긴 글만 보내고 편집 상태를 비운다.
  void _updateEditingValueSimple(TextEditingValue value) {
    _currentEditingState = value;

    if (!value.composing.isCollapsed) {
      widget.onComposing(value.composing.textInside(value.text));
      return;
    }

    widget.onComposing(null);

    if (value.text.length < _initEditingState.text.length) {
      widget.onDelete();
    } else {
      widget.onInsert(value.text.substring(_initEditingState.text.length));
    }

    if (value.text != _initEditingState.text) {
      _connection?.setEditingState(_initEditingState);
    }
  }

  @override
  void performAction(TextInputAction action) {
    // print('performAction $action');
    widget.onAction(action);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print('updateFloatingCursor $point');
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // print('showAutocorrectionPromptRect');
  }

  @override
  void connectionClosed() {
    // print('connectionClosed');
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // print('performPrivateCommand $action');
  }

  @override
  void insertTextPlaceholder(Size size) {
    // print('insertTextPlaceholder');
  }

  @override
  void removeTextPlaceholder() {
    // print('removeTextPlaceholder');
  }

  @override
  void showToolbar() {
    // print('showToolbar');
  }
}
