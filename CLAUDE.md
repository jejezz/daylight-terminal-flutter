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
  없으면 건너뛴다.

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

## 알려진 한계

- 실제 OS 끌기(Explorer/Finder로 놓기)는 자동 테스트로 확인하지 못했다 — 사람이 직접 눌러 봐야 한다.
  플러그인 쪽도 Windows/Linux는 베타다.
- Windows/Linux에서 큰 파일을 끌어내면, 로컬 사본을 다 받을 때까지 기다려야 끌기가 시작된다.
- "탐색기를 터미널 경로로 이동"은 셸에 `printf`(OSC 7)를 입력해서 경로를 얻는다 — bash/zsh/sh 계열 셸 기준이고,
  입력한 명령이 터미널에 한 줄 보인다.
