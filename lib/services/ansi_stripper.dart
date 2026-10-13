/// 터미널 출력에서 이스케이프 시퀀스(색, 커서 이동, OSC 등)를 걷어낸다.
/// 청크 경계에서 시퀀스가 잘려도 새어 나오지 않게, 끝이 불완전하면 다음 청크로 넘긴다.
class AnsiStripper {
  static final _complete = RegExp(
    r'\x1B\[[0-?]*[ -/]*[@-~]' // CSI
    r'|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)' // OSC
    r'|\x1B[PX^_][^\x1B]*\x1B\\' // DCS/SOS/PM/APC
    r'|\x1B[@-OQ-WYZ\\]' // 2바이트 (CSI `[`, OSC `]`, DCS 등 문자열을 여는 P X ^ _ 는 위에서 따로 처리)
    r'|\x1B[ -/]+[0-~]', // nF
  );

  String _carry = '';

  String strip(String chunk) {
    var text = _carry + chunk;
    _carry = '';
    text = text.replaceAll(_complete, '');
    // 끝에 미완성 시퀀스가 남았으면 보류한다.
    final esc = text.lastIndexOf('\x1B');
    if (esc != -1 && text.length - esc < 256) {
      _carry = text.substring(esc);
      text = text.substring(0, esc);
    }
    return text;
  }
}
