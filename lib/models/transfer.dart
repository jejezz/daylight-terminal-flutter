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

  void update({int? addTotal, int? setDone}) {
    if (addTotal != null) total += addTotal;
    if (setDone != null) done = setDone;
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
