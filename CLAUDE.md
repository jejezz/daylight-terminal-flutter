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

## 화면 글자 크기

- 설정 창 "외형"의 슬라이더 `화면 글자 크기`(80~150%, 5% 단위, 기본 100%, 키 `ui_text_scale`, `ui_prefs.dart`). 메뉴·탭·폴더/파일 이름·상태 줄·대화상자 등
  터미널 밖의 **모든 글자**가 커진다. `main.dart`의 `MaterialApp.builder`에서 `MediaQuery.textScaler`에 (OS 배율 × 이 배율)을 넣는 방식이라 개별 `fontSize`도 같이 커진다.
- 터미널은 이 배율을 받지 않는다: `TerminalView`에 `TextScaler.noScaling`을 주고 크기는 "터미널 글꼴"의 크기로만 정한다.
- 글자가 들어가는 **고정 높이**는 `context.scaled(값)`(`utils/ui_scale.dart`)으로 같이 키운다: 탭 줄(48), 파일 목록 줄(30), 상태 줄(32).
  새로 고정 높이를 넣을 때는 이걸 써야 큰 배율에서 글자가 잘리지 않는다. LineSender 하단 줄(44)·이름 줄(36)은 아직 고정이다.

## 앱 안 아이콘: Phosphor 듀오톤

- 앱 안의 모든 UI 아이콘은 **Phosphor Icons 듀오톤**(MIT)이다 (규약 icons.md는 Material Icons / Icons8을 말하지만 Phosphor 듀오톤으로 바꾼 것은 사용자 요청).
  `lib/theme/phosphor_icons.dart`의 `PhosphorIconsDuotone.이름`을 `PhosphorIcon(...)`으로 그린다. 새 아이콘은 Phosphor 이름 그대로 이 파일에 (주, 보조) 코드 포인트와 함께 더한다
  (코드 포인트는 phosphor_flutter 2.1.0의 `phosphor_icons_duotone.dart`에 있다. 테스트가 보조 글리프 빠진 것을 잡는다).
- **`phosphor_flutter` 패키지는 쓰지 않는다**: 2.1.0은 이 Flutter(3.47)에서 컴파일되지 않는다 (`IconData`가 final class라 상속 불가). 같은 글꼴
  (`assets/fonts/phosphor_duotone.ttf`, 라이선스 `assets/licenses/phosphor-icons.txt`)과 코드 포인트를 직접 쓴다. 보조(흐린 겹) 글리프는 모두 `const`여야 한다 (아이콘 글꼴 줄이기).
- 듀오톤은 글꼴 안에 두 겹이라 `PhosphorIcon`이 보조를 20% 불투명도로 깔고 주를 위에 그린다. 두 겹 모두 같은 색(`IconTheme`/`color`)이라 밝은/어두운 테마 모두 그대로 어울린다.
- 점 모양(연결 상태 점 등)은 아이콘이 아니라 도형이라 `Icons.circle` 그대로다. 테스트에서 아이콘을 찾을 때는 `find.byIcon(PhosphorIconsDuotone.x)` 또는 `find.byType(PhosphorIcon)`
  (`find.byType(Icon)`은 뒤 겹을 잡는다).

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
- 도구 줄(`_SerialBar`): 터미널/Hex 보기, 로컬 에코(기본 꺼짐: 켜면 LineSender로 보낸 줄을 화면에도 씀 — 터미널에 직접 친 키는 에코하지 않는다), 받은 바이트 수.
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
- 그냥 Enter는 보통의 편집기와 같은 줄바꿈이고, Ctrl+Enter가 커서가 있는 줄을 터미널로 보낸다(연결 전에는 아무 일도 하지 않는다).
  불러온 뒤 커서는 맨 앞이라 Ctrl+Enter를 누르면 첫 줄부터 보내진다. 마지막 줄을 보내면 새 줄이 붙지만 그것만으로
  "변경됨"이 되지는 않는다(끝의 빈 줄은 비교에서 뺀다). 스크립트와 파일 연결은 탭마다 따로다.
- 스크롤바 위 마우스 커서: TextField가 칸 전체를 I자 커서로 덮어서 안쪽 스크롤바 위에서도 커서가 안 바뀐다. 스크롤바가 있을
  때만 오른쪽 가장자리(안쪽 여백 10px + 스크롤바 18px)에 `PassThroughCursorRegion`(화살표 커서, 마우스 이벤트는 통과)을
  겹친다. 손잡이는 상자 오른쪽 끝에서 13~20px 안쪽에 있다(측정, 입력 칸 안쪽 여백이 바뀌면 달라지니 다시 잰다). `MouseRegion`은 이벤트를 막아서 스크롤바를 못 끌게 되므로
  쓰지 않는다. 스크롤바 유무는 알림만 믿지 않고 글·크기가 바뀔 때마다 프레임 뒤에 직접 읽는다(글이 짧아지면 알림이 안 온다).
