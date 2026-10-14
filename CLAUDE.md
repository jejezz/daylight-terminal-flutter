# Daylight Terminal

SSH 터미널과 SFTP 파일 탐색기를 한 창에서 쓰는 데스크톱 앱 (macOS / Windows / Linux, Flutter).
daylight-commander 계열 앱.

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1

## 앱 고유 요구사항

- 하나의 SSH 연결에서 셸 채널과 SFTP 채널을 함께 연다.
- 터미널과 탐색기의 현재 경로는 **자동으로 동기화하지 않는다.**
  사용자가 메뉴로 요청할 때만 이동한다
  ("터미널을 이 폴더로 이동" / "탐색기를 터미널 경로로 이동").
- 파일 업로드·다운로드는 드래그 앤 드롭으로 한다.
- 사용 패키지: dartssh2 (SSH/SFTP), xterm2 (터미널, portside와 동일), desktop_drop (끌어넣기),
  flutter_drag_out (끌어내기), provider (상태), file_selector (저장 대화상자).
- portside-flutter에서 가져온 기능: LineSender(`lib/widgets/line_sender.dart`)와 기록(Recording,
  `lib/services/log_file_service.dart`, `toggleLogging`). SSH에 맞게 줄 끝 기본값은 CR, 로컬 에코는 없음.
  기록 파일은 원본 바이트 또는 이스케이프 제거 텍스트.
- 비밀번호·키 암호는 저장하지 않는다. 호스트 키는 처음 본 것을 신뢰하고(TOFU) 이후 달라지면 거부한다.

## 테스트

- `flutter test`는 서버 없이 돈다. 실제 SSH 서버가 필요한 `test/ssh_e2e_test.dart`,
  `test/ssh_ui_e2e_test.dart`는 `TEST_SSH_PORT`, `TEST_SSH_PASSWORD`(사용자 `tester`, SFTP 루트에 `sub/` 폴더)가
  없으면 건너뛴다. `test/local_pty_e2e_test.dart`는 진짜 셸(ConPTY)로 도는 테스트라 `TEST_PTY=1`과 PATH에 빌드한
  `flutter_pty.dll`이 필요하다 (`flutter build windows --debug` 후 `PATH="$PATH:build/windows/x64/runner/Debug"`).

## 끌어내기 (flutter_drag_out)

- 탐색기 행은 `Draggable`이고, 창 밖으로 나가는 순간 `flutter_drag_out`(git, `v0.5.0`)이 OS 끌기 세션을 연다.
  Ctrl/⌘·Shift로 여러 개를 골라 한꺼번에 끌 수 있다.
- macOS: 파일 프로미스(`DragOutItem.promise`) — 놓는 곳에서 바로 SFTP로 받는다. 미리 받아 두는 것이 없다.
- Windows/Linux: 프로미스가 없어서 끌기를 시작하면 임시 폴더(`DragStaging`)에 로컬 사본을 받고, 창을 벗어났을 때
  다 받아져 있으면 바로, 아니면 받는 동안 마우스를 누르고 있는 경우에만 이어서 `FlutterDragOut.start`를 부른다.
  임시 사본은 다음 끌기를 시작할 때와 앱을 끝낼 때 지운다.
- 이 앱에서 끌어낸 것이 다시 들어오면 업로드하지 않는다 (`FlutterDragOut.inProgress`).

## 주소록과 터미널 글꼴

- 주소록(`address_book_dialog.dart`, Ctrl+Shift+O / ⌘O): 이름·그룹·메모를 붙여 저장하고, 검색·편집·삭제·연결.
  연결할 때마다 비밀번호를 묻는다 (저장하지 않는다). 지금 탭이 비어 있으면 그 탭에, 아니면 새 탭에 연결한다.
- 터미널 글꼴(`terminal_prefs.dart`, `terminal_font_dialog.dart`): 기본은 내장 Agave Nerd Font Mono(OFL 1.1,
  `assets/licenses/agave-nerd-font.txt`). 목록에서 고르거나 설치된 글꼴 이름을 직접 적을 수 있고, 어느 쪽이든
  fallback 맨 앞에 내장 글꼴이 있어 아이콘 글리프는 항상 나온다. 설정 키: `terminal_font_family`, `terminal_font_size`, `terminal_scrollback`(스크롤백 줄 수, 기본 10000 — xterm2는 생성 때만 정해서 새로 여는 탭부터 적용).
  (규약 fonts.md §4의 기본 고정폭 목록 대신 Nerd Font를 기본으로 쓰는 것은 사용자 요청.)

## 탭 종류: SSH와 로컬 셸

