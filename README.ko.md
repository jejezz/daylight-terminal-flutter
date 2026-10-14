<!-- From jejezz/application-release-templates common/tool/readme @ conventions-v1.
     tool/readme/init_readme.py가 만든 파일입니다 — conventions/readme-guide.md 참고.
     {{TODO: …}}를 모두 채우십시오. 하나라도 남아 있으면 tool/readme/check_readme.py가 실패합니다. -->

<p align="center">
  <img src="assets/icon/app_icon.png" width="128" alt="Daylight Terminal 아이콘">
</p>

<h1 align="center">Daylight Terminal</h1>

<p align="center">
  <b>SSH 터미널과 SFTP 파일 탐색기를 한 창에서</b> — 연결 하나로 셸과 파일 탐색기를 나란히 보고, 끌어다 놓아 파일을 주고받습니다.
</p>

<p align="center">
  <a href="https://github.com/jejezz/daylight-terminal-flutter/releases/latest"><img src="https://img.shields.io/github/v/release/jejezz/daylight-terminal-flutter?style=flat-square&color=4c9dff" alt="최신 릴리스"></a>
  <a href="https://github.com/jejezz/daylight-terminal-flutter/releases"><img src="https://img.shields.io/github/downloads/jejezz/daylight-terminal-flutter/total?style=flat-square&color=7c5cff" alt="다운로드"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%C2%B7%20Windows%20%C2%B7%20Linux-34d399?style=flat-square" alt="macOS · Windows · Linux">
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569b?style=flat-square" alt="Flutter">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/jejezz/daylight-terminal-flutter?style=flat-square" alt="MIT 라이선스"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>한국어</b>
</p>

<p align="center">
  <img src="docs/screenshots/demo.gif" width="720" alt="Daylight Terminal 데모: 주소록에서 서버를 골라 접속하고, 명령을 실행하고, 탐색기에 파일을 올리는 흐름">
</p>

## 기능

- **창 하나, 연결 하나** — 터미널과 SFTP 탐색기를 나란히 놓고 하나의 SSH 로그인을 함께 쓰며, 탭으로 여러 서버를 다룹니다.
- **양방향 드래그 앤 드롭** — 파일·폴더를 탐색기에 끌어다 놓으면 업로드, Finder·탐색기로 끌어내면 다운로드(여러 개 동시).
- **로컬 셸도 한 곳에서** — PowerShell, cmd, Git Bash, WSL, zsh, bash를 탭으로 열고 왼쪽에는 이 PC의 폴더를 보여 줍니다. SSH 탭과 나란히 씁니다.
- **주소록과 터미널 도구** — 그룹·검색이 되는 접속 주소록, 한 줄씩 보내는 LineSender, 세션 기록, 내장 Nerd Font(또는 설치된 아무 글꼴).
- **라이트·다크, 한국어·English** — 시스템 설정을 따르거나 툴바에서 고를 수 있습니다

<p align="center">
  <img src="docs/screenshots/home.png" width="360" alt="Daylight Terminal: SFTP 탐색기, 터미널, LineSender를 한 창에서 (라이트·다크)">
  <img src="docs/screenshots/detail.png" width="360" alt="Daylight Terminal 주소록: 그룹별로 저장한 접속 정보">
</p>

## 설치

[**Releases**](https://github.com/jejezz/daylight-terminal-flutter/releases/latest)에서 받습니다.

| OS | 파일 |
|---|---|
| macOS 12.0 이상 | `DaylightTerminal-<버전>-macos-universal.dmg` — 열어서 앱을 Applications 폴더로 끌어다 놓으세요 |
| Windows 10/11 (x64) | `DaylightTerminal-<버전>-windows-x64-setup.exe` |
| Linux (x64) | `DaylightTerminal-<버전>-linux-x64.tar.gz` — 압축을 풀고 `./install.sh` 실행 (`--remove`로 제거) |

**Windows:** 설치 프로그램에 아직 코드 서명이 없어서 SmartScreen이 "Windows의 PC 보호" 창을 띄웁니다. **추가 정보 → 실행**을 누르세요.

## 개발

```bash
flutter pub get
flutter run -d macos
```

릴리스: `scripts/bump-version.sh patch` → 병합 → `vX.Y.Z` 태그. CI가 모든 플랫폼을 빌드해서 올립니다. 규칙: [application-release-templates/conventions](https://github.com/jejezz/application-release-templates/tree/main/conventions).

## 크레딧

- 글꼴: [서울남산체](https://www.seoul.go.kr/seoul/font.do) (서울특별시)
- 아이콘: [Icons8](https://icons8.com)

## 라이선스

[MIT](LICENSE) © 2026 Jongyun Ahn