- 끌어넣기: 입력 칸에 텍스트 파일(`SenderFile.textExtensions`: txt, md, cfg, ini, conf, json, yaml, sh 등)을 끌어놓으면 열기와 같이 내용을 불러온다(변경이 있으면 먼저 묻는다). 목록에 없는 형식은 안내만 하고 열지 않는다. 이 앱에서 끌어낸 것(`FlutterDragOut.inProgress`)은 무시한다.
- 테스트의 파일 선택창은 `FileSelectorPlatform.instance`를 가짜로 바꿔서 쓴다 (`test/line_sender_file_test.dart`).

## 관리자 권한 (Windows)

- 설정 창 "관리자 권한" 섹션(Windows만). 로컬 셸(ConPTY)은 앱의 권한을 그대로 물려받고 실행 중인 프로세스의 권한은 못 바꾸므로,
  "관리자 권한으로 다시 시작"은 탭 목록을 저장하고(`SessionsController.saveTabsNow`) `ShellExecuteW(runas)`로 같은 exe를 UAC 상승으로 띄운 뒤
  이 앱을 끝낸다 (`services/elevation.dart`). UAC를 거절하면 그대로 두고 안내만 한다. 이미 관리자면 "관리자 권한으로 실행 중"만 보인다(`IsUserAnAdmin`).
- 관리자로 실행 중이면 제목 표시줄에 "(관리자 모드)"가 붙고 상태 바에 방패 아이콘과 "관리자 모드"가 보인다.
- 새 프로세스는 탭 복원(`restore_tabs`)으로 로컬 셸을 다시 연다. 복원을 꺼 두었으면 빈 창으로 시작한다.
- 알려진 한계: 관리자로 뜬 앱에는 일반 권한 탐색기에서 끌어넣기가 막힌다(Windows UIPI). 자동 테스트로 UAC 흐름은 확인하지 못했다.

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

## 탭 글(폴더·실행 중 명령)과 셸 통합

- 탭은 두 줄(높이 48)이다. 첫 줄 = `셸이름  폴더이름`(`TabLabels`, `lib/utils/tab_label.dart`; 셸 이름은 `pwsh`처럼 짧게 `primary` 색, 폴더는 집이면 `~`, 겹치면 부모를 붙여 `a/src`),
  둘째 줄 = 실행 중인 명령(`primary` 색) 또는 전체 경로. 폴더를 모르는 탭(SSH·시리얼·셸 통합 없는 셸)은 예전처럼 `tabTitle` 한 줄.
  툴팁에 전체 경로·셸·명령·종료 코드. 탭 앞 표시는 명령이 0.5초 넘게 돌면 스피너, 마지막 명령이 실패(종료 코드 ≠ 0)면 다음 명령까지 빨간 점.
- 탭 앞의 **아이콘 색**(16px; 막대는 아래 밑줄과 이어져 어색해서 없앴다): **탭마다** 다른 색이다 (폴더가 아니라 — 같은 폴더의 셸 여러 개도, 옆 탭끼리도 구분되게). `TabLabels.assignColors`가
  탭 줄이 그릴 때 아직 색이 없는 세션(`TerminalSession.tabColorIndex`)에 번호를 주는데, 가장 적게 쓰인 번호를 고르고 같으면 양옆 탭 색과 색상환에서
  가장 먼 것을 고른다. 한 번 받은 색은 `cd`나 다른 탭이 닫혀도 안 바뀐다. 색상환 16등분, 채도 0.85, 어두운 테마 명도 0.58 / 밝은 테마 0.42
  (`TabLabels.colorFor`). 고른 탭이라고 색을 바꾸지 않는다 (아래 밑줄이 알려 준다). 탭이 16개를 넘으면 색이 겹친다. 재시작하면 순서대로 다시 받는다.
- **탭 이름 직접 짓기**: 탭을 더블클릭하거나 오른쪽 클릭 → "탭 이름 바꾸기". 지은 이름(`TerminalSession.customTitle`)은 첫 줄의 폴더 이름 자리에 보이고(셸 이름·둘째 줄은 그대로),
  비워서 확인하거나 "자동 이름으로"를 고르면 자동 이름(폴더)으로 돌아간다. 저장된 탭 목록에 `title`로 같이 저장되어 다시 켜도 남는다(`SavedTab.title`).
  더블클릭은 `Listener`로 직접 센다 — `InkWell.onDoubleTap`을 쓰면 한 번 클릭으로 탭을 고르는 것이 늦어진다.
- 탭이 화면보다 많으면 탭 줄이 가로로 스크롤된다: 마우스 휠(세로 휠도 가로로 민다), 아래의 얇은 스크롤바, 그리고 탭을 고르거나 새 탭이 열리면
  그 탭이 보이는 곳으로 자동으로 온다(`_EnsureVisible`). 탭은 `ListView.builder`가 아니라 `Row`에 모두 만든다(안 만들어진 탭은 가져올 수 없어서).
