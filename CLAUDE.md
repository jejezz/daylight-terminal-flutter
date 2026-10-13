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
- 사용 패키지: dartssh2 (SSH/SFTP), xterm2 (터미널, portside와 동일), desktop_drop (드래그 앤 드롭),
  provider (상태), file_selector (저장 대화상자).
- portside-flutter에서 가져온 기능: LineSender(`lib/widgets/line_sender.dart`)와 기록(Recording,
  `lib/services/log_file_service.dart`, `toggleLogging`). SSH에 맞게 줄 끝 기본값은 CR, 로컬 에코는 없음.
  기록 파일은 원본 바이트 또는 이스케이프 제거 텍스트.
- 비밀번호·키 암호는 저장하지 않는다. 호스트 키는 처음 본 것을 신뢰하고(TOFU) 이후 달라지면 거부한다.

## 테스트

- `flutter test`는 서버 없이 돈다. 실제 SSH 서버가 필요한 `test/ssh_e2e_test.dart`,
  `test/ssh_ui_e2e_test.dart`는 `TEST_SSH_PORT`, `TEST_SSH_PASSWORD`(사용자 `tester`, SFTP 루트에 `sub/` 폴더)가
  없으면 건너뛴다.

## 알려진 한계

- 탐색기에서 OS(바탕화면 등)로 파일을 끌어내는 드래그는 아직 없다 — 네이티브 플러그인(Rust 필요)이 필요하다.
  지금은 더블클릭/우클릭 "다운로드"로 받는다.
- "탐색기를 터미널 경로로 이동"은 셸에 `printf`(OSC 7)를 입력해서 경로를 얻는다 — bash/zsh/sh 계열 셸 기준이고,
  입력한 명령이 터미널에 한 줄 보인다.
