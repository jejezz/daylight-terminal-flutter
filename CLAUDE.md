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
  flutter_drag_out (끌어내기), provider (상태), file_selector (저장 대화상자), flutter_libserialport (시리얼).
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

## 탐색기 안에서 끌어놓기 (이동/복사)

- 탐색기(로컬 폴더 뷰, SFTP) 행을 같은 탐색기의 **폴더 행** 위로 끌어다 놓으면 이동/복사를 **늘 먼저 묻는다**
  (`askMoveOrCopy`, `file_pane_parts.dart`). 놓는 순간 Ctrl(macOS는 ⌥)이 눌려 있으면 복사가, 아니면 이동이 기본 버튼이다.
  폴더 행만 받고(`FileRow.canDropInto`/`onDropInto`), 자기 자신·자기 안쪽·이미 그 안에 있는 것뿐이면 묻지 않는다 (`transferable`).
- 로컬: 이동은 이름 바꾸기(다른 드라이브면 복사 뒤 삭제), 같은 이름은 덮어쓰기 확인 창을 거친다 (`moveIn`/`copyIn(to:)`).
- SFTP: 이동은 서버 안 `rename`이고 같은 이름은 덮어쓰지 않고 건너뛴다. **복사는 앱이 하지 않는다** — SFTP에 복사가 없어서
  `cp -a -- 'src' 'dest/'` 명령을 클립보드에 복사해 주고 사용자가 터미널이나 LineSender에 붙여 넣어 실행한다 (`copyCommand`).
- Windows/Linux에서 SFTP 끌기는 이 탐색기 **밖으로 나갈 때** 로컬 사본을 받기 시작한다 (같은 탐색기 안에서 옮기려는 끌기가
  내려받지 않게). 창을 벗어난 순간 아직 시작 전이면 그때 시작한다 (`_stage`).

## SFTP 업로드 (별도 isolate)

- dartssh2의 암호화가 순수 Dart라서 메인 isolate에서 올리면 큰 파일을 올리는 동안 앱 전체(화면·키 입력)가 느려졌다.
  그래서 `SshSessionProvider.upload`는 `sftp_upload_worker.dart`의 워커 isolate가 **같은 서버에 따로 접속해서** 올리고,
  메인은 진행 상황 메시지만 받는다(0.1초에 한 번). 호스트 키는 메인이 이미 믿고 있는 값과 같을 때만 접속한다.
- 두 번째 연결에 쓰려고 비밀번호·키 암호를 **연결이 살아 있는 동안 메모리에만** 들고 있다(`_password`, `_keyPassphrase`; 끊기면 지운다, 저장하지 않는다).
- 워커가 접속하지 못하면(일회용 인증 등) 아무것도 올리기 전에 알려 오고, 그때는 지금 연결로 메인 isolate에서 올린다(`_uploadHere`, 진행 알림만 줄임).
- 올리는 도중 전송 줄의 X 버튼으로 취소할 수 있다(`Transfer.cancel`, 워커에는 항목 번호를 보낸다). 쓰던 파일은 `writer.abort()`로 끊고 서버의 반쯤 올라간 파일은 지운다. 다운로드는 취소할 수 없다.
- 다운로드는 아직 메인 isolate에서 한다.

## 주소록과 터미널 글꼴

- 주소록(`address_book_dialog.dart`, Ctrl+Shift+O / ⌘O): 이름·그룹·메모를 붙여 저장하고, 검색·편집·삭제·연결.
  연결할 때마다 비밀번호를 묻는다 (저장하지 않는다). 지금 탭이 비어 있으면 그 탭에, 아니면 새 탭에 연결한다.
- 터미널 글꼴(`terminal_prefs.dart`, 설정 창 `settings_dialog.dart`의 "터미널 글꼴" 섹션): 기본은 내장 Agave Nerd Font Mono(OFL 1.1,
  `assets/licenses/agave-nerd-font.txt`). 목록에서 고르거나 설치된 글꼴 이름을 직접 적을 수 있고, 어느 쪽이든
  fallback 맨 앞에 내장 글꼴이 있어 아이콘 글리프는 항상 나온다. 설정 키: `terminal_font_family`, `terminal_font_size`, `terminal_scrollback`(스크롤백 줄 수, 기본 10000 — xterm2는 생성 때만 정해서 새로 여는 탭부터 적용).
  (규약 fonts.md §4의 기본 고정폭 목록 대신 Nerd Font를 기본으로 쓰는 것은 사용자 요청.)