- 새 탭 메뉴(+) 또는 새 연결 화면(연결 버튼 아래의 "로컬 셸" 버튼들)에서 고른다. 새 연결 화면에서 고르면 그 빈 탭이 셸 탭으로 바뀐다(`openLocalHere`). 주소록은 SSH만 저장한다. **SSH 탭** = 왼쪽 SFTP(서버 폴더) + SSH 터미널. **로컬 셸 탭** = 왼쪽 이 PC의 폴더 뷰 +
  로컬 셸 터미널. 한 탭에서 로컬과 원격을 동시에 보지 않는다(양쪽 패널 없음).
- 구조: `TerminalSession`(터미널, LineSender, 기록, 현재 경로 확인)을 `SshSessionProvider`와 `LocalShellSession`이
  상속한다. 화면의 공통 위젯(터미널, LineSender, 상태 바, 탭)은 `TerminalSession`으로, 왼쪽 패널은 `SftpPane` /
  `LocalFolderPane`이 자기 타입으로 찾는다. 두 패널은 `file_pane_parts.dart`(헤더·행)와 `ListSelection`을 공유한다.
- 셸 탐지(`local_shell_finder.dart`): Windows는 pwsh, Windows PowerShell, cmd, Git Bash, WSL 배포판(`wsl -l -q`는
  UTF-16). macOS/Linux는 `$SHELL`과 `/etc/shells`(macOS는 로그인 셸 `-l`). 첫 번째가 기본 셸(Ctrl+Shift+L).
- 경로 이동도 **메뉴로만**: "터미널을 이 폴더로 이동"은 셸 종류별 명령(`local_paths.dart`)을 입력하고, "탐색기를
  터미널 경로로 이동"은 셸에 OSC 7을 출력시키는 명령을 입력해 경로를 받는다. cmd는 현재 경로를 알려 줄 방법이 없어
  이 메뉴 항목을 숨긴다. WSL은 `wslpath -u`와 `\\wsl.localhost\배포판` / `/mnt/c` 변환, Git Bash는 `cygpath -m`을 쓴다.
- 로컬 폴더 뷰의 삭제는 휴지통 없이 영구 삭제다(확인 창에 그렇게 적혀 있다). 링크는 대상이 아니라 링크만 지운다.
- 셸이 끝나면 탭은 남고 "다시 시작" 줄이 뜬다. 셸이 시작되지 않으면 오류와 함께 같은 줄이 뜬다.
- **`packages/flutter_pty`는 pub.dev 0.4.2의 복사본**이다. 원본의 Windows 결함(명령줄에 실행 파일이 두 번,
  UTF-8을 한 글자씩 UTF-16에 넣어 한글 경로가 깨짐, 인용 없음, 셸을 띄울 때마다 `Sleep(1000)`)을 고쳤다.
  자세한 내용은 `packages/flutter_pty/PATCHES.md`. 원본이 고치면 되돌린다.
- macOS 샌드박스는 꺼 둔다(`app-sandbox = false`, 규약). 켜져 있으면 로컬 셸도 SSH 연결도 막힌다.

## LineSender를 편집기처럼 (불러오기/저장)

- **제목 줄은 없다.** 편집 중인 파일 이름과 변경 여부는 입력 칸 안 맨 위(높이 36의 이름 줄)에 **둥근 윤곽선 칩**(새 연결 화면의 셸
  버튼과 같은 모양, 높이 28)으로 고정되어 있다. 본문과 구별되도록 본문(`onSurface`)과 다른 강조색(`primary`)을 쓰고, 저장하지 않은 변경이
  있으면 칩의 글자·아이콘·윤곽선이 모두 경고색으로 바뀐다. 글이 스크롤돼도 그대로 있고, 눌러도 입력 칸에 포커스가 간다(파일이 없으면
  `제목 없음`). 배경과 모서리는 바깥 `Container`가 맡고 안쪽 TextField는 채움·테두리를 끈다(테마 기본이 `filled`라서). 버튼은 모두
  **하단 줄**(입력 칸 아래, 높이 44 고정, 위쪽에 구분선 1px)에 있다: 왼쪽 정렬로 파일 버튼 네 개(새로 만들기, 열기 Ctrl+O/⌘O, 저장
  Ctrl+S, 다른 이름으로 저장 Ctrl+Shift+S, 아이콘 22 · 40x40), 오른쪽 정렬로 줄 끝 문자 칩(탭하면 메뉴)과 전송 버튼. 입력 칸 옆에 열을
  두지 않아서 폭이 좁아도 입력 칸이 전체 폭을 쓰고, 하단 줄이 영역 높이와 상관없이 맨 아래에 같은 크기로 붙어 있다. 누르는 영역은 버튼
  크기 그대로(`tapTargetSize: shrinkWrap`, 안 그러면 48로 불어서 좁은 폭에서 넘친다). 영역의 최소 높이는 144(이름 줄 36 + 글 영역 + 하단
  줄 44 + 여백), 기본 160.
  저장하지 않은 변경이 있으면 이름이 `● 이름 (변경됨)`으로 바뀐다. 파일과 연결되기 전(새 스크립트)에는 `제목 없음`이 보인다. 열기·새로 만들기 전에 변경이 있으면 취소/버리기/저장을 묻는다.
