import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @aboutTooltip.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get aboutTooltip;

  /// No description provided for @aboutVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전 {version} (빌드 {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutRepository.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @aboutMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 정보'**
  String aboutMenuItem(String appName);

  /// No description provided for @themeMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get themeMenuTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageMenuTooltip;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기 / System'**
  String get languageSystem;

  /// No description provided for @languageSystemShort.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get languageSystemShort;

  /// No description provided for @aboutTagline.
  ///
  /// In ko, this message translates to:
  /// **'SSH 터미널과 SFTP 파일 탐색기를 한 창에서'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'하나의 SSH 연결로 터미널과 SFTP 파일 탐색기를 나란히 보여 줍니다. 파일을 끌어다 놓아 올리고 내려받고, 원할 때만 터미널과 탐색기의 경로를 맞춥니다.'**
  String get aboutDescription;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'서버에 연결해 시작하세요'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyAction.
  ///
  /// In ko, this message translates to:
  /// **'연결'**
  String get homeEmptyAction;

  /// No description provided for @updateCheckMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 확인'**
  String get updateCheckMenuItem;

  /// No description provided for @updateChecking.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하는 중…'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 있습니다'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} {latest} 버전이 나왔습니다. (현재 {current})'**
  String updateAvailableBody(String appName, String current, String latest);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In ko, this message translates to:
  /// **'변경 내용'**
  String get updateReleaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateLater;

  /// No description provided for @updateSkipVersion.
  ///
  /// In ko, this message translates to:
  /// **'이 버전 건너뛰기'**
  String get updateSkipVersion;

  /// No description provided for @updateDownloading.
  ///
  /// In ko, this message translates to:
  /// **'내려받는 중…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In ko, this message translates to:
  /// **'파일을 확인하는 중…'**
  String get updateVerifying;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In ko, this message translates to:
  /// **'{received} / {total}'**
  String updateDownloadProgress(String received, String total);

  /// No description provided for @updateCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get updateCancel;

  /// No description provided for @updateFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트하지 못했습니다'**
  String get updateFailedTitle;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하지 못했습니다'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In ko, this message translates to:
  /// **'내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorInstall.
  ///
  /// In ko, this message translates to:
  /// **'설치를 시작하지 못했습니다.'**
  String get updateErrorInstall;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorGeneric;

  /// No description provided for @updateUpToDateTitle.
  ///
  /// In ko, this message translates to:
  /// **'최신 버전입니다'**
  String get updateUpToDateTitle;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In ko, this message translates to:
  /// **'{version} 버전을 사용 중입니다.'**
  String updateUpToDateBody(String version);

  /// No description provided for @updateUnavailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'직접 설치해 주세요'**
  String get updateUnavailableTitle;

  /// No description provided for @updateUnavailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{latest} 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.'**
  String updateUnavailableBody(String latest);

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In ko, this message translates to:
  /// **'릴리스 페이지 열기'**
  String get updateOpenReleasePage;

  /// No description provided for @updateBrowserDownloadTitle.
  ///
  /// In ko, this message translates to:
  /// **'브라우저에서 내려받습니다'**
  String get updateBrowserDownloadTitle;

  /// No description provided for @updateBrowserDownloadBody.
  ///
  /// In ko, this message translates to:
  /// **'브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateBrowserDownloadBody(String appName);

  /// No description provided for @updateMacosOpenedTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 창이 열렸습니다'**
  String get updateMacosOpenedTitle;

  /// No description provided for @updateMacosOpenedBody.
  ///
  /// In ko, this message translates to:
  /// **'열린 창에서 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateMacosOpenedBody(String appName);

  /// No description provided for @updateWindowsInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 프로그램을 열었습니다'**
  String get updateWindowsInstallTitle;

  /// No description provided for @updateWindowsInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'설치하려면 {appName} 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.'**
  String updateWindowsInstallBody(String appName);

  /// No description provided for @updateQuitApp.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 종료'**
  String updateQuitApp(String appName);

  /// No description provided for @updateLinuxInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치를 준비했습니다'**
  String get updateLinuxInstallTitle;

  /// No description provided for @updateLinuxInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.'**
  String updateLinuxInstallBody(String appName);

  /// No description provided for @updateQuitAndInstall.
  ///
  /// In ko, this message translates to:
  /// **'종료하고 설치'**
  String get updateQuitAndInstall;

  /// No description provided for @updateBusyTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금은 업데이트할 수 없습니다'**
  String get updateBusyTitle;

  /// No description provided for @updateBusyBody.
  ///
  /// In ko, this message translates to:
  /// **'작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.'**
  String get updateBusyBody;

  /// No description provided for @tabNew.
  ///
  /// In ko, this message translates to:
  /// **'새 연결'**
  String get tabNew;

  /// No description provided for @tabClose.
  ///
  /// In ko, this message translates to:
  /// **'탭 닫기'**
  String get tabClose;

  /// No description provided for @connectTitle.
  ///
  /// In ko, this message translates to:
  /// **'서버에 연결'**
  String get connectTitle;

  /// No description provided for @connectSavedProfiles.
  ///
  /// In ko, this message translates to:
  /// **'저장된 접속'**
  String get connectSavedProfiles;

  /// No description provided for @connectNewProfile.
  ///
  /// In ko, this message translates to:
  /// **'새 접속'**
  String get connectNewProfile;

  /// No description provided for @connectHost.
  ///
  /// In ko, this message translates to:
  /// **'호스트'**
  String get connectHost;

  /// No description provided for @connectPort.
  ///
  /// In ko, this message translates to:
  /// **'포트'**
  String get connectPort;

  /// No description provided for @connectUser.
  ///
  /// In ko, this message translates to:
  /// **'사용자'**
  String get connectUser;

  /// No description provided for @connectPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get connectPassword;

  /// No description provided for @connectKeyFile.
  ///
  /// In ko, this message translates to:
  /// **'개인 키 파일 (선택)'**
  String get connectKeyFile;

  /// No description provided for @connectKeyBrowse.
  ///
  /// In ko, this message translates to:
  /// **'찾아보기'**
  String get connectKeyBrowse;

  /// No description provided for @connectKeyPassphrase.
  ///
  /// In ko, this message translates to:
  /// **'키 암호 (있으면)'**
  String get connectKeyPassphrase;

  /// No description provided for @connectSaveProfile.
  ///
  /// In ko, this message translates to:
  /// **'이 접속 정보 저장 (비밀번호는 저장하지 않습니다)'**
  String get connectSaveProfile;

  /// No description provided for @connectDeleteProfile.
  ///
  /// In ko, this message translates to:
  /// **'저장된 접속 삭제'**
  String get connectDeleteProfile;

  /// No description provided for @connectAction.
  ///
  /// In ko, this message translates to:
  /// **'연결'**
  String get connectAction;

  /// No description provided for @connecting.
  ///
  /// In ko, this message translates to:
  /// **'연결 중…'**
  String get connecting;

  /// No description provided for @connectFailed.
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했습니다: {detail}'**
  String connectFailed(String detail);

  /// No description provided for @connectHostKeyMismatch.
  ///
  /// In ko, this message translates to:
  /// **'{host}의 호스트 키가 이전에 저장한 것과 다릅니다. 중간자 공격일 수 있어 연결을 거부했습니다.'**
  String connectHostKeyMismatch(String host);

  /// No description provided for @connectClosed.
  ///
  /// In ko, this message translates to:
  /// **'서버가 연결을 닫았습니다.'**
  String get connectClosed;

  /// No description provided for @connectReconnect.
  ///
  /// In ko, this message translates to:
  /// **'다시 연결'**
  String get connectReconnect;

  /// No description provided for @connectLostTitle.
  ///
  /// In ko, this message translates to:
  /// **'연결이 끊겼습니다'**
  String get connectLostTitle;

  /// No description provided for @connectLostBody.
  ///
  /// In ko, this message translates to:
  /// **'다시 연결할까요, 아니면 이 탭을 닫을까요? 스크립트 입력 칸에 저장하지 않은 내용이 있으면 이어서 저장할지 버릴지 묻습니다.'**
  String get connectLostBody;

  /// No description provided for @connectDisconnect.
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get connectDisconnect;

  /// No description provided for @sftpTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일'**
  String get sftpTitle;

  /// No description provided for @sftpUp.
  ///
  /// In ko, this message translates to:
  /// **'상위 폴더'**
  String get sftpUp;

  /// No description provided for @sftpRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로 고침'**
  String get sftpRefresh;

  /// No description provided for @sftpNewFolder.
  ///
  /// In ko, this message translates to:
  /// **'새 폴더'**
  String get sftpNewFolder;

  /// No description provided for @sftpFolderName.
  ///
  /// In ko, this message translates to:
  /// **'폴더 이름'**
  String get sftpFolderName;

  /// No description provided for @sftpRename.
  ///
  /// In ko, this message translates to:
  /// **'이름 바꾸기'**
  String get sftpRename;

  /// No description provided for @sftpNewName.
  ///
  /// In ko, this message translates to:
  /// **'새 이름'**
  String get sftpNewName;

  /// No description provided for @sftpDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get sftpDelete;

  /// No description provided for @sftpDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'{name}을(를) 삭제할까요? 되돌릴 수 없습니다.'**
  String sftpDeleteConfirm(String name);

  /// No description provided for @sftpDownload.
  ///
  /// In ko, this message translates to:
  /// **'다운로드'**
  String get sftpDownload;

  /// No description provided for @sftpDownloadConfirm.
  ///
  /// In ko, this message translates to:
  /// **'여기로 받기'**
  String get sftpDownloadConfirm;

  /// No description provided for @sftpEmpty.
  ///
  /// In ko, this message translates to:
  /// **'비어 있는 폴더입니다'**
  String get sftpEmpty;

  /// No description provided for @sftpDropHint.
  ///
  /// In ko, this message translates to:
  /// **'파일이나 폴더를 끌어다 놓으면 이 폴더로 업로드합니다'**
  String get sftpDropHint;

  /// No description provided for @sftpDropActive.
  ///
  /// In ko, this message translates to:
  /// **'놓으면 업로드합니다'**
  String get sftpDropActive;

  /// No description provided for @sftpColName.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get sftpColName;

  /// No description provided for @sftpColSize.
  ///
  /// In ko, this message translates to:
  /// **'크기'**
  String get sftpColSize;

  /// No description provided for @sftpColModified.
  ///
  /// In ko, this message translates to:
  /// **'수정한 날짜'**
  String get sftpColModified;

  /// No description provided for @sftpError.
  ///
  /// In ko, this message translates to:
  /// **'목록을 불러오지 못했습니다: {detail}'**
  String sftpError(String detail);

  /// No description provided for @sftpOverwriteTitle.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓸까요?'**
  String get sftpOverwriteTitle;

  /// No description provided for @sftpOverwriteBody.
  ///
  /// In ko, this message translates to:
  /// **'이미 있는 항목: {names}'**
  String sftpOverwriteBody(String names);

  /// No description provided for @sftpOverwrite.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓰기'**
  String get sftpOverwrite;

  /// No description provided for @localDropActive.
  ///
  /// In ko, this message translates to:
  /// **'놓으면 이 폴더로 복사합니다'**
  String get localDropActive;

  /// No description provided for @terminalDropPath.
  ///
  /// In ko, this message translates to:
  /// **'놓으면 경로를 입력합니다'**
  String get terminalDropPath;

  /// No description provided for @terminalDropUpload.
  ///
  /// In ko, this message translates to:
  /// **'놓으면 올리고 경로를 입력합니다'**
  String get terminalDropUpload;

  /// No description provided for @terminalDropFallback.
  ///
  /// In ko, this message translates to:
  /// **'터미널의 현재 폴더를 알 수 없어 탐색기의 폴더에 올렸습니다: {dir}'**
  String terminalDropFallback(String dir);

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get commonOk;

  /// No description provided for @pathMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'경로 이동'**
  String get pathMenuTooltip;

  /// No description provided for @pathMenuTerminalToHere.
  ///
  /// In ko, this message translates to:
  /// **'터미널을 이 폴더로 이동'**
  String get pathMenuTerminalToHere;

  /// No description provided for @pathMenuExplorerToTerminal.
  ///
  /// In ko, this message translates to:
  /// **'탐색기를 터미널 경로로 이동'**
  String get pathMenuExplorerToTerminal;

  /// No description provided for @pathCwdFailed.
  ///
  /// In ko, this message translates to:
  /// **'터미널의 현재 경로를 가져오지 못했습니다. 셸이 명령을 받을 수 있는 상태인지 확인하세요.'**
  String get pathCwdFailed;

  /// No description provided for @transferUploading.
  ///
  /// In ko, this message translates to:
  /// **'{name} 올리는 중'**
  String transferUploading(String name);

  /// No description provided for @transferDownloading.
  ///
  /// In ko, this message translates to:
  /// **'{name} 받는 중'**
  String transferDownloading(String name);

  /// No description provided for @transferDone.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get transferDone;

  /// No description provided for @transferFailed.
  ///
  /// In ko, this message translates to:
  /// **'실패: {error}'**
  String transferFailed(String error);

  /// No description provided for @transferClear.
  ///
  /// In ko, this message translates to:
  /// **'완료된 항목 지우기'**
  String get transferClear;

  /// No description provided for @senderHint.
  ///
  /// In ko, this message translates to:
  /// **'여러 줄을 미리 써 두고 Enter로 한 줄씩 전송합니다 (Ctrl+Enter: 줄바꿈)'**
  String get senderHint;

  /// No description provided for @senderLineEndingNone.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get senderLineEndingNone;

  /// No description provided for @senderLineEndingTooltip.
  ///
  /// In ko, this message translates to:
  /// **'줄 끝 문자'**
  String get senderLineEndingTooltip;

  /// No description provided for @senderSend.
  ///
  /// In ko, this message translates to:
  /// **'현재 줄 전송'**
  String get senderSend;

  /// No description provided for @statusRecording.
  ///
  /// In ko, this message translates to:
  /// **'기록 중: {file}'**
  String statusRecording(String file);

  /// No description provided for @statusStartRecording.
  ///
  /// In ko, this message translates to:
  /// **'기록 시작 ({key})'**
  String statusStartRecording(String key);

  /// No description provided for @statusStopRecording.
  ///
  /// In ko, this message translates to:
  /// **'기록 정지 ({key})'**
  String statusStopRecording(String key);

  /// No description provided for @statusRevealLog.
  ///
  /// In ko, this message translates to:
  /// **'탐색기에서 기록 파일 보기'**
  String get statusRevealLog;

  /// No description provided for @statusNoLogFile.
  ///
  /// In ko, this message translates to:
  /// **'기록한 파일이 아직 없습니다'**
  String get statusNoLogFile;

  /// No description provided for @statusCopyBuffer.
  ///
  /// In ko, this message translates to:
  /// **'터미널 내용 전체를 클립보드로 복사 (스크롤백 포함)'**
  String get statusCopyBuffer;

  /// No description provided for @statusSaveBuffer.
  ///
  /// In ko, this message translates to:
  /// **'터미널 내용 전체를 파일로 복사 (스크롤백 포함)'**
  String get statusSaveBuffer;

  /// No description provided for @statusSaveBufferConfirm.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get statusSaveBufferConfirm;

  /// No description provided for @statusBufferEmpty.
  ///
  /// In ko, this message translates to:
  /// **'터미널에 내용이 없습니다'**
  String get statusBufferEmpty;

  /// No description provided for @pathCopyHint.
  ///
  /// In ko, this message translates to:
  /// **'클릭하면 경로를 복사합니다'**
  String get pathCopyHint;

  /// No description provided for @pathCopied.
  ///
  /// In ko, this message translates to:
  /// **'경로를 클립보드에 복사했습니다: {path}'**
  String pathCopied(String path);

  /// No description provided for @statusBufferCopied.
  ///
  /// In ko, this message translates to:
  /// **'{lines}줄을 클립보드에 복사했습니다'**
  String statusBufferCopied(int lines);

  /// No description provided for @statusBufferSaved.
  ///
  /// In ko, this message translates to:
  /// **'{file}에 저장했습니다'**
  String statusBufferSaved(String file);

  /// No description provided for @statusStripAnsi.
  ///
  /// In ko, this message translates to:
  /// **'이스케이프 제거'**
  String get statusStripAnsi;

  /// No description provided for @statusStripAnsiTooltip.
  ///
  /// In ko, this message translates to:
  /// **'색·커서 이동 같은 제어 시퀀스를 빼고 텍스트만 기록합니다'**
  String get statusStripAnsiTooltip;

  /// No description provided for @logSaveConfirm.
  ///
  /// In ko, this message translates to:
  /// **'기록 시작'**
  String get logSaveConfirm;

  /// No description provided for @sftpDragCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 항목'**
  String sftpDragCount(int count);

  /// No description provided for @sftpDeleteConfirmMany.
  ///
  /// In ko, this message translates to:
  /// **'선택한 {count}개 항목을 삭제할까요? 되돌릴 수 없습니다.'**
  String sftpDeleteConfirmMany(int count);

  /// No description provided for @addressBookTitle.
  ///
  /// In ko, this message translates to:
  /// **'주소록'**
  String get addressBookTitle;

  /// No description provided for @addressBookTooltip.
  ///
  /// In ko, this message translates to:
  /// **'주소록 ({key})'**
  String addressBookTooltip(String key);

  /// No description provided for @addressBookOpen.
  ///
  /// In ko, this message translates to:
  /// **'주소록 열기'**
  String get addressBookOpen;

  /// No description provided for @addressBookSearch.
  ///
  /// In ko, this message translates to:
  /// **'이름·호스트·그룹 검색'**
  String get addressBookSearch;

  /// No description provided for @addressBookEmpty.
  ///
  /// In ko, this message translates to:
  /// **'저장된 접속이 없습니다. 아래 \'새 접속\'으로 추가하세요.'**
  String get addressBookEmpty;

  /// No description provided for @addressBookNoMatch.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과가 없습니다'**
  String get addressBookNoMatch;

  /// No description provided for @addressBookNew.
  ///
  /// In ko, this message translates to:
  /// **'새 접속'**
  String get addressBookNew;

  /// No description provided for @addressBookEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get addressBookEdit;

  /// No description provided for @addressBookConnect.
  ///
  /// In ko, this message translates to:
  /// **'연결'**
  String get addressBookConnect;

  /// No description provided for @addressBookDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get addressBookDelete;

  /// No description provided for @addressBookDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'{name}을(를) 주소록에서 삭제할까요?'**
  String addressBookDeleteConfirm(String name);

  /// No description provided for @addressBookUngrouped.
  ///
  /// In ko, this message translates to:
  /// **'그룹 없음'**
  String get addressBookUngrouped;

  /// No description provided for @addressBookName.
  ///
  /// In ko, this message translates to:
  /// **'이름 (비우면 user@host)'**
  String get addressBookName;

  /// No description provided for @addressBookGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹'**
  String get addressBookGroup;

  /// No description provided for @addressBookNote.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get addressBookNote;

  /// No description provided for @addressBookSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get addressBookSave;

  /// No description provided for @connectPromptTitle.
  ///
  /// In ko, this message translates to:
  /// **'{label}에 연결'**
  String connectPromptTitle(String label);

  /// No description provided for @connectPromptHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 저장되지 않습니다'**
  String get connectPromptHint;

  /// No description provided for @settingsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsSectionRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로 고침 옵션'**
  String get settingsSectionRefresh;

  /// No description provided for @settingsSectionTerminalFont.
  ///
  /// In ko, this message translates to:
  /// **'터미널 글꼴'**
  String get settingsSectionTerminalFont;

  /// No description provided for @settingsSectionStartup.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get settingsSectionStartup;

  /// No description provided for @restoreTabs.
  ///
  /// In ko, this message translates to:
  /// **'마지막에 열어 둔 탭 다시 열기'**
  String get restoreTabs;

  /// No description provided for @restoreTabsHelp.
  ///
  /// In ko, this message translates to:
  /// **'로컬 셸은 같은 폴더에서 바로 열고, SSH와 시리얼은 접속 정보만 채워 둡니다. 비밀번호는 저장하지 않으며 자동으로 연결하지 않습니다.'**
  String get restoreTabsHelp;

  /// No description provided for @refreshLocal.
  ///
  /// In ko, this message translates to:
  /// **'로컬 폴더 자동 새로 고침'**
  String get refreshLocal;

  /// No description provided for @refreshLocalHelp.
  ///
  /// In ko, this message translates to:
  /// **'보이는 탭의 폴더를 5초마다 다시 읽습니다.'**
  String get refreshLocalHelp;

  /// No description provided for @refreshSsh.
  ///
  /// In ko, this message translates to:
  /// **'SFTP 폴더 자동 새로 고침'**
  String get refreshSsh;

  /// No description provided for @refreshSshHelp.
  ///
  /// In ko, this message translates to:
  /// **'보이는 탭의 서버 폴더를 5초마다 다시 읽습니다. 네트워크를 쓰므로 기본은 꺼짐입니다.'**
  String get refreshSshHelp;

  /// No description provided for @terminalFontFamily.
  ///
  /// In ko, this message translates to:
  /// **'글꼴'**
  String get terminalFontFamily;

  /// No description provided for @terminalFontBundled.
  ///
  /// In ko, this message translates to:
  /// **'{name} (내장)'**
  String terminalFontBundled(String name);

  /// No description provided for @terminalFontCustom.
  ///
  /// In ko, this message translates to:
  /// **'직접 입력…'**
  String get terminalFontCustom;

  /// No description provided for @terminalFontCustomName.
  ///
  /// In ko, this message translates to:
  /// **'설치된 글꼴 이름'**
  String get terminalFontCustomName;

  /// No description provided for @terminalFontCustomHelp.
  ///
  /// In ko, this message translates to:
  /// **'OS에 설치된 글꼴의 이름을 그대로 적으세요. 없는 이름이면 내장 글꼴로 대신 표시됩니다.'**
  String get terminalFontCustomHelp;

  /// No description provided for @terminalFontSize.
  ///
  /// In ko, this message translates to:
  /// **'크기'**
  String get terminalFontSize;

  /// No description provided for @terminalFontReset.
  ///
  /// In ko, this message translates to:
  /// **'기본값으로'**
  String get terminalFontReset;

  /// No description provided for @terminalScrollback.
  ///
  /// In ko, this message translates to:
  /// **'스크롤백 줄 수'**
  String get terminalScrollback;

  /// No description provided for @terminalScrollbackHelp.
  ///
  /// In ko, this message translates to:
  /// **'위로 스크롤해 다시 볼 수 있는 지난 출력의 최대 줄 수입니다. 새로 여는 탭부터 적용되고, 열려 있는 탭은 그대로입니다.'**
  String get terminalScrollbackHelp;

  /// No description provided for @terminalScrollbackLines.
  ///
  /// In ko, this message translates to:
  /// **'{count}줄'**
  String terminalScrollbackLines(int count);

  /// No description provided for @localOpen.
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get localOpen;

  /// No description provided for @localReveal.
  ///
  /// In ko, this message translates to:
  /// **'파일 관리자에서 보기'**
  String get localReveal;

  /// No description provided for @localPlaces.
  ///
  /// In ko, this message translates to:
  /// **'자주 가는 곳'**
  String get localPlaces;

  /// No description provided for @localFolderError.
  ///
  /// In ko, this message translates to:
  /// **'폴더를 읽지 못했습니다: {detail}'**
  String localFolderError(String detail);

  /// No description provided for @shellExited.
  ///
  /// In ko, this message translates to:
  /// **'셸이 종료되었습니다 (종료 코드 {code})'**
  String shellExited(int code);

  /// No description provided for @shellRestart.
  ///
  /// In ko, this message translates to:
  /// **'다시 시작'**
  String get shellRestart;

  /// No description provided for @shellStartFailed.
  ///
  /// In ko, this message translates to:
  /// **'셸을 시작하지 못했습니다: {detail}'**
  String shellStartFailed(String detail);

  /// No description provided for @shellTerminate.
  ///
  /// In ko, this message translates to:
  /// **'셸 종료'**
  String get shellTerminate;

  /// No description provided for @newTabSsh.
  ///
  /// In ko, this message translates to:
  /// **'SSH 연결'**
  String get newTabSsh;

  /// No description provided for @newTabLocalShell.
  ///
  /// In ko, this message translates to:
  /// **'로컬 셸'**
  String get newTabLocalShell;

  /// No description provided for @newTabNoShells.
  ///
  /// In ko, this message translates to:
  /// **'사용할 수 있는 로컬 셸을 찾지 못했습니다'**
  String get newTabNoShells;

  /// No description provided for @senderOpen.
  ///
  /// In ko, this message translates to:
  /// **'스크립트 열기 ({key})'**
  String senderOpen(String key);

  /// No description provided for @senderSave.
  ///
  /// In ko, this message translates to:
  /// **'저장 ({key})'**
  String senderSave(String key);

  /// No description provided for @senderSaveAs.
  ///
  /// In ko, this message translates to:
  /// **'다른 이름으로 저장…'**
  String get senderSaveAs;

  /// No description provided for @senderNew.
  ///
  /// In ko, this message translates to:
  /// **'새로 만들기'**
  String get senderNew;

  /// No description provided for @senderModified.
  ///
  /// In ko, this message translates to:
  /// **'변경됨'**
  String get senderModified;

  /// No description provided for @senderUnsavedTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않은 변경 사항'**
  String get senderUnsavedTitle;

  /// No description provided for @senderUnsavedBody.
  ///
  /// In ko, this message translates to:
  /// **'{name}의 변경 사항을 저장하지 않았습니다.'**
  String senderUnsavedBody(String name);

  /// No description provided for @senderUntitled.
  ///
  /// In ko, this message translates to:
  /// **'제목 없음'**
  String get senderUntitled;

  /// No description provided for @senderDiscard.
  ///
  /// In ko, this message translates to:
  /// **'버리기'**
  String get senderDiscard;

  /// No description provided for @senderSaveFirst.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get senderSaveFirst;

  /// No description provided for @senderFileTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'파일이 너무 큽니다 (최대 {mb}MB)'**
  String senderFileTooLarge(int mb);

  /// No description provided for @senderFileNotUtf8.
  ///
  /// In ko, this message translates to:
  /// **'UTF-8 텍스트 파일만 열 수 있습니다'**
  String get senderFileNotUtf8;

  /// No description provided for @senderDropUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'텍스트 파일(txt, md, cfg, ini 등)만 끌어넣어 열 수 있습니다'**
  String get senderDropUnsupported;

  /// No description provided for @senderRemoteNotSaved.
  ///
  /// In ko, this message translates to:
  /// **'서버 파일의 사본입니다. 고친 내용은 서버에 저장되지 않습니다.'**
  String get senderRemoteNotSaved;

  /// No description provided for @senderRemoteNotSavedShort.
  ///
  /// In ko, this message translates to:
  /// **'서버 파일의 사본 — 고쳐도 서버에는 저장되지 않음'**
  String get senderRemoteNotSavedShort;

  /// No description provided for @senderFileError.
  ///
  /// In ko, this message translates to:
  /// **'파일을 처리하지 못했습니다: {detail}'**
  String senderFileError(String detail);

  /// No description provided for @helpModeTooltip.
  ///
  /// In ko, this message translates to:
  /// **'도움말 모드'**
  String get helpModeTooltip;

  /// No description provided for @helpButton.
  ///
  /// In ko, this message translates to:
  /// **'도움말 모드\n마우스를 올린 컨트롤의 설명을 봅니다. 아무 곳이나 클릭하거나 Esc를 누르면 끝납니다.'**
  String get helpButton;

  /// No description provided for @helpDisconnect.
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기 / 셸 종료\nSSH 연결을 끊거나 로컬 셸을 종료합니다. 탭은 남습니다.'**
  String get helpDisconnect;

  /// No description provided for @helpAddressBook.
  ///
  /// In ko, this message translates to:
  /// **'주소록\n저장해 둔 SSH 접속 정보를 검색·편집하고 연결합니다. 비밀번호는 저장하지 않습니다.'**
  String get helpAddressBook;

  /// No description provided for @helpSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정\n탐색기 자동 새로 고침과 터미널 글꼴·크기·스크롤백을 바꿉니다.'**
  String get helpSettings;

  /// No description provided for @helpTheme.
  ///
  /// In ko, this message translates to:
  /// **'테마\n밝게, 어둡게, 시스템 설정 중에서 고릅니다.'**
  String get helpTheme;

  /// No description provided for @helpLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어\n앱 표시 언어를 바꿉니다.'**
  String get helpLanguage;

  /// No description provided for @helpAbout.
  ///
  /// In ko, this message translates to:
  /// **'정보\n버전, 라이선스, 업데이트 확인을 봅니다.'**
  String get helpAbout;

  /// No description provided for @helpTabs.
  ///
  /// In ko, this message translates to:
  /// **'탭\nSSH 연결과 로컬 셸을 탭으로 나눠 엽니다. 탭마다 터미널과 탐색기가 따로 있습니다.'**
  String get helpTabs;

  /// No description provided for @helpExplorerSftp.
  ///
  /// In ko, this message translates to:
  /// **'서버 탐색기 (SFTP)\n서버의 폴더와 파일입니다. 파일을 끌어넣으면 업로드, 밖으로 끌어내면 다운로드됩니다.'**
  String get helpExplorerSftp;

  /// No description provided for @helpExplorerLocal.
  ///
  /// In ko, this message translates to:
  /// **'폴더 보기\n이 PC의 폴더와 파일입니다. 삭제는 휴지통 없이 영구 삭제됩니다.'**
  String get helpExplorerLocal;

  /// No description provided for @helpTerminal.
  ///
  /// In ko, this message translates to:
  /// **'터미널\n셸 화면입니다. 글을 드래그해 복사하고, 키보드로 바로 입력합니다.'**
  String get helpTerminal;

  /// No description provided for @helpSender.
  ///
  /// In ko, this message translates to:
  /// **'줄 전송 입력 칸\n여러 줄 스크립트를 쓰거나 파일에서 불러와 한 줄씩 터미널로 보냅니다. 열기·저장도 여기서 합니다.'**
  String get helpSender;

  /// No description provided for @helpStatusBar.
  ///
  /// In ko, this message translates to:
  /// **'상태 표시줄\n연결 상태와 현재 경로 등 이 탭의 상태를 보여 줍니다.'**
  String get helpStatusBar;

  /// No description provided for @helpEmptyAction.
  ///
  /// In ko, this message translates to:
  /// **'새 연결\n새 탭을 열어 접속 화면으로 이동합니다.'**
  String get helpEmptyAction;

  /// No description provided for @helpTabItem.
  ///
  /// In ko, this message translates to:
  /// **'탭\n눌러서 이 탭으로 전환합니다. 탭마다 터미널과 탐색기가 따로 있습니다.'**
  String get helpTabItem;

  /// No description provided for @helpTabNew.
  ///
  /// In ko, this message translates to:
  /// **'새 탭\nSSH 연결 또는 이 PC의 로컬 셸을 새 탭으로 엽니다.'**
  String get helpTabNew;

  /// No description provided for @helpTabClose.
  ///
  /// In ko, this message translates to:
  /// **'탭 닫기\n이 탭을 닫습니다. 연결 중이면 끊깁니다.'**
  String get helpTabClose;

  /// No description provided for @helpPaneUp.
  ///
  /// In ko, this message translates to:
  /// **'상위 폴더\n한 단계 위 폴더로 이동합니다.'**
  String get helpPaneUp;

  /// No description provided for @helpPanePath.
  ///
  /// In ko, this message translates to:
  /// **'현재 경로\n누르면 전체 경로를 클립보드에 복사합니다.'**
  String get helpPanePath;

  /// No description provided for @helpPaneRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로 고침\n폴더 목록을 다시 읽습니다.'**
  String get helpPaneRefresh;

  /// No description provided for @helpPaneNewFolder.
  ///
  /// In ko, this message translates to:
  /// **'새 폴더\n현재 폴더 안에 새 폴더를 만듭니다.'**
  String get helpPaneNewFolder;

  /// No description provided for @helpPanePathSync.
  ///
  /// In ko, this message translates to:
  /// **'경로 동기화\n터미널을 이 폴더로 옮기거나, 탐색기를 터미널의 현재 경로로 옮깁니다. 자동으로는 옮겨지지 않습니다.'**
  String get helpPanePathSync;

  /// No description provided for @helpPanePlaces.
  ///
  /// In ko, this message translates to:
  /// **'자주 가는 곳\n홈, 바탕 화면 등 자주 쓰는 폴더로 바로 이동합니다.'**
  String get helpPanePlaces;

  /// No description provided for @helpFileRow.
  ///
  /// In ko, this message translates to:
  /// **'파일 / 폴더\n두 번 누르면 열고, Ctrl/⌘·Shift로 여러 개를 고릅니다. 오른쪽 버튼으로 메뉴를 열고, 끌어서 옮기거나 업로드·다운로드합니다.'**
  String get helpFileRow;

  /// No description provided for @helpTransferClear.
  ///
  /// In ko, this message translates to:
  /// **'완료 항목 지우기\n끝난 전송 기록을 목록에서 지웁니다.'**
  String get helpTransferClear;

  /// No description provided for @helpStatusStripAnsi.
  ///
  /// In ko, this message translates to:
  /// **'이스케이프 제거\n켜면 기록·복사·저장 때 색상 등 제어 문자를 뺀 글만 남깁니다.'**
  String get helpStatusStripAnsi;

  /// No description provided for @helpStatusCopyBuffer.
  ///
  /// In ko, this message translates to:
  /// **'터미널 내용 복사\n터미널에 쌓인 내용 전체를 클립보드로 복사합니다.'**
  String get helpStatusCopyBuffer;

  /// No description provided for @helpStatusSaveBuffer.
  ///
  /// In ko, this message translates to:
  /// **'터미널 내용 저장\n터미널에 쌓인 내용 전체를 파일로 저장합니다.'**
  String get helpStatusSaveBuffer;

  /// No description provided for @helpStatusRecord.
  ///
  /// In ko, this message translates to:
  /// **'기록 시작 / 중지\n터미널 출력을 파일에 기록합니다. 연결되어 있을 때 시작할 수 있습니다.'**
  String get helpStatusRecord;

  /// No description provided for @helpStatusRevealLog.
  ///
  /// In ko, this message translates to:
  /// **'기록 파일 보기\n기록한 파일이 있는 폴더를 파일 관리자에서 엽니다.'**
  String get helpStatusRevealLog;

  /// No description provided for @helpSenderNew.
  ///
  /// In ko, this message translates to:
  /// **'새로 만들기\n입력 칸을 비우고 파일과의 연결을 끊습니다. 변경이 있으면 먼저 묻습니다.'**
  String get helpSenderNew;

  /// No description provided for @helpSenderOpen.
  ///
  /// In ko, this message translates to:
  /// **'열기\n텍스트 파일(UTF-8)을 입력 칸으로 불러옵니다.'**
  String get helpSenderOpen;

  /// No description provided for @helpSenderSave.
  ///
  /// In ko, this message translates to:
  /// **'저장\n입력 칸의 내용을 연결된 파일에 저장합니다. 연결된 파일이 없으면 새 이름을 묻습니다.'**
  String get helpSenderSave;

  /// No description provided for @helpSenderSaveAs.
  ///
  /// In ko, this message translates to:
  /// **'다른 이름으로 저장\n입력 칸의 내용을 다른 파일로 저장합니다.'**
  String get helpSenderSaveAs;

  /// No description provided for @helpSenderLineEnding.
  ///
  /// In ko, this message translates to:
  /// **'줄 끝 문자\n한 줄을 보낸 뒤 덧붙일 문자(CR, LF, CRLF, 없음)를 고릅니다. SSH에서는 보통 CR입니다.'**
  String get helpSenderLineEnding;

  /// No description provided for @helpSenderSend.
  ///
  /// In ko, this message translates to:
  /// **'보내기\n커서가 있는 줄을 터미널로 보내고 다음 줄로 넘어갑니다. 연결되어 있어야 합니다.'**
  String get helpSenderSend;

  /// No description provided for @newTabSerial.
  ///
  /// In ko, this message translates to:
  /// **'시리얼 포트'**
  String get newTabSerial;

  /// No description provided for @serialTitle.
  ///
  /// In ko, this message translates to:
  /// **'시리얼 연결'**
  String get serialTitle;

  /// No description provided for @serialPort.
  ///
  /// In ko, this message translates to:
  /// **'포트'**
  String get serialPort;

  /// No description provided for @serialPortHint.
  ///
  /// In ko, this message translates to:
  /// **'포트 선택'**
  String get serialPortHint;

  /// No description provided for @serialPortRefresh.
  ///
  /// In ko, this message translates to:
  /// **'포트 목록 새로 고침'**
  String get serialPortRefresh;

  /// No description provided for @serialNoPorts.
  ///
  /// In ko, this message translates to:
  /// **'연결된 시리얼 포트가 없습니다. USB 장치를 꽂으면 자동으로 나타납니다.'**
  String get serialNoPorts;

  /// No description provided for @serialBaud.
  ///
  /// In ko, this message translates to:
  /// **'보드레이트'**
  String get serialBaud;

  /// No description provided for @serialBaudInvalid.
  ///
  /// In ko, this message translates to:
  /// **'1 이상의 숫자를 입력하세요'**
  String get serialBaudInvalid;

  /// No description provided for @serialDataBits.
  ///
  /// In ko, this message translates to:
  /// **'데이터 비트'**
  String get serialDataBits;

  /// No description provided for @serialParity.
  ///
  /// In ko, this message translates to:
  /// **'패리티'**
  String get serialParity;

  /// No description provided for @serialStopBits.
  ///
  /// In ko, this message translates to:
  /// **'정지 비트'**
  String get serialStopBits;

  /// No description provided for @serialFlow.
  ///
  /// In ko, this message translates to:
  /// **'흐름 제어'**
  String get serialFlow;

  /// No description provided for @serialParityNone.
  ///
  /// In ko, this message translates to:
  /// **'없음 (N)'**
  String get serialParityNone;

  /// No description provided for @serialParityOdd.
  ///
  /// In ko, this message translates to:
  /// **'홀수 (O)'**
  String get serialParityOdd;

  /// No description provided for @serialParityEven.
  ///
  /// In ko, this message translates to:
  /// **'짝수 (E)'**
  String get serialParityEven;

  /// No description provided for @serialParityMark.
  ///
  /// In ko, this message translates to:
  /// **'마크 (M)'**
  String get serialParityMark;

  /// No description provided for @serialParitySpace.
  ///
  /// In ko, this message translates to:
  /// **'스페이스 (S)'**
  String get serialParitySpace;

  /// No description provided for @serialFlowNone.
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get serialFlowNone;

  /// No description provided for @serialFlowRtsCts.
  ///
  /// In ko, this message translates to:
  /// **'RTS/CTS (하드웨어)'**
  String get serialFlowRtsCts;

  /// No description provided for @serialFlowXonXoff.
  ///
  /// In ko, this message translates to:
  /// **'XON/XOFF (소프트웨어)'**
  String get serialFlowXonXoff;

  /// No description provided for @serialFlowDtrDsr.
  ///
  /// In ko, this message translates to:
  /// **'DTR/DSR (하드웨어)'**
  String get serialFlowDtrDsr;

  /// No description provided for @serialErrorOpen.
  ///
  /// In ko, this message translates to:
  /// **'포트를 열지 못했습니다: {detail}'**
  String serialErrorOpen(String detail);

  /// No description provided for @serialErrorIo.
  ///
  /// In ko, this message translates to:
  /// **'포트 읽기/쓰기 오류: {detail}'**
  String serialErrorIo(String detail);

  /// No description provided for @serialErrorNotOpen.
  ///
  /// In ko, this message translates to:
  /// **'열린 포트가 없습니다.'**
  String get serialErrorNotOpen;

  /// No description provided for @serialErrorDisconnected.
  ///
  /// In ko, this message translates to:
  /// **'장치가 분리되었습니다.'**
  String get serialErrorDisconnected;

  /// No description provided for @serialViewTerminal.
  ///
  /// In ko, this message translates to:
  /// **'터미널 보기'**
  String get serialViewTerminal;

  /// No description provided for @serialViewHex.
  ///
  /// In ko, this message translates to:
  /// **'Hex 보기'**
  String get serialViewHex;

  /// No description provided for @serialEcho.
  ///
  /// In ko, this message translates to:
  /// **'로컬 에코'**
  String get serialEcho;

  /// No description provided for @serialEchoTooltip.
  ///
  /// In ko, this message translates to:
  /// **'LineSender로 보낸 내용을 터미널 화면에도 그대로 보여 줍니다. 장치가 입력을 되돌려 주지 않을 때 켭니다.'**
  String get serialEchoTooltip;

  /// No description provided for @serialBytes.
  ///
  /// In ko, this message translates to:
  /// **'수신 {count} 바이트'**
  String serialBytes(int count);

  /// No description provided for @serialHexEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 받은 데이터가 없습니다.'**
  String get serialHexEmpty;

  /// No description provided for @helpSerialBar.
  ///
  /// In ko, this message translates to:
  /// **'시리얼 도구 줄\n터미널 보기와 Hex 보기를 바꾸고, 로컬 에코를 켜고 끕니다. Hex 보기는 터미널 화면이 아니라 실제로 받은 바이트를 보여 줍니다.'**
  String get helpSerialBar;

  /// No description provided for @tabNewSsh.
  ///
  /// In ko, this message translates to:
  /// **'새 SSH 연결'**
  String get tabNewSsh;

  /// No description provided for @tabNewSerial.
  ///
  /// In ko, this message translates to:
  /// **'새 시리얼 연결'**
  String get tabNewSerial;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
