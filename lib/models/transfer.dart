import 'package:flutter/foundation.dart';

enum TransferDirection { upload, download }

enum TransferStatus { running, done, failed, cancelled }

/// 진행 중이거나 끝난 파일 전송 하나 (폴더면 안의 모든 파일을 합친 값).
class Transfer extends ChangeNotifier {
  Transfer(this.name, this.direction);

  final String name;
  final TransferDirection direction;

  int total = 0;
  int done = 0;
  TransferStatus status = TransferStatus.running;
  String? error;

  /// 취소를 요청했다. 실제로 멈출 때까지는 [status]가 그대로 running이다.
  bool cancelRequested = false;

  /// 취소할 수 있는 전송이면 멈추는 동작이 들어 있다 (업로드만).
  void Function()? onCancel;

  bool get cancellable => status == TransferStatus.running && !cancelRequested && onCancel != null;

  double? get progress => total == 0 ? null : (done / total).clamp(0.0, 1.0);

  final Stopwatch _clock = Stopwatch()..start();
  int _sampleMs = 0;
  int _sampleDone = 0;
  double _speed = 0;

  /// 최근 전송 속도(바이트/초, 지수 평균). 아직 모르면 0.
  double get bytesPerSecond => status == TransferStatus.running ? _speed : 0;

  /// 화면에 보일 속도 글 (예: `12.3 MB/s`). 아직 모르면 null.
  String? get speedLabel {
    final v = bytesPerSecond;
    if (v <= 0) return null;
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var x = v;
    var i = 0;
    while (x >= 1024 && i < units.length - 1) {
      x /= 1024;
      i++;
    }
    return '${x.toStringAsFixed(i == 0 || x >= 100 ? 0 : 1)} ${units[i]}';
  }

  void _sample() {
    final now = _clock.elapsedMilliseconds;
    final dt = now - _sampleMs;
    if (dt < 500) return;
    if (_sampleMs == 0 && _sampleDone == 0 && done == 0) return;
    final inst = (done - _sampleDone) * 1000 / dt;
    _speed = _speed == 0 ? inst : _speed * 0.6 + inst * 0.4;
    _sampleMs = now;
    _sampleDone = done;
  }

  void update({int? addTotal, int? setDone}) {
    if (addTotal != null) total += addTotal;
    if (setDone != null) {
      done = setDone;
      _sample();
    }
    notifyListeners();
  }

  void cancel() {
    if (!cancellable) return;
    cancelRequested = true;
    onCancel!();
    notifyListeners();
  }

  void finishCancelled() {
    status = TransferStatus.cancelled;
    notifyListeners();
  }

  void finish([Object? failure]) {
    status = failure == null ? TransferStatus.done : TransferStatus.failed;
    error = failure?.toString();
    notifyListeners();
  }
}
