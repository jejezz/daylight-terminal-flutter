import 'package:dartssh2/dartssh2.dart';

/// 암호 우선순위: dartssh2는 암호화를 순수 Dart로 해서 알고리즘마다 속도 차이가 크다.
/// 기본값은 AES-GCM을 맨 앞에 두는데, 이것이 loopback에서 1.6MB/s밖에 안 나왔다
/// (같은 조건에서 chacha20-poly1305 36MB/s, aes-ctr 13~15MB/s). 빠른 것부터 협상하고,
/// 서버가 지원하지 않으면 다음 것으로 넘어간다 (모두 안전한 알고리즘이다).
const fastSshAlgorithms = SSHAlgorithms(
  cipher: [
    SSHCipherType.chacha20poly1305,
    SSHCipherType.aes128ctr,
    SSHCipherType.aes256ctr,
    SSHCipherType.aes128gcm,
    SSHCipherType.aes256gcm,
  ],
);
