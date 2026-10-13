import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

import '../models/local_shell.dart';

/// 로컬 셸이 돌아가는 가상 터미널(pty) 하나. 실제 구현은 flutter_pty(Windows는 ConPTY)이고,
/// 네이티브 라이브러리가 없는 테스트에서는 가짜로 바꿔 끼운다.
abstract class PtyProcess {
  /// 셸이 내보내는 출력 (stdout과 stderr가 합쳐져 있다).
  Stream<Uint8List> get output;

  /// 프로세스가 끝나면 종료 코드로 완료된다.
  Future<int> get exitCode;

  void write(Uint8List data);

  void resize(int rows, int columns);

  void kill();
}

typedef PtyFactory = PtyProcess Function(
  LocalShell shell, {
  required String workingDirectory,
  required Map<String, String> environment,
  required int rows,
  required int columns,
});

/// flutter_pty로 실제 셸을 띄운다. 이 패키지는 환경 변수를 거의 물려주지 않으므로(HOME, PATH 등
/// 몇 개뿐) 호출하는 쪽이 전체 환경을 넘겨야 Windows에서도 셸이 제대로 동작한다.
PtyProcess startFlutterPty(
  LocalShell shell, {
  required String workingDirectory,
  required Map<String, String> environment,
  required int rows,
  required int columns,
}) => _FlutterPtyProcess(
  Pty.start(
    shell.executable,
    arguments: shell.arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    rows: rows,
    columns: columns,
  ),
);

class _FlutterPtyProcess implements PtyProcess {
  _FlutterPtyProcess(this._pty);

  final Pty _pty;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int rows, int columns) => _pty.resize(rows, columns);

  @override
  void kill() => _pty.kill();
}