- 터미널 색상 구성표(`terminal_schemes.dart`, 설정 창 "터미널 색상" 섹션, 키 `terminal_color_scheme`): 기본(VS Code Dark), Solarized Dark/Light, Dracula, One Dark,
  Tokyo Night, Gruvbox Dark, Nord, Monokai, GitHub Light. 이름은 고유 이름이라 번역하지 않는다. 열린 탭에도 바로 적용된다. 모르는 id는 기본으로 돌아간다.

## 설정 창과 탐색기 자동 새로 고침

- 툴바의 설정(톱니) 버튼 = `settings_dialog.dart`. 섹션: "새로 고침 옵션", "터미널 글꼴".
- 보이는 탭의 목록만 5초마다 조용히(로딩 표시·오류 없이, 바뀐 것이 있을 때만 갱신) 다시 읽는다. 탭이 활성화되면 바로 한 번 읽고,
  비활성화되면 멈추고, 사용자가 새로 고치면 5초가 다시 시작된다 (`TerminalSession.setActive` / `restartAutoRefreshTimer`).
- 설정(`refresh_prefs.dart`): `auto_refresh_local`(기본 켜짐), `auto_refresh_ssh`(기본 꺼짐 — 네트워크 오류가 잦아서).
  `SessionsController`가 설정과 선택된 탭에 맞춰 각 세션에 알린다.
- 테스트는 `test/flutter_test_config.dart`가 타이머를 꺼 둔다 (남은 타이머가 있으면 위젯 테스트가 실패). `auto_refresh_test.dart`만 켠다.

## 탭 종류: SSH와 로컬 셸

- 새 탭 메뉴(+) 또는 새 연결 화면(연결 버튼 아래의 "시리얼"·"로컬 셸" 버튼들)에서 고른다. 이 선택 구역은 **처음 여는 탭(앱 시작, 빈 화면의 새 연결 버튼)에서만** 보이고(`SshSessionProvider.showAllOptions`), (+) 메뉴나 단축키로 연 SSH 탭은 SSH 폼만, 시리얼 탭은 시리얼 폼만 보인다. 새 연결 화면에서 고르면 그 빈 탭이 셸 탭으로 바뀐다(`openLocalHere`). 주소록은 SSH만 저장한다. **SSH 탭** = 왼쪽 SFTP(서버 폴더) + SSH 터미널. **로컬 셸 탭** = 왼쪽 이 PC의 폴더 뷰 +
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

## 탭 종류: 시리얼 (portside-flutter에서 가져옴)

- 새 탭 메뉴(+) 또는 새 연결 화면의 "시리얼" 구역 버튼에서 연다(빈 SSH 탭은 `openSerialHere`로 그 자리에서 바뀐다). 연결 전에는 `SerialConnectPanel`
  (포트, 보드레이트, 데이터 비트, 패리티, 정지 비트, 흐름 제어; 포트 목록은 2초마다 다시 읽어 핫플러그 반영)이 보이고, 연결하면 **왼쪽 이 PC의 폴더 뷰 +
  오른쪽 시리얼 터미널**이 된다. 주소록에는 저장하지 않는다. 설정은 탭이 살아 있는 동안만 기억한다(`SerialSession.pending*`).
- 구조: `LocalFolderSession`(폴더 뷰 상태·동작, `LocalShellSession`에서 뽑아냄)을 `LocalShellSession`과 `SerialSession`이 상속한다.
  `LocalFolderPane`은 `LocalFolderSession`을 찾는다. 시리얼에는 셸이 없어서 `canMoveTerminal`/`canSyncExplorer`가 false — "경로 이동" 메뉴가 숨는다.
- `SerialService`(`flutter_libserialport` 래퍼)는 portside와 같되 `open(SerialSettings)`로 통신 설정을 모두 받는다. 테스트는 `test/helpers/fake_serial.dart`.
- 도구 줄(`_SerialBar`): 터미널/Hex 보기, 로컬 에코(기본 켜짐: LineSender로 보낸 줄을 화면에도 씀 — 터미널에 직접 친 키는 에코하지 않는다), 받은 바이트 수.
  Hex 보기는 터미널 화면이 아니라 실제로 받은 바이트(`rawBytes`, 최대 2MB)다. 줄 끝 기본값은 LF(portside와 같음, SSH/셸은 CR). 연결하면 깨우는 CRLF를 한 번 보낸다.
