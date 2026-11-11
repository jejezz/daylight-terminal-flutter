import 'package:flutter/material.dart';

import '../services/remote_text_file.dart';
import '../services/sender_file.dart';

/// 편집기 칸에 열려 있는 서버 파일 하나.
class EditorDocument extends ChangeNotifier {
  EditorDocument(RemoteTextFile file)
    : _file = file,
      text = TextEditingController(text: file.document.text),
      _savedText = file.document.text {
    text.addListener(_onText);
  }

  RemoteTextFile _file;
  final TextEditingController text;
  String _savedText;
  bool _saving = false;
  bool _modified = false;

  /// 서버에서 이 파일이 바뀐 것이 확인되어 사용자의 결정을 기다리는 중.
  bool conflict = false;

  String get path => _file.path;
  SenderDocument get baseDocument => _file.document;
  RemoteTextFile get file => _file;
  bool get saving => _saving;
  bool get modified => _modified;

  void _onText() {
    final m = text.text != _savedText;
    if (m != _modified) {
      _modified = m;
      notifyListeners();
    }
  }

  void _setSaving(bool v) {
    _saving = v;
    notifyListeners();
  }

  /// 저장이 끝났다: 저장한 내용과 서버 상태를 새 기준으로 삼는다.
  void _markSaved(String savedText, RemoteStat stat) {
    _file = RemoteTextFile(_file.path, SenderDocument(savedText, _file.document.eol, bom: _file.document.bom), stat);
    _savedText = savedText;
    conflict = false;
    _modified = text.text != _savedText;
    notifyListeners();
  }

  /// 서버의 내용으로 다시 채운다 (충돌했을 때 "서버 버전 불러오기").
  void _replaceWith(RemoteTextFile file) {
    _file = file;
    _savedText = file.document.text;
    conflict = false;
    text.value = TextEditingValue(text: file.document.text);
    _modified = false;
    notifyListeners();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// 한 탭(서버 연결 하나)의 편집기 칸: 열린 파일들과 보이기/숨기기.
class RemoteEditorController extends ChangeNotifier {
  RemoteEditorController(this._fs);

  /// 지금 연결의 서버 파일 계층. 연결이 없으면 null.
  final RemoteFs? Function() _fs;

  final List<EditorDocument> _docs = [];
  int _current = -1;
  bool _visible = false;
  bool _disposed = false;

  /// 사용자가 편집기 칸을 접었는가 (열린 파일은 그대로다).
  bool get visible => _visible && _docs.isNotEmpty;
  List<EditorDocument> get documents => List.unmodifiable(_docs);
  EditorDocument? get current => _current >= 0 && _current < _docs.length ? _docs[_current] : null;
  bool get hasUnsaved => _docs.any((d) => d.modified);
  List<EditorDocument> get unsaved => [
    for (final d in _docs)
      if (d.modified) d,
  ];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 서버 파일 [path]를 연다. 이미 열려 있으면 그 파일로 옮겨 가기만 한다. 열 수 없으면 [RemoteEditException].
  Future<EditorDocument> open(String path) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    // 이미 열린 파일은 다시 받지 않는다 — 편집 중인 내용을 덮어쓰지 않도록. 링크 경로로 다시 열려는 경우도 실제 경로로 맞춘다.
    for (final (i, d) in _docs.indexed) {
      if (d.path == path) return _show(i);
    }
    final file = await RemoteText.open(fs, path);
    for (final (i, d) in _docs.indexed) {
      if (d.path == file.path) return _show(i);
    }
    final doc = EditorDocument(file)..addListener(_notify);
    _docs.add(doc);
    return _show(_docs.length - 1);
  }

  EditorDocument _show(int index) {
    _current = index;
    _visible = true;
    _notify();
    return _docs[index];
  }

  void select(EditorDocument doc) {
    final i = _docs.indexOf(doc);
    if (i == -1) return;
    _current = i;
    _notify();
  }

  void setVisible(bool v) {
    if (_visible == v) return;
    _visible = v;
    _notify();
  }

  /// [doc]을 저장한다. 서버에서 그사이 바뀌었으면 저장하지 않고 [RemoteSaveStatus.conflict]를 돌려주며 [EditorDocument.conflict]를
  /// 켠다. [overwrite]이면 그래도 덮어쓴다. [backup]이면 `.bak`에 이전 내용을 남긴다. 연결이 없거나 쓰기가 실패하면 던진다.
  Future<RemoteSaveResult> save(EditorDocument doc, {bool overwrite = false, bool backup = false}) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    if (doc.saving) return const RemoteSaveResult.conflict();
    doc._setSaving(true);
    try {
      // 칸 안에서는 줄바꿈을 LF로 통일해 두었다가 저장할 때 파일의 원래 줄바꿈으로 되돌린다 (붙여 넣은 CRLF도 같이 정리된다).
      final text = doc.text.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final base = doc.baseDocument;
      final result = await RemoteText.save(
        fs,
        doc.file,
        SenderDocument(text, base.eol, bom: base.bom),
        overwrite: overwrite,
        backup: backup,
      );
      if (result.status == RemoteSaveStatus.saved) {
        doc._markSaved(doc.text.text, result.stat!);
      } else {
        doc.conflict = true;
      }
      return result;
    } finally {
      doc._setSaving(false);
    }
  }

  /// 충돌했을 때: 서버의 현재 내용으로 다시 채운다 (내가 고친 것은 버려진다).
  Future<void> reload(EditorDocument doc) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    doc._replaceWith(await RemoteText.open(fs, doc.path));
  }

  /// [doc]을 닫는다. 저장하지 않은 변경을 묻는 것은 부른 쪽의 몫이다.
  void close(EditorDocument doc) {
    final i = _docs.indexOf(doc);
    if (i == -1) return;
    _docs.removeAt(i);
    doc.removeListener(_notify);
    doc.dispose();
    if (_docs.isEmpty) {
      _current = -1;
      _visible = false;
    } else if (_current >= _docs.length) {
      _current = _docs.length - 1;
    } else if (i < _current) {
      _current--;
    }
    _notify();
  }

  /// 모든 파일을 닫는다 (연결이 끝났을 때).
  void closeAll() {
    for (final d in _docs) {
      d.removeListener(_notify);
      d.dispose();
    }
    _docs.clear();
    _current = -1;
    _visible = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final d in _docs) {
      d.removeListener(_notify);
      d.dispose();
    }
    _docs.clear();
    super.dispose();
  }
}
