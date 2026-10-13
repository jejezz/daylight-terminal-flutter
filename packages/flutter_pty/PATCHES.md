# 이 폴더는 flutter_pty 0.4.2의 복사본입니다

Daylight Terminal이 Windows에서 로컬 셸(PowerShell, cmd, WSL)을 띄우려면 아래 결함을 고쳐야 해서
pub.dev의 원본 대신 이 복사본을 씁니다 (`pubspec.yaml`의 `path:` 의존성). 원본 라이선스(MIT)는
[LICENSE](LICENSE)에 그대로 있습니다. 고친 곳은 모두 `src/flutter_pty_win.c`이고, macOS/Linux 코드는
원본 그대로입니다.

| 원본 0.4.2의 문제 (Windows) | 증상 | 고친 방법 |
|---|---|---|
| 명령줄에 실행 파일이 두 번 들어간다 (`arguments`가 이미 argv라서 0번이 실행 파일인데 또 붙임) | `wsl.exe -d Ubuntu`가 `command not found`(127)로 끝난다. PowerShell 7은 자기 경로를 스크립트로 실행하려다 실패한다. cmd/Windows PowerShell은 우연히 중첩 실행되어 동작한다 | `arguments[0]`을 건너뛴다 |
| 명령줄·환경 변수·작업 폴더를 `(WCHAR)char`로 한 글자씩 넣는다 | 한글 등 비ASCII 경로(`C:\Users\홍길동\...`)가 깨진다 | `MultiByteToWideChar(CP_UTF8)`로 변환한다 |
| 실행 파일과 인자를 인용하지 않는다 | `C:\Program Files\...`처럼 공백이 든 경로, 공백이 든 인자가 쪼개진다 | `CommandLineToArgvW` 규칙대로 인용한다 |
| `pty_create`가 `Sleep(1000)`을 한다 | 셸을 띄울 때마다 UI 스레드가 1초 멈춘다 | 제거했다 |

원본으로 되돌리거나 새 버전으로 올릴 때는 위 네 가지가 고쳐졌는지 먼저 확인하세요. 고쳐졌다면
이 폴더를 지우고 `pubspec.yaml`을 `flutter_pty: ^x.y.z`로 되돌리면 됩니다.