- 장치가 뽑히면(스트림 오류 또는 오류 없이 끝남, 쓰기 오류) 포트를 닫고 오류 상태가 되어 연결 폼으로 돌아간다. 기록(Recording)은 받은 바이트를 그대로 쓴다.
- 네이티브 `libserialport`는 플러그인이 빌드한다. macOS는 podspec이 `autogen.sh`/`configure`를 돌려서 `brew install automake libtool`이,
  Linux는 `libudev-dev`가 필요하다 (`release.yml`에 설치 단계가 있다). 앱 샌드박스와는 무관하다.

## 열어 둔 탭 기억·복원

- 앱을 켤 때 지난번에 열어 둔 탭을 다시 연다 (설정 창 "시작" 섹션, 키 `restore_tabs`, 기본 켜짐). 저장은 `SessionsController`가
  탭을 열고 닫거나 바꿀 때, 탭 안의 상태가 바뀔 때(1초 모아서), 앱을 끝낼 때 한다 (`tab_store.dart`, 키 `open_tabs`, 같으면 쓰지 않는다).
- **로컬 셸**: 같은 셸을 마지막 폴더에서 바로 연다 (셸이 지금 없으면 건너뛰고, 폴더가 없으면 홈). **SSH**: 접속 정보(호스트·포트·사용자·키 경로·이름)만
  채운 접속 화면으로 연다 — 비밀번호·키 암호는 저장하지 않으니 자동 접속하지 않는다 (`SshSessionProvider.prefill`). **시리얼**: 포트·속도 등만 채우고
  장치를 자동으로 열지 않는다 (`SerialSession.prefill`). 접속하지 않은 빈 SSH 탭은 저장하지 않는다.
- 복원은 `loadShells()` 뒤에 한 번(`restoreTabs`), 사용자가 처음 탭을 건드리기 전일 때만 한다. 복원이 끝나기 전에는 저장하지 않는다 (처음의 빈 탭이
  지난번 기록을 덮어쓰지 않게). 설정을 끄면 저장해 둔 것을 지운다. 컨트롤러에 `tabStore`·`restorePrefs`를 주지 않으면(테스트) 기억하지 않는다.

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

## 도움말 모드

- 앱 바의 `?` 버튼(`HelpModeButton`) → `HelpModeController.start`. 켜지면 `HomeScreen`의 `Stack` 맨 위에 `HelpModeOverlay`가 올라와
  화면을 살짝 어둡게 하고(마우스가 올라간 컨트롤만 도려내 밝게) 커서를 `help`(화살표+?)로 바꾼다. 아무 곳이나 클릭하거나 Esc면 끝나며,
  그 클릭·키는 아래로 전달하지 않는다. 창 크기는 고정하지 않는다(박스는 매번 실제 위치를 읽어 따라온다).
- 설명이 필요한 컨트롤은 `child.help(HelpId.x)`(= `HelpTarget`)로 감싸고, 글은 `app_*.arb`의 `help*` 키(첫 줄 이름, 나머지 설명)에 둔다.
  패널뿐 아니라 안의 버튼(탭, 탐색기 헤더·행, LineSender 하단 줄, 상태 바)도 각각 감싼다. 서버 연결 화면(`ConnectPanel`)은 대상이 아니다.
  겹치면 가장 작은(안쪽) 영역이 이긴다. `IndexedStack`이 가린 탭의 컨트롤은 뺀다.
- 다이얼로그가 떠 있으면(`ModalRoute.isCurrent == false`) `?` 버튼이 꺼져 진입할 수 없다. 오버레이는 메인 화면만 덮는다.

## 알려진 한계

- 실제 OS 끌기(Explorer/Finder로 놓기)는 자동 테스트로 확인하지 못했다 — 사람이 직접 눌러 봐야 한다.
  플러그인 쪽도 Windows/Linux는 베타다.
- Windows/Linux에서 큰 파일을 끌어내면, 로컬 사본을 다 받을 때까지 기다려야 끌기가 시작된다.
- "탐색기를 터미널 경로로 이동"은 셸에 `printf`(OSC 7)를 입력해서 경로를 얻는다 — bash/zsh/sh 계열 셸 기준이고,
  입력한 명령이 터미널에 한 줄 보인다.
