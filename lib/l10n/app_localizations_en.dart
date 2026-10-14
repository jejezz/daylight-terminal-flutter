// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystem => 'System / 시스템 설정 따르기';

  @override
  String get languageSystemShort => 'System';

  @override
  String get aboutTagline => 'SSH terminal and SFTP file explorer in one window';

  @override
  String get aboutDescription => 'Shows a terminal and an SFTP file explorer side by side over a single SSH connection. Drag and drop to upload and download, and sync the terminal and explorer paths only when you ask.';

  @override
  String get homeEmptyTitle => 'Connect to a server to get started';

  @override
  String get homeEmptyAction => 'Connect';

  @override
  String get updateCheckMenuItem => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest is available. You have $current.';
  }

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying the file…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateFailedTitle => 'Couldn\'t update';

  @override
  String get updateCheckFailedTitle => 'Couldn\'t check for updates';

  @override
  String get updateErrorNetwork => 'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum => 'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric => 'The update server sent an unexpected response. Please try again later.';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'You\'re using version $version.';
  }

  @override
  String get updateUnavailableTitle => 'Install it manually';

  @override
  String updateUnavailableBody(String latest) {
    return 'Version $latest is available, but the app can\'t install it automatically. Please download it from the release page.';
  }

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateBrowserDownloadTitle => 'Downloading in your browser';

  @override
  String updateBrowserDownloadBody(String appName) {
    return 'Your browser is downloading the new version. Open the DMG and drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateMacosOpenedTitle => 'The installer window is open';

  @override
  String updateMacosOpenedBody(String appName) {
    return 'In the window that opened, drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateWindowsInstallTitle => 'The installer is open';

  @override
  String updateWindowsInstallBody(String appName) {
    return '$appName must quit before it can be updated. Follow the installer\'s instructions.';
  }

  @override
  String updateQuitApp(String appName) {
    return 'Quit $appName';
  }

  @override
  String get updateLinuxInstallTitle => 'Ready to install';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName will quit and install the update, then start again automatically.';
  }

  @override
  String get updateQuitAndInstall => 'Quit and install';

  @override
  String get updateBusyTitle => 'Can\'t update right now';

  @override
  String get updateBusyBody => 'A task is in progress. Please try again when it has finished.';

  @override
  String get tabNew => 'New connection';

  @override
  String get tabClose => 'Close tab';

  @override
  String get connectTitle => 'Connect to a server';

  @override
  String get connectSavedProfiles => 'Saved connections';

  @override
  String get connectNewProfile => 'New connection';

  @override
  String get connectHost => 'Host';

  @override
  String get connectPort => 'Port';

  @override
  String get connectUser => 'User';

  @override
  String get connectPassword => 'Password';

  @override
  String get connectKeyFile => 'Private key file (optional)';

  @override
  String get connectKeyBrowse => 'Browse';

  @override
  String get connectKeyPassphrase => 'Key passphrase (if any)';

  @override
  String get connectSaveProfile => 'Save this connection (the password is never saved)';

  @override
  String get connectDeleteProfile => 'Delete saved connection';

  @override
  String get connectAction => 'Connect';

  @override
  String get connecting => 'Connecting…';

  @override
  String connectFailed(String detail) {
    return 'Could not connect: $detail';
  }

  @override
  String connectHostKeyMismatch(String host) {
    return 'The host key of $host differs from the one saved earlier. The connection was refused because this could be a man-in-the-middle attack.';
  }

  @override
  String get connectClosed => 'The server closed the connection.';

  @override
  String get connectReconnect => 'Reconnect';

  @override
  String get connectDisconnect => 'Disconnect';

  @override
  String get sftpTitle => 'Files';

  @override
  String get sftpUp => 'Parent folder';

  @override
  String get sftpRefresh => 'Refresh';

  @override
  String get sftpNewFolder => 'New folder';

  @override
  String get sftpFolderName => 'Folder name';

  @override
  String get sftpRename => 'Rename';

  @override
  String get sftpNewName => 'New name';

  @override
  String get sftpDelete => 'Delete';

  @override
  String sftpDeleteConfirm(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get sftpDownload => 'Download';

  @override
  String get sftpDownloadConfirm => 'Download here';

  @override
  String get sftpEmpty => 'This folder is empty';

  @override
  String get sftpDropHint => 'Drop files or folders here to upload to this folder';

  @override
  String get sftpDropActive => 'Drop to upload';

  @override
  String get sftpColName => 'Name';

  @override
  String get sftpColSize => 'Size';

  @override
  String get sftpColModified => 'Modified';

  @override
  String sftpError(String detail) {
    return 'Could not load the listing: $detail';
  }

  @override
  String get sftpOverwriteTitle => 'Overwrite?';

  @override
  String sftpOverwriteBody(String names) {
    return 'Already exists: $names';
  }

  @override
  String get sftpOverwrite => 'Overwrite';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get pathMenuTooltip => 'Go to path';

  @override
  String get pathMenuTerminalToHere => 'Move terminal to this folder';

  @override
  String get pathMenuExplorerToTerminal => 'Move explorer to the terminal path';

  @override
  String get pathCwdFailed => 'Could not get the terminal\'s current path. Check that the shell is ready for commands.';

  @override
  String transferUploading(String name) {
    return 'Uploading $name';
  }

  @override
  String transferDownloading(String name) {
    return 'Downloading $name';
  }

  @override
  String get transferDone => 'Done';

  @override
  String transferFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get transferClear => 'Clear finished';

  @override
  String get senderHint => 'Write several lines ahead and send them one by one with Enter (Ctrl+Enter: new line)';

  @override
  String get senderLineEndingNone => 'None';

  @override
  String get senderLineEndingTooltip => 'Line ending';

  @override
  String get senderSend => 'Send current line';

  @override
  String statusRecording(String file) {
    return 'Recording: $file';
  }

  @override
  String statusStartRecording(String key) {
    return 'Start recording ($key)';
  }

  @override
  String statusStopRecording(String key) {
    return 'Stop recording ($key)';
  }

  @override
  String get statusRevealLog => 'Show the recording in the file manager';

  @override
  String get statusNoLogFile => 'Nothing has been recorded yet';

  @override
  String get statusStripAnsi => 'Strip escapes';

  @override
  String get statusStripAnsiTooltip => 'Record plain text without control sequences such as colors and cursor moves';

  @override
  String get logSaveConfirm => 'Start recording';

  @override
  String sftpDragCount(int count) {
    return '$count items';
  }

  @override
  String sftpDeleteConfirmMany(int count) {
    return 'Delete the $count selected items? This cannot be undone.';
  }

  @override
  String get addressBookTitle => 'Address book';

  @override
  String addressBookTooltip(String key) {
    return 'Address book ($key)';
  }

  @override
  String get addressBookOpen => 'Open address book';

  @override
  String get addressBookSearch => 'Search name, host or group';

  @override
  String get addressBookEmpty => 'No saved connections yet. Add one with \'New connection\' below.';

  @override
  String get addressBookNoMatch => 'No matches';

  @override
  String get addressBookNew => 'New connection';

  @override
  String get addressBookEdit => 'Edit';

  @override
  String get addressBookConnect => 'Connect';

  @override
  String get addressBookDelete => 'Delete';

  @override
  String addressBookDeleteConfirm(String name) {
    return 'Remove $name from the address book?';
  }

  @override
  String get addressBookUngrouped => 'No group';

  @override
  String get addressBookName => 'Name (user@host if empty)';

  @override
  String get addressBookGroup => 'Group';

  @override
  String get addressBookNote => 'Note';

  @override
  String get addressBookSave => 'Save';

  @override
  String connectPromptTitle(String label) {
    return 'Connect to $label';
  }

  @override
  String get connectPromptHint => 'The password is not saved';

  @override
  String get terminalFontTooltip => 'Terminal font';

  @override
  String get terminalFontTitle => 'Terminal font';

  @override
  String get terminalFontFamily => 'Font';

  @override
  String terminalFontBundled(String name) {
    return '$name (bundled)';
  }

  @override
  String get terminalFontCustom => 'Enter a name…';

  @override
  String get terminalFontCustomName => 'Installed font name';

  @override
  String get terminalFontCustomHelp => 'Type the exact name of a font installed on this computer. If it is not found, the bundled font is used instead.';

  @override
  String get terminalFontSize => 'Size';

  @override
  String get terminalFontReset => 'Reset to default';

  @override
  String get terminalScrollback => 'Scrollback lines';

  @override
  String get terminalScrollbackHelp => 'The most past output lines you can scroll back to. Applies to tabs opened from now on; open tabs keep their current setting.';

  @override
  String terminalScrollbackLines(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString lines';
  }

  @override
  String get localOpen => 'Open';

  @override
  String get localReveal => 'Show in file manager';

  @override
  String get localPlaces => 'Places';

  @override
  String localFolderError(String detail) {
    return 'Could not read the folder: $detail';
  }

  @override
  String shellExited(int code) {
    return 'The shell has exited (exit code $code)';
  }

  @override
  String get shellRestart => 'Restart';

  @override
  String shellStartFailed(String detail) {
    return 'Could not start the shell: $detail';
  }

  @override
  String get shellTerminate => 'End shell';

  @override
  String get newTabSsh => 'SSH connection';

  @override
  String get newTabLocalShell => 'Local shell';

  @override
  String get newTabNoShells => 'No local shell was found';

  @override
  String senderOpen(String key) {
    return 'Open a script ($key)';
  }

  @override
  String senderSave(String key) {
    return 'Save ($key)';
  }

  @override
  String get senderSaveAs => 'Save as…';

  @override
  String get senderNew => 'New script';

  @override
  String get senderModified => 'modified';

  @override
  String get senderUnsavedTitle => 'Unsaved changes';

  @override
  String senderUnsavedBody(String name) {
    return '$name has changes that are not saved.';
  }

  @override
  String get senderUntitled => 'Untitled';

  @override
  String get senderDiscard => 'Discard';

  @override
  String get senderSaveFirst => 'Save';

  @override
  String senderFileTooLarge(int mb) {
    return 'The file is too large (max $mb MB)';
  }

  @override
  String get senderFileNotUtf8 => 'Only UTF-8 text files can be opened';

  @override
  String get senderDropUnsupported => 'Only text files (txt, md, cfg, ini, ...) can be dropped here';

  @override
  String senderFileError(String detail) {
    return 'Could not handle the file: $detail';
  }
}
