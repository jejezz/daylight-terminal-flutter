import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/remote_text_file.dart';
import '../services/sender_file.dart';
import '../widgets/highlight_controller.dart';

/// 편집기 칸에 열려 있는 파일 하나. 이미 있는 파일(서버 또는 이 PC)이거나, 아직 저장하지 않은 새 파일([isNew])이다.
class EditorDocument extends ChangeNotifier {
  EditorDocument(RemoteTextFile file, {p.Context? context})
    : _file = file,
      number = 0,
      suggestedName = null,
      pathContext = context ?? p.posix,
      _newBase = const SenderDocument('', '\n'),
      text = HighlightController(text: file.document.text),
      _savedText = file.document.text {
    text.fileName = pathContext.basename(file.path);
    text.addListener(_onText);
  }

  /// 아직 저장하지 않은 새 파일. [number]는 "제목 없음 N"에 쓰는 번호다. [initial]을 주면 그 내용으로 시작하고(이 PC에서
  /// 끌어놓은 파일), [suggestedName]은 처음 저장할 때 제안할 파일 이름이자 색 입히기의 기준이다.
  EditorDocument.untitled(this.number, {SenderDocument? initial, this.suggestedName, p.Context? context})
    : _file = null,
      pathContext = context ?? p.posix,
      _newBase = initial ?? const SenderDocument('', '\n'),
      text = HighlightController(text: initial?.text ?? ''),
      _savedText = '' {
    text.fileName = suggestedName;
    _modified = text.text != _savedText;
    text.addListener(_onText);
  }

  RemoteTextFile? _file;

  /// 이 파일이 있는 파일 시스템의 경로 규칙 (서버는 posix, Windows의 이 PC는 `\` 경로).
  final p.Context pathContext;

  /// 새 파일의 번호 (이미 있는 파일은 0).
  final int number;

  /// 새 파일을 처음 저장할 때 제안할 파일 이름 (끌어놓은 파일의 이름 등). 없으면 null.
  final String? suggestedName;
  final SenderDocument _newBase;
  final HighlightController text;
  String _savedText;
  bool _saving = false;
  bool _modified = false;

  /// 서버에서 이 파일이 바뀐 것이 확인되어 사용자의 결정을 기다리는 중.
  bool conflict = false;

  /// 경로. 새 파일은 처음 저장하기 전까지 null.
  String? get path => _file?.path;
  bool get isNew => _file == null;
  SenderDocument get baseDocument => _file?.document ?? _newBase;
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
    final target = path ?? _file!.path;
    final base = baseDocument;
    _file = RemoteTextFile(target, SenderDocument(savedText, base.eol, bom: base.bom), stat);
    text.fileName = pathContext.basename(target); // 이름이 바뀌면 강조 종류도 바뀔 수 있다
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

/// 한 탭의 편집기 칸: 열린 파일들과 보이기/숨기기. SSH 탭은 서버 파일을(SFTP), 로컬 셸·시리얼 탭은 이 PC의 파일을 편집한다.
class RemoteEditorController extends ChangeNotifier {
  /// [directory]는 새 파일을 저장할 때 처음 제안할 폴더 (보통 탐색기가 보는 폴더). [local]은 이 PC의 파일을 편집하는
  /// 편집기인가 — 파일을 끌어놓으면 서버용은 새 파일로(저장할 때 서버 경로를 묻는다), 로컬용은 그 파일을 바로 연다.
  /// [context]는 경로 규칙이다 (기본 posix).
  RemoteEditorController(this._fs, {this.directory, this.local = false, p.Context? context})
    : pathContext = context ?? p.posix;

  /// 지금 연결의 파일 계층. 연결이 없으면 null.
  final RemoteFs? Function() _fs;
  final String? Function()? directory;
  final bool local;
  final p.Context pathContext;

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

