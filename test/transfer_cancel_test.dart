import 'package:daylight_terminal/models/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel: only a running transfer with a stop handler, once; then finishCancelled', () {
    final t = Transfer('a.bin', TransferDirection.upload);
    expect(t.cancellable, isFalse); // 멈추는 방법이 없으면(다운로드) 취소할 수 없다
    var stopped = 0;
    t.onCancel = () => stopped++;
    expect(t.cancellable, isTrue);
    t.cancel();
    t.cancel();
    expect((stopped, t.cancelRequested, t.cancellable, t.status), (1, true, false, TransferStatus.running));
    t.finishCancelled();
    expect(t.status, TransferStatus.cancelled);
  });
}
