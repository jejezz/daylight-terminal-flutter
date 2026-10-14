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
  String get aboutDescription => '하나의 SSH 연결로 터미널과 SFTP 파일 탐색기를 나란히 보여 줍니다. 파일을 끌어다 놓아 올리고 내려받고, 원할 때만 터미널과 탐색기의 경로를 맞춥니다.';

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
  String get updateErrorNetwork => '업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get updateErrorChecksum => '내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateErrorInstall => '설치를 시작하지 못했습니다.';

  @override
  String get updateErrorGeneric => '업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.';

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
  String get pathCwdFailed => '터미널의 현재 경로를 가져오지 못했습니다. 셸이 명령을 받을 수 있는 상태인지 확인하세요.';

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
  String get terminalFontTooltip => '터미널 글꼴';

  @override
  String get terminalFontTitle => '터미널 글꼴';

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
  String get terminalFontCustomHelp => 'OS에 설치된 글꼴의 이름을 그대로 적으세요. 없는 이름이면 내장 글꼴로 대신 표시됩니다.';

  @override
  String get terminalFontSize => '크기';

  @override
  String get terminalFontReset => '기본값으로';

  @override
  String get terminalScrollback => '스크롤백 줄 수';

  @override
  String get terminalScrollbackHelp => '위로 스크롤해 다시 볼 수 있는 지난 출력의 최대 줄 수입니다. 새로 여는 탭부터 적용되고, 열려 있는 탭은 그대로입니다.';

  @override
  String terminalScrollbackLines(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
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
  String get senderDropUnsupported => '텍스트 파일(txt, md, cfg, ini 등)만 끌어넣어 열 수 있습니다';

  @override
  String senderFileError(String detail) {
    return '파일을 처리하지 못했습니다: $detail';
  }
}