- 규칙(`sender_file.dart`): UTF-8 텍스트만(BOM은 떼고, UTF-8이 아니면 깨져 보이게 열지 않고 거부), 2MB 초과 거부. 칸 안에서는
  줄바꿈을 LF로 통일하고(한 줄씩 보내는 로직이 LF 기준), 저장할 때 파일이 원래 쓰던 줄바꿈(CRLF 등)으로 돌려놓는다.
- 불러온 뒤 커서는 맨 앞이라 Enter를 누르면 첫 줄부터 보내진다. 마지막 줄을 보내면 새 줄이 붙지만 그것만으로
  "변경됨"이 되지는 않는다(끝의 빈 줄은 비교에서 뺀다). 스크립트와 파일 연결은 탭마다 따로다.
- 스크롤바 위 마우스 커서: TextField가 칸 전체를 I자 커서로 덮어서 안쪽 스크롤바 위에서도 커서가 안 바뀐다. 스크롤바가 있을
  때만 오른쪽 가장자리(안쪽 여백 10px + 스크롤바 18px)에 `PassThroughCursorRegion`(화살표 커서, 마우스 이벤트는 통과)을
  겹친다. 손잡이는 상자 오른쪽 끝에서 13~20px 안쪽에 있다(측정, 입력 칸 안쪽 여백이 바뀌면 달라지니 다시 잰다). `MouseRegion`은 이벤트를 막아서 스크롤바를 못 끌게 되므로
  쓰지 않는다. 스크롤바 유무는 알림만 믿지 않고 글·크기가 바뀔 때마다 프레임 뒤에 직접 읽는다(글이 짧아지면 알림이 안 온다).
- 끌어넣기: 입력 칸에 텍스트 파일(`SenderFile.textExtensions`: txt, md, cfg, ini, conf, json, yaml, sh 등)을 끌어놓으면 열기와 같이 내용을 불러온다(변경이 있으면 먼저 묻는다). 목록에 없는 형식은 안내만 하고 열지 않는다. 이 앱에서 끌어낸 것(`FlutterDragOut.inProgress`)은 무시한다.
- 테스트의 파일 선택창은 `FileSelectorPlatform.instance`를 가짜로 바꿔서 쓴다 (`test/line_sender_file_test.dart`).

## 창 위치 (Windows)

- `lib/window/window_placement.dart`: 마지막 창 위치·크기를 `window_placement` 키로 저장하고(물리 픽셀, 최대화 여부 포함) 다시 켤 때 복원한다.
  저장한 모니터가 없어졌거나 화면 밖이면 주 모니터 가운데에 연다. window_manager의 `center`는 커서가 있는 모니터를
  고르고, 모니터마다 배율이 다르면 위치 단위가 어긋나 창이 한쪽으로 쏠리므로 Windows에서는 쓰지 않는다.
  다른 OS는 기존대로 `center: true`.

## xterm2 복사본

- `packages/xterm2`는 pub.dev 5.3.0의 복사본이다. 드래그로 글을 고르는 중 스크롤되면 선택 시작점이 딴 줄로 옮겨가던
  결함을 고쳤다(시작점을 버퍼 칸으로 저장). 자세한 내용은 `packages/xterm2/PATCHES.md`. 원본이 고치면 되돌린다.

## 알려진 한계

- 실제 OS 끌기(Explorer/Finder로 놓기)는 자동 테스트로 확인하지 못했다 — 사람이 직접 눌러 봐야 한다.
  플러그인 쪽도 Windows/Linux는 베타다.
- Windows/Linux에서 큰 파일을 끌어내면, 로컬 사본을 다 받을 때까지 기다려야 끌기가 시작된다.
- "탐색기를 터미널 경로로 이동"은 셸에 `printf`(OSC 7)를 입력해서 경로를 얻는다 — bash/zsh/sh 계열 셸 기준이고,
  입력한 명령이 터미널에 한 줄 보인다.
