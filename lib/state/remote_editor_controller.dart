import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/remote_text_file.dart';
import '../services/sender_file.dart';
import '../widgets/highlight_controller.dart';

/// 편집기 칸에 열려 있는 파일 하나. 서버에서 연 파일이거나, 아직 서버에 저장하지 않은 새 파일([isNew])이다.
class EditorDocument extends ChangeNotifier {
  EditorDocument(RemoteTextFile file)
    : _file = file,
      number = 0,
      text = HighlightController(text: file.document.text)..fileName = p.posix.basename(file.path),
      _savedText = file.document.text {
    text.addListener(_onText);
  }

  /// 서버에 아직 없는 새 파일. [number]는 "제목 없음 N"에 쓰는 번호다.
  EditorDocument.untitled(this.number) : _file = null, text = HighlightController(), _savedText = '' {
    text.addListener(_onText);
  }

  RemoteTextFile? _file;

  /// 새 파일의 번호 (서버에서 연 파일은 0).
  final int number;
  final HighlightController text;
  String _savedText;
  bool _saving = false;
  bool _modified = false;

  /// 서버에서 이 파일이 바뀐 것이 확인되어 사용자의 결정을 기다리는 중.
  bool conflict = false;

  /// 서버 경로. 새 파일은 처음 저장하기 전까지 null.
  String? get path => _file?.path;
  bool get isNew => _file == null;
  SenderDocument get baseDocument => _file?.document ?? const SenderDocument('', '\n');
  RemoteTextFile? get file => _file;
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

  /// 저장이 끝났다: 저장한 내용과 서버 상태를 새 기준으로 삼는다. [path]를 주면 (새 파일을 저장했거나 다른 이름으로
  /// 저장했을 때) 그 경로의 파일이 된다.
  void _markSaved(String savedText, RemoteStat stat, {String? path}) {
    final old = _file;
    final target = path ?? old!.path;
    final base = old?.document ?? const SenderDocument('', '\n');
    _file = RemoteTextFile(target, SenderDocument(savedText, base.eol, bom: base.bom), stat);
    text.fileName = p.posix.basename(target); // 이름이 바뀌면 강조 종류도 바뀔 수 있다
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
  /// [directory]는 새 파일을 저장할 때 처음 제안할 서버 폴더 (보통 탐색기가 보는 폴더).
  RemoteEditorController(this._fs, {this.directory});

  /// 지금 연결의 서버 파일 계층. 연결이 없으면 null.
  final RemoteFs? Function() _fs;
  final String? Function()? directory;

  final List<EditorDocument> _docs = [];
  int _current = -1;
  bool _visible = true;
  bool _disposed = false;
  int _untitledCount = 0;

  /// 편집기 칸이 펼쳐져 있는가. 파일이 하나도 없어도 펼쳐져 있다 (사용자가 접었을 때만 접힌다).
  bool get visible => _visible;
  List<EditorDocument> get documents => List.unmodifiable(_docs);
  EditorDocument? get current => _current >= 0 && _current < _docs.length ? _docs[_current] : null;
  bool get hasUnsaved => _docs.any((d) => d.modified);
  List<EditorDocument> get unsaved => [
    for (final d in _docs)
      if (d.modified) d,
  ];

  /// 새 파일을 저장할 때 처음 제안할 서버 폴더.
  String get suggestedDirectory => directory?.call() ?? '/';

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

  /// 서버에 아직 없는 새 파일을 만든다 (저장할 때 서버 경로를 묻는다).
  EditorDocument newDocument() {
    final doc = EditorDocument.untitled(++_untitledCount)..addListener(_notify);
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

  /// 칸 안의 글. 줄바꿈은 LF로 통일해 두었다가 저장할 때 파일의 원래 줄바꿈으로 되돌린다 (붙여 넣은 CRLF도 같이 정리된다).
  static String _normalized(EditorDocument doc) => doc.text.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// [doc]을 저장한다. 서버에서 그사이 바뀌었으면 저장하지 않고 [RemoteSaveStatus.conflict]를 돌려주며 [EditorDocument.conflict]를
  /// 켠다. [overwrite]이면 그래도 덮어쓴다. [backup]이면 `.bak`에 이전 내용을 남긴다. 연결이 없거나 쓰기가 실패하면 던진다.
  /// 서버 경로가 아직 없는 새 파일은 [saveAs]로 저장한다.
  Future<RemoteSaveResult> save(EditorDocument doc, {bool overwrite = false, bool backup = false}) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    final file = doc.file;
    if (file == null) throw const RemoteEditException(RemoteEditError.io, 'no server path yet');
    if (doc.saving) return const RemoteSaveResult.conflict();
    doc._setSaving(true);
    try {
      final base = doc.baseDocument;
      final result = await RemoteText.save(
        fs,
        file,
        SenderDocument(_normalized(doc), base.eol, bom: base.bom),
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

  /// [doc]을 서버의 [path]에 저장한다 (새 파일의 첫 저장, 또는 다른 이름으로 저장). 그 경로에 이미 파일이 있으면
  /// [overwrite]가 아닌 한 쓰지 않고 [RemoteSaveStatus.conflict]를 돌려준다. 저장되면 [doc]은 그 경로의 파일이 된다.
  Future<RemoteSaveResult> saveAs(EditorDocument doc, String path, {bool overwrite = false}) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    if (doc.saving) return const RemoteSaveResult.conflict();
    if (_docs.any((d) => d != doc && d.path == path)) {
      throw RemoteEditException(RemoteEditError.alreadyOpen, path);
    }
    doc._setSaving(true);
    try {
      final base = doc.baseDocument;
      final result = await RemoteText.saveNew(
        fs,
        path,
        SenderDocument(_normalized(doc), base.eol, bom: base.bom),
        overwrite: overwrite,
      );
      if (result.status == RemoteSaveStatus.saved) doc._markSaved(doc.text.text, result.stat!, path: path);
      return result;
    } finally {
      doc._setSaving(false);
    }
  }

  /// 충돌했을 때: 서버의 현재 내용으로 다시 채운다 (내가 고친 것은 버려진다).
  Future<void> reload(EditorDocument doc) async {
    final fs = _fs();
    final path = doc.path;
    if (fs == null || path == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    doc._replaceWith(await RemoteText.open(fs, path));
  }

  /// [doc]을 닫는다. 저장하지 않은 변경을 묻는 것은 부른 쪽의 몫이다. 마지막 파일을 닫아도 칸은 펼쳐진 채로 남는다.
  void close(EditorDocument doc) {
    final i = _docs.indexOf(doc);
    if (i == -1) return;
    _docs.removeAt(i);
    doc.removeListener(_notify);
    doc.dispose();
    if (_docs.isEmpty) {
      _current = -1;
    } else if (_current >= _docs.length) {
      _current = _docs.length - 1;
    } else if (i < _current) {
      _current--;
    }
    _notify();
  }

  /// 모든 파일을 닫는다 (다른 서버에 접속할 때).
  void closeAll() {
    for (final d in _docs) {
      d.removeListener(_notify);
      d.dispose();
    }
    _docs.clear();
    _current = -1;
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
