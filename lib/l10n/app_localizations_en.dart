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
  String get aboutTagline =>
      'SSH terminal and SFTP file explorer in one window';

  @override
  String get aboutDescription =>
      'Shows a terminal and an SFTP file explorer side by side over a single SSH connection. Drag and drop to upload and download, and sync the terminal and explorer paths only when you ask.';

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
  String get updateErrorNetwork =>
      'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric =>
      'The update server sent an unexpected response. Please try again later.';

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
  String get updateBusyBody =>
      'A task is in progress. Please try again when it has finished.';

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
  String get connectSaveProfile =>
      'Save this connection (the password is never saved)';

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
  String get sftpDropHint =>
      'Drop files or folders here to upload to this folder';

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
  String get localDropActive => 'Drop to copy into this folder';

  @override
  String get terminalDropPath => 'Drop to type the path';

  @override
  String get terminalDropUpload => 'Drop to upload and type the path';

  @override
  String terminalDropFallback(String dir) {
    return 'The terminal\'s current folder is unknown, so the files were uploaded to the explorer folder: $dir';
  }

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
  String get pathCwdFailed =>
      'Could not get the terminal\'s current path. Check that the shell is ready for commands.';

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
  String get senderHint =>
      'Write several lines ahead and send them one by one with Enter (Ctrl+Enter: new line)';

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
  String get statusCopyBuffer =>
      'Copy everything in the terminal to the clipboard (including scrollback)';

  @override
  String get statusSaveBuffer =>
      'Copy everything in the terminal to a file (including scrollback)';

  @override
  String get statusSaveBufferConfirm => 'Save';

  @override
  String get statusBufferEmpty => 'The terminal is empty';

  @override
  String get pathCopyHint => 'Click to copy the path';

  @override
  String pathCopied(String path) {
    return 'Copied the path to the clipboard: $path';
  }

  @override
  String statusBufferCopied(int lines) {
    return 'Copied $lines lines to the clipboard';
  }

  @override
  String statusBufferSaved(String file) {
    return 'Saved to $file';
  }

  @override
  String get statusStripAnsi => 'Strip escapes';

  @override
  String get statusStripAnsiTooltip =>
      'Record plain text without control sequences such as colors and cursor moves';

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
  String get addressBookEmpty =>
      'No saved connections yet. Add one with \'New connection\' below.';

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
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionRefresh => 'Refresh';

  @override
  String get settingsSectionTerminalFont => 'Terminal font';

  @override
  String get settingsSectionStartup => 'Startup';

  @override
  String get restoreTabs => 'Reopen the tabs you had open last time';

  @override
  String get restoreTabsHelp =>
      'Local shells open in the same folder. SSH and serial tabs only get their connection details filled in — passwords are never saved and nothing connects by itself.';

  @override
  String get refreshLocal => 'Refresh local folders automatically';

  @override
  String get refreshLocalHelp =>
      'Re-reads the folder of the visible tab every 5 seconds.';

  @override
  String get refreshSsh => 'Refresh SFTP folders automatically';

  @override
  String get refreshSshHelp =>
      'Re-reads the server folder of the visible tab every 5 seconds. Off by default because it uses the network.';

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
  String get terminalFontCustomHelp =>
      'Type the exact name of a font installed on this computer. If it is not found, the bundled font is used instead.';

  @override
  String get terminalFontSize => 'Size';

  @override
  String get terminalFontReset => 'Reset to default';

  @override
  String get terminalScrollback => 'Scrollback lines';

  @override
  String get terminalScrollbackHelp =>
      'The most past output lines you can scroll back to. Applies to tabs opened from now on; open tabs keep their current setting.';

  @override
  String terminalScrollbackLines(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
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
  String get senderDropUnsupported =>
      'Only text files (txt, md, cfg, ini, ...) can be dropped here';

  @override
  String get senderRemoteNotSaved =>
      'This is a copy of a server file. Edits are not saved to the server.';

  @override
  String get senderRemoteNotSavedShort =>
      'Server file copy — edits won\'t be saved to the server';

  @override
  String senderFileError(String detail) {
    return 'Could not handle the file: $detail';
  }

  @override
  String get helpModeTooltip => 'Help mode';

  @override
  String get helpButton =>
      'Help mode\nHover over a control to see what it does. Click anywhere or press Esc to leave.';

  @override
  String get helpDisconnect =>
      'Disconnect / end shell\nCloses the SSH connection or ends the local shell. The tab stays open.';

  @override
  String get helpAddressBook =>
      'Address book\nSearch, edit and connect to saved SSH hosts. Passwords are never saved.';

  @override
  String get helpSettings =>
      'Settings\nChange explorer auto-refresh and the terminal font, size and scrollback.';

  @override
  String get helpTheme => 'Theme\nChoose light, dark, or follow the system.';

  @override
  String get helpLanguage =>
      'Language\nChange the display language of the app.';

  @override
  String get helpAbout =>
      'About\nShows the version, licenses and update check.';

  @override
  String get helpTabs =>
      'Tabs\nOpen SSH connections and local shells as tabs. Each tab has its own terminal and explorer.';

  @override
  String get helpExplorerSftp =>
      'Server explorer (SFTP)\nFolders and files on the server. Drop files here to upload, drag them out to download.';

  @override
  String get helpExplorerLocal =>
      'Folder view\nFolders and files on this PC. Deleting is permanent; there is no Recycle Bin.';

  @override
  String get helpTerminal =>
      'Terminal\nThe shell screen. Drag to select and copy text; type directly with the keyboard.';

  @override
  String get helpSender =>
      'Line sender\nWrite a multi-line script or load one from a file and send it to the terminal line by line. Open and save are here too.';

  @override
  String get helpStatusBar =>
      'Status bar\nShows the state of this tab, such as the connection and current path.';

  @override
  String get helpEmptyAction =>
      'New connection\nOpens a new tab with the connection screen.';

  @override
  String get helpTabItem =>
      'Tab\nClick to switch to this tab. Each tab has its own terminal and explorer.';

  @override
  String get helpTabNew =>
      'New tab\nOpen an SSH connection or a local shell on this PC in a new tab.';

  @override
  String get helpTabClose =>
      'Close tab\nCloses this tab. An active connection is disconnected.';

  @override
  String get helpPaneUp => 'Parent folder\nGo up one level.';

  @override
  String get helpPanePath =>
      'Current path\nClick to copy the full path to the clipboard.';

  @override
  String get helpPaneRefresh => 'Refresh\nReload the folder listing.';

  @override
  String get helpPaneNewFolder =>
      'New folder\nCreate a new folder in the current folder.';

  @override
  String get helpPanePathSync =>
      'Sync paths\nMove the terminal to this folder, or the explorer to the terminal\'s current path. Nothing moves automatically.';

  @override
  String get helpPanePlaces =>
      'Places\nJump to common folders such as Home and Desktop.';

  @override
  String get helpFileRow =>
      'File / folder\nDouble-click to open; Ctrl/⌘ and Shift select several. Right-click for a menu; drag to move, upload or download.';

  @override
  String get helpTransferClear =>
      'Clear finished\nRemove completed transfers from the list.';

  @override
  String get helpStatusStripAnsi =>
      'Strip escapes\nWhen on, recordings, copies and saves keep only plain text without colors and control codes.';

  @override
  String get helpStatusCopyBuffer =>
      'Copy terminal contents\nCopy everything in the terminal buffer to the clipboard.';

  @override
  String get helpStatusSaveBuffer =>
      'Save terminal contents\nSave everything in the terminal buffer to a file.';

  @override
  String get helpStatusRecord =>
      'Start / stop recording\nRecord the terminal output to a file. Available while connected.';

  @override
  String get helpStatusRevealLog =>
      'Show log file\nOpen the folder containing the recording in your file manager.';

  @override
  String get helpSenderNew =>
      'New\nClear the box and detach it from the file. Asks first if there are changes.';

  @override
  String get helpSenderOpen => 'Open\nLoad a UTF-8 text file into the box.';

  @override
  String get helpSenderSave =>
      'Save\nSave the box to the linked file. Asks for a name if there is none.';

  @override
  String get helpSenderSaveAs =>
      'Save as\nSave the box contents to a different file.';

  @override
  String get helpSenderLineEnding =>
      'Line ending\nChoose the character appended after each line sent (CR, LF, CRLF or none). Usually CR for SSH.';

  @override
  String get helpSenderSend =>
      'Send\nSend the line at the cursor to the terminal and move to the next. Requires a connection.';

  @override
  String get newTabSerial => 'Serial port';

  @override
  String get serialTitle => 'Serial connection';

  @override
  String get serialPort => 'Port';

  @override
  String get serialPortHint => 'Select a port';

  @override
  String get serialPortRefresh => 'Refresh port list';

  @override
  String get serialNoPorts =>
      'No serial ports found. Plug in a USB device and it will appear automatically.';

  @override
  String get serialBaud => 'Baud rate';

  @override
  String get serialBaudInvalid => 'Enter a number of 1 or more';

  @override
  String get serialDataBits => 'Data bits';

  @override
  String get serialParity => 'Parity';

  @override
  String get serialStopBits => 'Stop bits';

  @override
  String get serialFlow => 'Flow control';

  @override
  String get serialParityNone => 'None (N)';

  @override
  String get serialParityOdd => 'Odd (O)';

  @override
  String get serialParityEven => 'Even (E)';

  @override
  String get serialParityMark => 'Mark (M)';

  @override
  String get serialParitySpace => 'Space (S)';

  @override
  String get serialFlowNone => 'None';

  @override
  String get serialFlowRtsCts => 'RTS/CTS (hardware)';

  @override
  String get serialFlowXonXoff => 'XON/XOFF (software)';

  @override
  String get serialFlowDtrDsr => 'DTR/DSR (hardware)';

  @override
  String serialErrorOpen(String detail) {
    return 'Could not open the port: $detail';
  }

  @override
  String serialErrorIo(String detail) {
    return 'Port read/write error: $detail';
  }

  @override
  String get serialErrorNotOpen => 'No port is open.';

  @override
  String get serialErrorDisconnected => 'The device was disconnected.';

  @override
  String get serialViewTerminal => 'Terminal view';

  @override
  String get serialViewHex => 'Hex view';

  @override
  String get serialEcho => 'Local echo';

  @override
  String get serialEchoTooltip =>
      'Also show what you send from the line sender on the terminal screen. Turn on when the device does not echo input back.';

  @override
  String serialBytes(int count) {
    return '$count bytes received';
  }

  @override
  String get serialHexEmpty => 'No data received yet.';

  @override
  String get helpSerialBar =>
      'Serial toolbar\nSwitch between the terminal view and the hex view, and turn local echo on or off. The hex view shows the bytes actually received, not the terminal screen.';

  @override
  String get tabNewSsh => 'New SSH connection';

  @override
  String get tabNewSerial => 'New serial connection';
}
