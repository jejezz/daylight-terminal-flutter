import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// 가끔만 나타나는 "버튼이 안 눌린다" 같은 문제를 나중에 가려내기 위한 가벼운 진단 기록.
///
/// 파일 이름·경로·입력 내용은 남기지 않고 동작 종류와 시간만 남긴다. 로컬 파일 하나에만 쓰고(크기 제한,
/// 넘으면 이전 것을 `.1`로 밀어낸다) 어디로도 보내지 않는다. [init]을 부르기 전에는 아무것도 하지 않는다
/// (테스트는 init을 부르지 않는다).
///
/// 한 줄: `시각 +앱 시작 뒤 경과초 사건`. 클릭이 들어왔는지(`pointer down`), 화면이 반응했는지(`ui.*`),
/// 처리가 끝났는지(`… done`/`… still running`), 앱이 멈췄는지(`event loop stall`/`slow frame`)를 본다.
class DiagLog {
  DiagLog._(this._file, this._maxBytes, this._clock) {
    _size = _file.existsSync() ? _file.lengthSync() : 0;
  }

  static DiagLog? _instance;
  static bool get enabled => _instance != null;

  final File _file;
  final int _maxBytes;
  final Stopwatch _clock;
  int _size = 0;

  /// 운영체제별 기록 폴더. macOS는 `~/Library/Logs/Daylight Terminal`.
  static Directory defaultDirectory({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? Directory.systemTemp.path;
    if (Platform.isMacOS) return Directory(p.join(home, 'Library', 'Logs', 'Daylight Terminal'));
    if (Platform.isWindows) {
      return Directory(p.join(env['LOCALAPPDATA'] ?? p.join(home, 'AppData', 'Local'), 'Daylight Terminal', 'logs'));
    }
    return Directory(p.join(env['XDG_STATE_HOME'] ?? p.join(home, '.local', 'state'), 'daylight-terminal'));
  }

  /// 기록을 시작한다. 실패해도 앱을 방해하지 않는다. [directory]는 테스트에서만 바꾼다.
  static Future<void> init({required String version, Directory? directory, int maxBytes = 512 * 1024}) async {
    try {
      final dir = directory ?? defaultDirectory();
      await dir.create(recursive: true);
      _instance = DiagLog._(File(p.join(dir.path, 'diagnostics.log')), maxBytes, Stopwatch()..start());
      log('start version=$version os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (e) {
      _instance = null;
      debugPrint('DiagLog init failed: $e');
    }
  }

  /// 테스트가 만든 기록을 정리한다.
  @visibleForTesting
  static void reset() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _instance = null;
  }

  static String? get path => _instance?._file.path;

  static void log(String event) => _instance?._write(event);

  /// 오래 걸릴 수 있는 일의 시작을 남기고, 끝났을 때 부를 함수를 돌려 준다.
  /// [slow]가 지나도 안 끝나면 `still running`을 한 번 남긴다 (끝나지 않는 일을 알아보려는 것).
  static void Function() begin(String name, {Duration slow = const Duration(seconds: 3)}) {
    final i = _instance;
    if (i == null) return () {};
    final watch = Stopwatch()..start();
    i._write('$name start');
    final timer = Timer(slow, () => i._write('$name still running ${watch.elapsedMilliseconds}ms'));
    return () {
      timer.cancel();
      i._write('$name done ${watch.elapsedMilliseconds}ms');
    };
  }

  void _write(String event) {
    try {
      final now = DateTime.now();
      final line = '${now.toIso8601String()} +${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s $event\n';
      if (_size + line.length > _maxBytes) {
        _file.renameSync('${_file.path}.1'); // 이전 것은 하나만 남긴다
        _size = 0;
      }
      _file.writeAsStringSync(line, mode: FileMode.append);
      _size += line.length;
    } catch (_) {
      // 기록 때문에 앱이 영향을 받으면 안 된다.
    }
  }

  // ───────────────────────── 자동으로 보는 것 ─────────────────────────

  static Timer? _heartbeat;

  /// 클릭 도착, 화면 활성·비활성, 이벤트 루프 멈춤, 느린 프레임을 자동으로 남긴다. [init] 뒤에 한 번 부른다.
  static void watch() {
    if (!enabled) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) log('pointer down buttons=${event.buttons} kind=${event.kind.name}');
    });
    WidgetsBinding.instance.addObserver(_Lifecycle());
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        if (t.totalSpan > const Duration(milliseconds: 250)) {
          log(
            'slow frame total=${t.totalSpan.inMilliseconds}ms build=${t.buildDuration.inMilliseconds}ms '
            'raster=${t.rasterDuration.inMilliseconds}ms',
          );
        }
      }
    });
    // 0.5초마다 깨어나는 타이머가 1.5초 넘게 밀리면 Dart 쪽이 그만큼 막혀 있었다는 뜻이다.
    var last = DateTime.now();
    _heartbeat = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final now = DateTime.now();
      final gap = now.difference(last).inMilliseconds;
      last = now;
      if (gap > 1500) log('event loop stall ${gap - 500}ms');
    });
  }
}

class _Lifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => DiagLog.log('lifecycle ${state.name}');
}
