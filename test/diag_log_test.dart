import 'dart:io';

import 'package:daylight_terminal/services/diag_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('dt_diag_'));

  tearDown(() async {
    DiagLog.reset();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String read() => File('${dir.path}/diagnostics.log').readAsStringSync();

  test('does nothing before init', () {
    expect(DiagLog.enabled, isFalse);
    DiagLog.log('x');
    DiagLog.begin('job')();
    expect(dir.listSync(), isEmpty);
  });

  test('writes the version first, then events with elapsed time', () async {
    await DiagLog.init(version: '1.2.3+4', directory: dir);
    DiagLog.log('pointer down');
    final lines = read().trim().split('\n');
    expect(lines.first, contains('start version=1.2.3+4'));
    expect(lines.last, matches(RegExp(r'^\S+ \+\d+\.\ds pointer down$')));
  });

  test('begin/done records the job and how long it took', () async {
    await DiagLog.init(version: 'v', directory: dir);
    final done = DiagLog.begin('local.loadFolder');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    done();
    expect(read(), contains('local.loadFolder start'));
    expect(read(), matches(RegExp(r'local\.loadFolder done \d+ms')));
  });

  test('a job that never finishes is reported as still running', () async {
    await DiagLog.init(version: 'v', directory: dir);
    final done = DiagLog.begin('sftp.loadDir', slow: const Duration(milliseconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(read(), matches(RegExp(r'sftp\.loadDir still running \d+ms')));
    done();
  });

  test('keeps only a bounded amount: the old log moves to .1', () async {
    await DiagLog.init(version: 'v', directory: dir, maxBytes: 600);
    for (var i = 0; i < 40; i++) {
      DiagLog.log('event $i');
    }
    expect(File('${dir.path}/diagnostics.log.1').existsSync(), isTrue);
    expect(File('${dir.path}/diagnostics.log').lengthSync(), lessThan(700));
    expect(read(), contains('event 39')); // 최근 것은 남는다
  });

  test('never throws when the folder disappears', () async {
    await DiagLog.init(version: 'v', directory: dir);
    await dir.delete(recursive: true);
    expect(() => DiagLog.log('after delete'), returnsNormally);
  });
}
