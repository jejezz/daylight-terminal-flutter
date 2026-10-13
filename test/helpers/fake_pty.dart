import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/services/pty_backend.dart';

/// 네이티브 flutter_pty 없이 로컬 셸 세션을 테스트하기 위한 가짜 pty.
/// 입력으로 들어온 바이트는 [written]에 쌓이고, [emit]으로 셸이 내보내는 출력을 흉내 낸다.
class FakePty implements PtyProcess {
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<int>();
  final List<int> written = [];
  final List<(int rows, int cols)> resizes = [];
  bool killed = false;

  /// 입력이 들어올 때마다 불리는 훅 — 셸이 명령에 반응하는 것을 흉내 낼 때 쓴다.
  void Function(String input)? onInput;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  String get writtenText => utf8.decode(written, allowMalformed: true);

  void emit(String text) => _output.add(Uint8List.fromList(utf8.encode(text)));

  void emitBytes(List<int> bytes) => _output.add(Uint8List.fromList(bytes));

  void finish([int code = 0]) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  void write(Uint8List data) {
    written.addAll(data);
    onInput?.call(utf8.decode(data, allowMalformed: true));
  }

  @override
  void resize(int rows, int columns) => resizes.add((rows, columns));

  @override
  void kill() {
    killed = true;
    finish(-1);
  }
}

/// [FakePty]를 만들어 [made]에 모으는 팩토리.
class FakePtyFactory {
  final List<FakePty> made = [];
  final List<({LocalShell shell, String cwd, Map<String, String> env, int rows, int cols})> calls = [];
  Object? failWith;

  FakePty get last => made.last;

  PtyProcess call(
    LocalShell shell, {
    required String workingDirectory,
    required Map<String, String> environment,
    required int rows,
    required int columns,
  }) {
    if (failWith != null) throw failWith!;
    calls.add((shell: shell, cwd: workingDirectory, env: environment, rows: rows, cols: columns));
    final pty = FakePty();
    made.add(pty);
    return pty;
  }
}