- 폴더·명령은 **셸 통합**(`lib/services/shell_integration.dart`)이 알려 준다: 로컬 PowerShell(pwsh·Windows PowerShell)을 띄울 때
  `-NoExit -EncodedCommand`로 스크립트를 넣어(파일 없이 — 실행 정책 회피) 프로필 뒤에 `prompt`와 `PSConsoleHostReadLine`을 감싼다.
  프롬프트마다 OSC 7(폴더), 명령을 받으면 OSC 633;E(명령, `\\`·`\xHH` 이스케이프)와 133;C, 끝나면 133;D;종료코드.
  `TerminalSession`이 `onPrivateOSC`로 받아 `reportedCwd`/`runningCommand`/`commandRunning`/`lastExitCode`로 노출한다 (바뀔 때만 알림).
  명령은 300자까지만 보낸다. 비밀번호가 든 명령이 탭(스크린샷)에 보일 수 있다 — 설정으로 줄이는 것은 아직 없다.
- **bash·Git Bash**도 셸 통합이 있다. 파일 없이 환경 변수로 넣는다: `PROMPT_COMMAND='eval "$__DL_SI"'`와 스크립트가 든 `__DL_SI`
  (`ShellIntegration.environment`). `PROMPT_COMMAND`는 첫 프롬프트에서 불리므로 `.bashrc`/`.bash_profile`(로그인 셸 포함)을 다 읽은 뒤에 걸리고,
  `PS0`(bash 4.4+)로 명령 시작을 알린다(`history 1`로 명령 줄). 프롬프트마다 종료 코드(133;D)·폴더(OSC 7, Git Bash는 `cygpath -m`)를 알리고
  `$?`를 되돌려 놓는다. 기존 `PROMPT_COMMAND`는 이어서 부른다. macOS 기본 bash 3.2는 `PS0`가 없어 폴더만 알린다. 스페이스로 시작하는 명령(앱이 `cd`를 넣을 때)은
  히스토리에 안 남아 직전 명령이 잠깐 보일 수 있다 (0.5초 안에 끝나 스피너는 안 뜬다).
- **WSL**도 같은 bash 스크립트를 쓴다: `wsl.exe`는 `WSLENV`에 이름이 올라 있는 환경 변수만 리눅스로 넘기므로 `PROMPT_COMMAND`·`__DL_SI`를 `WSLENV`에 보탠다.
  폴더는 리눅스 경로(`/home/me`, `/mnt/c/…`) 그대로 탭에 보인다.
- 아직: zsh·cmd는 셸 통합이 없다 (폴더 이름 대신 셸 이름), 명령 숨기기 설정. zsh는 `ZDOTDIR`로 `.zshrc`를 감싸 `precmd`/`preexec`를 거는 방식이 될 텐데,
  이 PC(Windows)에는 zsh가 없어 실제로 돌려 볼 수 없었다. PowerShell 7(pwsh)은 이 PC에 없어 실제로는 확인하지 못했다 (Windows PowerShell 5.1로만).

## Impeller (렌더링 엔진)

- 기본은 **꺼짐**(앱 초기화가 켰을 때보다 1/3 시간). 환경 변수 `DAYLIGHT_IMPELLER=1`(또는 true/on/yes)로 켠다.
- Windows(`windows/runner/main.cpp`)는 `DartProject::set_impeller_switch`, Linux(`linux/runner/main.cc`)의 `main` 맨 앞에서 엔진 생성 전에 `FLUTTER_ENGINE_SWITCHES`/`FLUTTER_ENGINE_SWITCH_1=enable-impeller=true|false`를 설정한다.
  macOS는 Info.plist `FLTEnableImpeller=false`가 기본이고 `MainFlutterWindow.swift`가 같은 환경 변수 방식으로 덮어쓴다(켜는 쪽은 실제 Mac에서 확인하지 못했다).

## 원격 편집기 (SFTP, 오른쪽 도킹)

- SSH 탭에서 파일을 우클릭 → "편집" 또는 F4로 연다. 서버에 아무것도 설치하지 않고 SFTP로만 읽고 쓴다. 탭 오른쪽에 도킹되는 칸이고
  (`remote_editor_pane.dart`, `home_screen.dart`의 세 번째 칸), 안에 파일 탭이 있다. 접으면 오른쪽에 좁은 손잡이만 남고 열린 파일은 유지된다.
  더블클릭은 아직 다운로드 그대로다 (편집으로 바꾸는 설정은 다음 단계).
  F4는 탐색기(`SftpPane`)가 자기 `FocusNode`를 가지고 있어야 받는다 — 터미널이 포커스를 쥐고 있어서, 행을 고를 때(`_select`) 탐색기가 포커스를 가져온다 (`test/sftp_pane_keys_test.dart`).
  왼쪽에 줄 번호가 있고, 본문은 줄을 넘기지 않고 가로로 스크롤한다 (줄 번호와 줄이 1:1이 되도록; 둘 다 같은 고정 줄 높이 strut).
