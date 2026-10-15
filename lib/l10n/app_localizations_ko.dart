// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutTooltip => '정보';

  @override
  String aboutVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get aboutOpenSourceLicenses => '오픈소스 라이선스';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => '닫기';

  @override
  String aboutMenuItem(String appName) {
    return '$appName 정보';
  }

  @override
  String get themeMenuTooltip => '테마';

  @override
  String get themeSystem => '시스템 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get languageMenuTooltip => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기 / System';

  @override
  String get languageSystemShort => '시스템';

  @override
  String get aboutTagline => 'SSH 터미널과 SFTP 파일 탐색기를 한 창에서';

  @override
  String get aboutDescription =>
      '하나의 SSH 연결로 터미널과 SFTP 파일 탐색기를 나란히 보여 줍니다. 파일을 끌어다 놓아 올리고 내려받고, 원할 때만 터미널과 탐색기의 경로를 맞춥니다.';

  @override
  String get homeEmptyTitle => '서버에 연결해 시작하세요';

  @override
  String get homeEmptyAction => '연결';

  @override
  String get updateCheckMenuItem => '업데이트 확인';

  @override
  String get updateChecking => '업데이트를 확인하는 중…';

  @override
  String get updateAvailableTitle => '새 버전이 있습니다';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest 버전이 나왔습니다. (현재 $current)';
  }

  @override
  String get updateReleaseNotes => '변경 내용';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateDownloading => '내려받는 중…';

  @override
  String get updateVerifying => '파일을 확인하는 중…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => '취소';

  @override
  String get updateFailedTitle => '업데이트하지 못했습니다';

  @override
  String get updateCheckFailedTitle => '업데이트를 확인하지 못했습니다';

  @override
  String get updateErrorNetwork =>
      '업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get updateErrorChecksum =>
      '내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateErrorInstall => '설치를 시작하지 못했습니다.';

  @override
  String get updateErrorGeneric =>
      '업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateUpToDateTitle => '최신 버전입니다';

  @override
  String updateUpToDateBody(String version) {
    return '$version 버전을 사용 중입니다.';
  }

  @override
  String get updateUnavailableTitle => '직접 설치해 주세요';

  @override
  String updateUnavailableBody(String latest) {
    return '$latest 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.';
  }

  @override
  String get updateOpenReleasePage => '릴리스 페이지 열기';

  @override
  String get updateBrowserDownloadTitle => '브라우저에서 내려받습니다';

  @override
  String updateBrowserDownloadBody(String appName) {
    return '브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateMacosOpenedTitle => '설치 창이 열렸습니다';

  @override
  String updateMacosOpenedBody(String appName) {
    return '열린 창에서 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateWindowsInstallTitle => '설치 프로그램을 열었습니다';

  @override
  String updateWindowsInstallBody(String appName) {
    return '설치하려면 $appName 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.';
  }

  @override
  String updateQuitApp(String appName) {
    return '$appName 종료';
  }

  @override
  String get updateLinuxInstallTitle => '설치를 준비했습니다';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.';
  }

  @override
  String get updateQuitAndInstall => '종료하고 설치';

  @override
  String get updateBusyTitle => '지금은 업데이트할 수 없습니다';

  @override
  String get updateBusyBody => '작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.';

  @override
  String get tabNew => '새 연결';

  @override
  String get tabClose => '탭 닫기';

  @override
  String get connectTitle => '서버에 연결';

  @override
  String get connectSavedProfiles => '저장된 접속';

  @override
  String get connectNewProfile => '새 접속';

  @override
  String get connectHost => '호스트';

  @override
  String get connectPort => '포트';

  @override
  String get connectUser => '사용자';

  @override
  String get connectPassword => '비밀번호';

  @override
  String get connectKeyFile => '개인 키 파일 (선택)';

  @override
  String get connectKeyBrowse => '찾아보기';

  @override
  String get connectKeyPassphrase => '키 암호 (있으면)';

  @override
  String get connectSaveProfile => '이 접속 정보 저장 (비밀번호는 저장하지 않습니다)';

  @override
  String get connectDeleteProfile => '저장된 접속 삭제';

  @override
  String get connectAction => '연결';

  @override
  String get connecting => '연결 중…';

  @override
  String connectFailed(String detail) {
    return '연결하지 못했습니다: $detail';
  }

  @override
  String connectHostKeyMismatch(String host) {
    return '$host의 호스트 키가 이전에 저장한 것과 다릅니다. 중간자 공격일 수 있어 연결을 거부했습니다.';
  }

  @override
  String get connectClosed => '서버가 연결을 닫았습니다.';

  @override
  String get connectReconnect => '다시 연결';

  @override
  String get connectDisconnect => '연결 끊기';

  @override
  String get sftpTitle => '파일';

  @override
  String get sftpUp => '상위 폴더';

  @override
  String get sftpRefresh => '새로 고침';

  @override
  String get sftpNewFolder => '새 폴더';

  @override
  String get sftpFolderName => '폴더 이름';

  @override
  String get sftpRename => '이름 바꾸기';

  @override
  String get sftpNewName => '새 이름';

  @override
  String get sftpDelete => '삭제';

  @override
  String sftpDeleteConfirm(String name) {
    return '$name을(를) 삭제할까요? 되돌릴 수 없습니다.';
  }

  @override
  String get sftpDownload => '다운로드';

  @override
  String get sftpDownloadConfirm => '여기로 받기';

  @override
  String get sftpEmpty => '비어 있는 폴더입니다';

  @override
  String get sftpDropHint => '파일이나 폴더를 끌어다 놓으면 이 폴더로 업로드합니다';

  @override
  String get sftpDropActive => '놓으면 업로드합니다';

  @override
  String get sftpColName => '이름';

  @override
  String get sftpColSize => '크기';

  @override
  String get sftpColModified => '수정한 날짜';

  @override
  String sftpError(String detail) {
    return '목록을 불러오지 못했습니다: $detail';
  }

  @override
  String get sftpOverwriteTitle => '덮어쓸까요?';

  @override
  String sftpOverwriteBody(String names) {
    return '이미 있는 항목: $names';
  }

  @override
  String get sftpOverwrite => '덮어쓰기';

  @override
  String get localDropActive => '놓으면 이 폴더로 복사합니다';

  @override
  String get terminalDropPath => '놓으면 경로를 입력합니다';

  @override
  String get terminalDropUpload => '놓으면 올리고 경로를 입력합니다';

  @override
  String terminalDropFallback(String dir) {
    return '터미널의 현재 폴더를 알 수 없어 탐색기의 폴더에 올렸습니다: $dir';
  }

  @override
  String get commonCancel => '취소';

  @override
  String get commonOk => '확인';

  @override
  String get pathMenuTooltip => '경로 이동';

  @override
  String get pathMenuTerminalToHere => '터미널을 이 폴더로 이동';

  @override
  String get pathMenuExplorerToTerminal => '탐색기를 터미널 경로로 이동';

  @override
  String get pathCwdFailed =>
      '터미널의 현재 경로를 가져오지 못했습니다. 셸이 명령을 받을 수 있는 상태인지 확인하세요.';

  @override
  String transferUploading(String name) {
    return '$name 올리는 중';
  }

  @override
  String transferDownloading(String name) {
    return '$name 받는 중';
  }

  @override
  String get transferDone => '완료';

  @override
  String transferFailed(String error) {
    return '실패: $error';
  }

  @override
  String get transferClear => '완료된 항목 지우기';

  @override
  String get senderHint => '여러 줄을 미리 써 두고 Enter로 한 줄씩 전송합니다 (Ctrl+Enter: 줄바꿈)';

  @override
  String get senderLineEndingNone => '없음';

  @override
  String get senderLineEndingTooltip => '줄 끝 문자';

  @override
  String get senderSend => '현재 줄 전송';

  @override
  String statusRecording(String file) {
    return '기록 중: $file';
  }

  @override
  String statusStartRecording(String key) {
    return '기록 시작 ($key)';
  }

  @override
  String statusStopRecording(String key) {
    return '기록 정지 ($key)';
  }

  @override
  String get statusRevealLog => '탐색기에서 기록 파일 보기';

  @override
  String get statusNoLogFile => '기록한 파일이 아직 없습니다';

  @override
  String get statusCopyBuffer => '터미널 내용 전체를 클립보드로 복사 (스크롤백 포함)';

  @override
  String get statusSaveBuffer => '터미널 내용 전체를 파일로 복사 (스크롤백 포함)';

  @override
  String get statusSaveBufferConfirm => '저장';

  @override
  String get statusBufferEmpty => '터미널에 내용이 없습니다';

  @override
  String get pathCopyHint => '클릭하면 경로를 복사합니다';

  @override
  String pathCopied(String path) {
    return '경로를 클립보드에 복사했습니다: $path';
  }

  @override
  String statusBufferCopied(int lines) {
    return '$lines줄을 클립보드에 복사했습니다';
  }

  @override
  String statusBufferSaved(String file) {
    return '$file에 저장했습니다';
  }

  @override
  String get statusStripAnsi => '이스케이프 제거';

  @override
  String get statusStripAnsiTooltip => '색·커서 이동 같은 제어 시퀀스를 빼고 텍스트만 기록합니다';

  @override
  String get logSaveConfirm => '기록 시작';

  @override
  String sftpDragCount(int count) {
    return '$count개 항목';
  }

  @override
  String sftpDeleteConfirmMany(int count) {
    return '선택한 $count개 항목을 삭제할까요? 되돌릴 수 없습니다.';
  }

  @override
  String get addressBookTitle => '주소록';

  @override
  String addressBookTooltip(String key) {
    return '주소록 ($key)';
  }

  @override
  String get addressBookOpen => '주소록 열기';

  @override
  String get addressBookSearch => '이름·호스트·그룹 검색';

  @override
  String get addressBookEmpty => '저장된 접속이 없습니다. 아래 \'새 접속\'으로 추가하세요.';

  @override
  String get addressBookNoMatch => '검색 결과가 없습니다';

  @override
  String get addressBookNew => '새 접속';

  @override
  String get addressBookEdit => '편집';

  @override
  String get addressBookConnect => '연결';

  @override
  String get addressBookDelete => '삭제';

  @override
  String addressBookDeleteConfirm(String name) {
    return '$name을(를) 주소록에서 삭제할까요?';
  }

  @override
  String get addressBookUngrouped => '그룹 없음';

  @override
  String get addressBookName => '이름 (비우면 user@host)';

  @override
  String get addressBookGroup => '그룹';

  @override
  String get addressBookNote => '메모';

  @override
  String get addressBookSave => '저장';

  @override
  String connectPromptTitle(String label) {
    return '$label에 연결';
  }

  @override
  String get connectPromptHint => '비밀번호는 저장되지 않습니다';

  @override
  String get settingsTooltip => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionRefresh => '새로 고침 옵션';

  @override
  String get settingsSectionTerminalFont => '터미널 글꼴';

  @override
  String get settingsSectionStartup => '시작';

  @override
  String get restoreTabs => '마지막에 열어 둔 탭 다시 열기';

  @override
  String get restoreTabsHelp =>
      '로컬 셸은 같은 폴더에서 바로 열고, SSH와 시리얼은 접속 정보만 채워 둡니다. 비밀번호는 저장하지 않으며 자동으로 연결하지 않습니다.';

  @override
  String get refreshLocal => '로컬 폴더 자동 새로 고침';

  @override
  String get refreshLocalHelp => '보이는 탭의 폴더를 5초마다 다시 읽습니다.';

  @override
  String get refreshSsh => 'SFTP 폴더 자동 새로 고침';

  @override
  String get refreshSshHelp =>
      '보이는 탭의 서버 폴더를 5초마다 다시 읽습니다. 네트워크를 쓰므로 기본은 꺼짐입니다.';

  @override
  String get terminalFontFamily => '글꼴';

  @override
  String terminalFontBundled(String name) {
    return '$name (내장)';
  }

  @override
  String get terminalFontCustom => '직접 입력…';

  @override
  String get terminalFontCustomName => '설치된 글꼴 이름';

  @override
  String get terminalFontCustomHelp =>
      'OS에 설치된 글꼴의 이름을 그대로 적으세요. 없는 이름이면 내장 글꼴로 대신 표시됩니다.';

  @override
  String get terminalFontSize => '크기';

  @override
  String get terminalFontReset => '기본값으로';

  @override
  String get terminalScrollback => '스크롤백 줄 수';

  @override
  String get terminalScrollbackHelp =>
      '위로 스크롤해 다시 볼 수 있는 지난 출력의 최대 줄 수입니다. 새로 여는 탭부터 적용되고, 열려 있는 탭은 그대로입니다.';

  @override
  String terminalScrollbackLines(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString줄';
  }

  @override
  String get localOpen => '열기';

  @override
  String get localReveal => '파일 관리자에서 보기';

  @override
  String get localPlaces => '자주 가는 곳';

  @override
  String localFolderError(String detail) {
    return '폴더를 읽지 못했습니다: $detail';
  }

  @override
  String shellExited(int code) {
    return '셸이 종료되었습니다 (종료 코드 $code)';
  }

  @override
  String get shellRestart => '다시 시작';

  @override
  String shellStartFailed(String detail) {
    return '셸을 시작하지 못했습니다: $detail';
  }

  @override
  String get shellTerminate => '셸 종료';

  @override
  String get newTabSsh => 'SSH 연결';

  @override
  String get newTabLocalShell => '로컬 셸';

  @override
  String get newTabNoShells => '사용할 수 있는 로컬 셸을 찾지 못했습니다';

  @override
  String senderOpen(String key) {
    return '스크립트 열기 ($key)';
  }

  @override
  String senderSave(String key) {
    return '저장 ($key)';
  }

  @override
  String get senderSaveAs => '다른 이름으로 저장…';

  @override
  String get senderNew => '새로 만들기';

  @override
  String get senderModified => '변경됨';

  @override
  String get senderUnsavedTitle => '저장하지 않은 변경 사항';

  @override
  String senderUnsavedBody(String name) {
    return '$name의 변경 사항을 저장하지 않았습니다.';
  }

  @override
  String get senderUntitled => '제목 없음';

  @override
  String get senderDiscard => '버리기';

  @override
  String get senderSaveFirst => '저장';

  @override
  String senderFileTooLarge(int mb) {
    return '파일이 너무 큽니다 (최대 ${mb}MB)';
  }

  @override
  String get senderFileNotUtf8 => 'UTF-8 텍스트 파일만 열 수 있습니다';

  @override
  String get senderDropUnsupported =>
      '텍스트 파일(txt, md, cfg, ini 등)만 끌어넣어 열 수 있습니다';

  @override
  String get senderRemoteNotSaved => '서버 파일의 사본입니다. 고친 내용은 서버에 저장되지 않습니다.';

  @override
  String get senderRemoteNotSavedShort => '서버 파일의 사본 — 고쳐도 서버에는 저장되지 않음';

  @override
  String senderFileError(String detail) {
    return '파일을 처리하지 못했습니다: $detail';
  }

  @override
  String get helpModeTooltip => '도움말 모드';

  @override
  String get helpButton =>
      '도움말 모드\n마우스를 올린 컨트롤의 설명을 봅니다. 아무 곳이나 클릭하거나 Esc를 누르면 끝납니다.';

  @override
  String get helpDisconnect =>
      '연결 끊기 / 셸 종료\nSSH 연결을 끊거나 로컬 셸을 종료합니다. 탭은 남습니다.';

  @override
  String get helpAddressBook =>
      '주소록\n저장해 둔 SSH 접속 정보를 검색·편집하고 연결합니다. 비밀번호는 저장하지 않습니다.';

  @override
  String get helpSettings => '설정\n탐색기 자동 새로 고침과 터미널 글꼴·크기·스크롤백을 바꿉니다.';

  @override
  String get helpTheme => '테마\n밝게, 어둡게, 시스템 설정 중에서 고릅니다.';

  @override
  String get helpLanguage => '언어\n앱 표시 언어를 바꿉니다.';

  @override
  String get helpAbout => '정보\n버전, 라이선스, 업데이트 확인을 봅니다.';

  @override
  String get helpTabs => '탭\nSSH 연결과 로컬 셸을 탭으로 나눠 엽니다. 탭마다 터미널과 탐색기가 따로 있습니다.';

  @override
  String get helpExplorerSftp =>
      '서버 탐색기 (SFTP)\n서버의 폴더와 파일입니다. 파일을 끌어넣으면 업로드, 밖으로 끌어내면 다운로드됩니다.';

  @override
  String get helpExplorerLocal =>
      '폴더 보기\n이 PC의 폴더와 파일입니다. 삭제는 휴지통 없이 영구 삭제됩니다.';

  @override
  String get helpTerminal => '터미널\n셸 화면입니다. 글을 드래그해 복사하고, 키보드로 바로 입력합니다.';

  @override
  String get helpSender =>
      '줄 전송 입력 칸\n여러 줄 스크립트를 쓰거나 파일에서 불러와 한 줄씩 터미널로 보냅니다. 열기·저장도 여기서 합니다.';

  @override
  String get helpStatusBar => '상태 표시줄\n연결 상태와 현재 경로 등 이 탭의 상태를 보여 줍니다.';

  @override
  String get helpEmptyAction => '새 연결\n새 탭을 열어 접속 화면으로 이동합니다.';

  @override
  String get helpTabItem => '탭\n눌러서 이 탭으로 전환합니다. 탭마다 터미널과 탐색기가 따로 있습니다.';

  @override
  String get helpTabNew => '새 탭\nSSH 연결 또는 이 PC의 로컬 셸을 새 탭으로 엽니다.';

  @override
  String get helpTabClose => '탭 닫기\n이 탭을 닫습니다. 연결 중이면 끊깁니다.';

  @override
  String get helpPaneUp => '상위 폴더\n한 단계 위 폴더로 이동합니다.';

  @override
  String get helpPanePath => '현재 경로\n누르면 전체 경로를 클립보드에 복사합니다.';

  @override
  String get helpPaneRefresh => '새로 고침\n폴더 목록을 다시 읽습니다.';

  @override
  String get helpPaneNewFolder => '새 폴더\n현재 폴더 안에 새 폴더를 만듭니다.';

  @override
  String get helpPanePathSync =>
      '경로 동기화\n터미널을 이 폴더로 옮기거나, 탐색기를 터미널의 현재 경로로 옮깁니다. 자동으로는 옮겨지지 않습니다.';

  @override
  String get helpPanePlaces => '자주 가는 곳\n홈, 바탕 화면 등 자주 쓰는 폴더로 바로 이동합니다.';

  @override
  String get helpFileRow =>
      '파일 / 폴더\n두 번 누르면 열고, Ctrl/⌘·Shift로 여러 개를 고릅니다. 오른쪽 버튼으로 메뉴를 열고, 끌어서 옮기거나 업로드·다운로드합니다.';

  @override
  String get helpTransferClear => '완료 항목 지우기\n끝난 전송 기록을 목록에서 지웁니다.';

  @override
  String get helpStatusStripAnsi =>
      '이스케이프 제거\n켜면 기록·복사·저장 때 색상 등 제어 문자를 뺀 글만 남깁니다.';

  @override
  String get helpStatusCopyBuffer => '터미널 내용 복사\n터미널에 쌓인 내용 전체를 클립보드로 복사합니다.';

  @override
  String get helpStatusSaveBuffer => '터미널 내용 저장\n터미널에 쌓인 내용 전체를 파일로 저장합니다.';

  @override
  String get helpStatusRecord =>
      '기록 시작 / 중지\n터미널 출력을 파일에 기록합니다. 연결되어 있을 때 시작할 수 있습니다.';

  @override
  String get helpStatusRevealLog => '기록 파일 보기\n기록한 파일이 있는 폴더를 파일 관리자에서 엽니다.';

  @override
  String get helpSenderNew =>
      '새로 만들기\n입력 칸을 비우고 파일과의 연결을 끊습니다. 변경이 있으면 먼저 묻습니다.';

  @override
  String get helpSenderOpen => '열기\n텍스트 파일(UTF-8)을 입력 칸으로 불러옵니다.';

  @override
  String get helpSenderSave =>
      '저장\n입력 칸의 내용을 연결된 파일에 저장합니다. 연결된 파일이 없으면 새 이름을 묻습니다.';

  @override
  String get helpSenderSaveAs => '다른 이름으로 저장\n입력 칸의 내용을 다른 파일로 저장합니다.';

  @override
  String get helpSenderLineEnding =>
      '줄 끝 문자\n한 줄을 보낸 뒤 덧붙일 문자(CR, LF, CRLF, 없음)를 고릅니다. SSH에서는 보통 CR입니다.';

  @override
  String get helpSenderSend =>
      '보내기\n커서가 있는 줄을 터미널로 보내고 다음 줄로 넘어갑니다. 연결되어 있어야 합니다.';

  @override
  String get newTabSerial => '시리얼 포트';

  @override
  String get serialTitle => '시리얼 연결';

  @override
  String get serialPort => '포트';

  @override
  String get serialPortHint => '포트 선택';

  @override
  String get serialPortRefresh => '포트 목록 새로 고침';

  @override
  String get serialNoPorts => '연결된 시리얼 포트가 없습니다. USB 장치를 꽂으면 자동으로 나타납니다.';

  @override
  String get serialBaud => '보드레이트';

  @override
  String get serialBaudInvalid => '1 이상의 숫자를 입력하세요';

  @override
  String get serialDataBits => '데이터 비트';

  @override
  String get serialParity => '패리티';

  @override
  String get serialStopBits => '정지 비트';

  @override
  String get serialFlow => '흐름 제어';

  @override
  String get serialParityNone => '없음 (N)';

  @override
  String get serialParityOdd => '홀수 (O)';

  @override
  String get serialParityEven => '짝수 (E)';

  @override
  String get serialParityMark => '마크 (M)';

  @override
  String get serialParitySpace => '스페이스 (S)';

  @override
  String get serialFlowNone => '없음';

  @override
  String get serialFlowRtsCts => 'RTS/CTS (하드웨어)';

  @override
  String get serialFlowXonXoff => 'XON/XOFF (소프트웨어)';

  @override
  String get serialFlowDtrDsr => 'DTR/DSR (하드웨어)';

  @override
  String serialErrorOpen(String detail) {
    return '포트를 열지 못했습니다: $detail';
  }

  @override
  String serialErrorIo(String detail) {
    return '포트 읽기/쓰기 오류: $detail';
  }

  @override
  String get serialErrorNotOpen => '열린 포트가 없습니다.';

  @override
  String get serialErrorDisconnected => '장치가 분리되었습니다.';

  @override
  String get serialViewTerminal => '터미널 보기';

  @override
  String get serialViewHex => 'Hex 보기';

  @override
  String get serialEcho => '로컬 에코';

  @override
  String get serialEchoTooltip =>
      'LineSender로 보낸 내용을 터미널 화면에도 그대로 보여 줍니다. 장치가 입력을 되돌려 주지 않을 때 켭니다.';

  @override
  String serialBytes(int count) {
    return '수신 $count 바이트';
  }

  @override
  String get serialHexEmpty => '아직 받은 데이터가 없습니다.';

  @override
  String get helpSerialBar =>
      '시리얼 도구 줄\n터미널 보기와 Hex 보기를 바꾸고, 로컬 에코를 켜고 끕니다. Hex 보기는 터미널 화면이 아니라 실제로 받은 바이트를 보여 줍니다.';

  @override
  String get tabNewSsh => '새 SSH 연결';

  @override
  String get tabNewSerial => '새 시리얼 연결';
}
