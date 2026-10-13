import 'package:flutter/foundation.dart';

enum TransferDirection { upload, download }

enum TransferStatus { running, done, failed }

/// 진행 중이거나 끝난 파일 전송 하나 (폴더면 안의 모든 파일을 합친 값).
class Transfer extends ChangeNotifier {
  Transfer(this.name, this.direction);

  final String name;
  final TransferDirection direction;

  int total = 0;
  int done = 0;
  TransferStatus status = TransferStatus.running;
  String? error;

  double? get progress => total == 0 ? null : (done / total).clamp(0.0, 1.0);

  void update({int? addTotal, int? setDone}) {
    if (addTotal != null) total += addTotal;
    if (setDone != null) done = setDone;
    notifyListeners();
  }

  void finish([Object? failure]) {
    status = failure == null ? TransferStatus.done : TransferStatus.failed;
    error = failure?.toString();
    notifyListeners();
  }
}