- 편집기 칸은 서버에 접속한 SSH 탭에서 **열린 파일이 없어도 늘 펼쳐져 있다** (안내와 "새 파일" 버튼). 사용자가 접었을 때만 오른쪽에 좁은 손잡이만 남는다.
  탭 줄의 + 버튼이나 "새 파일"로 **서버에 아직 없는 새 파일**("제목 없음 N")을 만들어 쓰고, 저장(Ctrl+S)하면 서버 경로를 묻는다 (탐색기가 보는 폴더에 `untitled.txt`를 제안, 상대 경로는 그 폴더 기준).
  이미 있는 경로면 덮어쓸지 묻고, 다른 탭에 열려 있는 경로는 거부한다. "다른 이름으로 저장"(Ctrl+Shift+S)은 열린 파일의 복사본을 서버에 만들고 그 탭이 복사본을 편집한다 (`RemoteText.saveNew`, `RemoteEditorController.saveAs`).
- 구문 강조(`services/syntax_highlight.dart`, `widgets/highlight_controller.dart`): 셸(.sh/.bash/.zshrc 등, 또는 첫 줄 `#!`)과 설정 파일(.conf/.ini/.yaml/.env/.service 등)만 vim처럼 색을 입힌다. 이름이 바뀌면(새 파일을 foo.sh로 저장) 바로 켜진다.
  글은 그대로이고 색만 입히며(`buildTextSpan`), 한글 조합 중 밑줄도 유지한다. 40만 자를 넘으면 강조하지 않는다 (키마다 글 전체를 다시 훑기 때문). 팔레트는 밝은/어두운 테마별로 따로 있다.
- 규칙: UTF-8 텍스트만, 2MB 초과·NUL 바이트(바이너리)·폴더·장치는 거부 (`SenderFile.decode(rejectBinary: true)`, LineSender와 같은 규칙).
  줄바꿈(CRLF)과 BOM은 저장할 때 원래대로 되돌린다. 심볼릭 링크는 실제 경로를 편집한다.
- 저장(`services/remote_text_file.dart`): 저장 직전에 서버 파일의 크기·수정 시각을 다시 확인해 열 때와 다르면 쓰지 않고 충돌로 알린다
  (덮어쓰기 / 서버 버전 불러오기 / 취소). 임시 이름에 쓴 뒤 `rename`하고 권한을 이어받는다 (소유자는 가능할 때만). 폴더에 쓸 수 없으면 파일에 바로 쓴다.
  테스트는 메모리 가짜 `RemoteFs`(`test/helpers/fake_remote_fs.dart`)로 한다.
- 상태는 탭마다 `SshSessionProvider.editor`(`RemoteEditorController`). 연결이 끊겨도 열린 파일은 남기고, 다른 서버에 접속할 때만 비운다.
  저장하지 않은 변경이 있으면 파일 탭·서버 탭을 닫을 때 묻는다.
- 아직: 설정 창 "편집기" 섹션(더블클릭 동작, `.bak` 백업), 좁은 화면에서 아래로 옮기기, 읽기 전용 파일의 sudo 안내, 그 밖의 언어 강조. 실제 SFTP 서버로 확인하지 못했다
  (`SftpRemoteFs`는 e2e 테스트 없음).

- **구분선 끌기**(`widgets/pane_divider.dart`, `PaneDivider`; 탐색기·편집기·LineSender 칸 공통)는 이벤트마다 움직인 양을 더하지 않고 **누른 자리에서의 누적 거리**로 크기를 정한다 (`onDragStart`에서 크기를 기억).
  화면이 다시 그려지기 전에 이벤트가 여러 번 오거나 최소·최대 크기에 걸렸다 풀릴 때 구분선이 마우스를 못 따라가던 문제를 없앤다 (`test/pane_divider_test.dart`).

## 알려진 한계

- 실제 OS 끌기(Explorer/Finder로 놓기)는 자동 테스트로 확인하지 못했다 — 사람이 직접 눌러 봐야 한다.
  플러그인 쪽도 Windows/Linux는 베타다.
- Windows/Linux에서 큰 파일을 끌어내면, 로컬 사본을 다 받을 때까지 기다려야 끌기가 시작된다.
- "탐색기를 터미널 경로로 이동"은 셸에 `printf`(OSC 7)를 입력해서 경로를 얻는다 — bash/zsh/sh 계열 셸 기준이고,
  입력한 명령이 터미널에 한 줄 보인다.