  /// 새 파일을 저장할 때 처음 제안할 폴더.
  String get suggestedDirectory => directory?.call() ?? (local ? Directory.current.path : '/');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 같은 파일인가 (Windows는 대소문자와 `/`·`\` 차이를 무시한다).
  bool _same(String? a, String b) => a != null && pathContext.canonicalize(a) == pathContext.canonicalize(b);

  /// 파일 [path]를 연다. 이미 열려 있으면 그 파일로 옮겨 가기만 한다. 열 수 없으면 [RemoteEditException].
  Future<EditorDocument> open(String path) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    // 이미 열린 파일은 다시 받지 않는다 — 편집 중인 내용을 덮어쓰지 않도록. 링크 경로로 다시 열려는 경우도 실제 경로로 맞춘다.
    for (final (i, d) in _docs.indexed) {
      if (_same(d.path, path)) return _show(i);
    }
    final file = await RemoteText.open(fs, path);
    for (final (i, d) in _docs.indexed) {
      if (_same(d.path, file.path)) return _show(i);
    }
    final doc = EditorDocument(file, context: pathContext)..addListener(_notify);
    _docs.add(doc);
    return _show(_docs.length - 1);
  }

  /// 새 파일을 만든다 (저장할 때 경로를 묻는다). [initial]을 주면 그 내용으로 시작한다.
  EditorDocument newDocument({SenderDocument? initial, String? suggestedName}) {
    final doc = EditorDocument.untitled(++_untitledCount, initial: initial, suggestedName: suggestedName, context: pathContext)
      ..addListener(_notify);
    _docs.add(doc);
    return _show(_docs.length - 1);
  }

  /// 이 PC의 파일 [localPath]의 내용을 새 파일로 연다 (서버 편집기에 이 PC의 파일을 끌어놓았을 때). 저장하면 서버 경로를
  /// 묻고, 제안하는 이름은 원래 파일 이름이다. 열 수 없는 파일(UTF-8 텍스트가 아님, 2MB 초과, 바이너리, 폴더)은
  /// [RemoteEditException].
  Future<EditorDocument> openLocalFileAsNew(String localPath) async {
    final SenderDocument doc;
    try {
      final file = File(localPath);
      if (await FileSystemEntity.isDirectory(localPath)) {
        throw RemoteEditException(RemoteEditError.notRegular, localPath);
      }
      if (await file.length() > SenderFile.maxBytes) throw const RemoteEditException(RemoteEditError.tooLarge);
      doc = RemoteText.decodeText(await file.readAsBytes());
    } on RemoteEditException {
      rethrow;
    } on FileSystemException catch (e) {
      throw RemoteEditException(RemoteEditError.io, e.message);
    }
    return newDocument(initial: doc, suggestedName: p.basename(localPath));
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

  /// [doc]을 저장한다. 그사이 디스크(서버)에서 바뀌었으면 저장하지 않고 [RemoteSaveStatus.conflict]를 돌려주며
  /// [EditorDocument.conflict]를 켠다. [overwrite]이면 그래도 덮어쓴다. [backup]이면 `.bak`에 이전 내용을 남긴다. 연결이
  /// 없거나 쓰기가 실패하면 던진다. 경로가 아직 없는 새 파일은 [saveAs]로 저장한다.
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

  /// [doc]을 [path]에 저장한다 (새 파일의 첫 저장, 또는 다른 이름으로 저장). 그 경로에 이미 파일이 있으면
  /// [overwrite]가 아닌 한 쓰지 않고 [RemoteSaveStatus.conflict]를 돌려준다. 저장되면 [doc]은 그 경로의 파일이 된다.
  Future<RemoteSaveResult> saveAs(EditorDocument doc, String path, {bool overwrite = false}) async {
    final fs = _fs();
    if (fs == null) throw const RemoteEditException(RemoteEditError.io, 'not connected');
    if (doc.saving) return const RemoteSaveResult.conflict();
    if (_docs.any((d) => d != doc && _same(d.path, path))) {
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

  /// 충돌했을 때: 디스크(서버)의 현재 내용으로 다시 채운다 (내가 고친 것은 버려진다).
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
