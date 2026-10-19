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

  @override
  void updateEditingValue(TextEditingValue value) {
    _currentEditingState = value;
    final base = _initEditingState.text.length;
    final caret = value.selection.isValid ? value.selection.end.clamp(0, value.text.length) : value.text.length;
    final text = value.text.substring(0, caret); // 커서 뒤는 쓰지 않는다 (엔진이 되풀이해서 붙이기도 한다)

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
