// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 새 앱의 시작점. 규약이 요구하는 연결을 한곳에 모았다:
//   창 크기(window_manager) · 추가 라이선스 · 설정 로드 · 라이트/다크 ·
//   언어 해석 · macOS 앱 메뉴 About · 앱 바 [테마 | 언어 | 정보] · 빈 상태.
// 기존 앱에는 통째로 덮어쓰지 말고 필요한 부분만 옮긴다.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'about/about_dialog.dart';
import 'about/app_menu_bar.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/diag_log.dart';
import 'services/profile_store.dart';
import 'settings/refresh_prefs.dart';
import 'settings/restore_prefs.dart';
import 'services/tab_store.dart';
import 'settings/terminal_prefs.dart';
import 'state/sessions_controller.dart';
import 'window/window_placement.dart';
import 'theme/app_theme.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';

final bool _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  if (_isDesktop) {
    // 가끔만 나타나는 문제(버튼이 안 눌림 등)를 나중에 가려내기 위한 기록 (services/diag_log.dart).
    final info = await PackageInfo.fromPlatform();
    await DiagLog.init(version: '${info.version}+${info.buildNumber}');
    DiagLog.watch();
  }

  WindowPlacement? placement;
  if (_isDesktop) {
    await windowManager.ensureInitialized();
    // ui-ux.md §5: 최소 크기는 960×600 이하 (1366×768 노트북).
    const defaultSize = Size(1200, 720);
    // Windows: 모니터마다 배율이 다르면 window_manager의 center가 창을 한쪽으로 쏠리게 해서, 마지막 위치를
    // 기억하고 물리 픽셀로 직접 배치한다 (window_placement.dart). 다른 OS는 기존대로 center.
    if (WindowPlacement.enabled) {
      placement = WindowPlacement(await SharedPreferences.getInstance(), defaultSize: defaultSize);
    }
    final options = WindowOptions(
      size: defaultSize,
      minimumSize: const Size(960, 600),
      center: placement == null,
      title: AppIdentity.displayName,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await placement?.placeInitially();
      placement?.attach();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final settings = await AppSettings.load();
  final terminalPrefs = await TerminalPrefs.load();
  final refreshPrefs = await RefreshPrefs.load();
  final restorePrefs = await RestorePrefs.load();
  final sessions = SessionsController(
    await ProfileStore.load(),
    scrollback: () => terminalPrefs.scrollback,
    refreshPrefs: refreshPrefs,
    tabStore: await TabStore.load(),
    restorePrefs: restorePrefs,
  );
  // 새 탭 메뉴에 보일 로컬 셸 목록 (Windows는 WSL 배포판을 묻느라 잠깐 걸린다). 셸 목록이 있어야 지난번 탭을 다시 열 수 있다.
  unawaited(sessions.loadShells().then((_) => sessions.restoreTabs()));
  DiagLog.log('startup ready');
  // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음.
  final updates = await UpdateService.create();
  // UpdateScope 는 MaterialApp 위에 둔다 — 정보 창이 이것을 읽어 "업데이트 확인" 단추를 붙인다.
  runApp(
    UpdateScope(
      service: updates,
      child: App(
        settings: settings,
        sessions: sessions,
        terminalPrefs: terminalPrefs,
        refreshPrefs: refreshPrefs,
        restorePrefs: restorePrefs,
        placement: placement,
        updates: updates,
      ),
    ),
  );
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.settings,
    required this.sessions,
    required this.terminalPrefs,
    required this.refreshPrefs,
    required this.restorePrefs,
    this.placement,
    this.updates,
  });

  final AppSettings settings;
  final SessionsController sessions;
  final TerminalPrefs terminalPrefs;
  final RefreshPrefs refreshPrefs;
  final RestorePrefs restorePrefs;
  final WindowPlacement? placement;
  final UpdateService? updates;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncWindowBrightness);
    _syncWindowBrightness();
    widget.updates?.startAutomaticCheck(_navigatorKey);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncWindowBrightness);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱 종료 요청(⌘Q, 업데이트 후 재시작 등) 때는 위젯 dispose가 보장되지 않으므로
  // 기록 중인 파일을 먼저 flush/close 한다.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await widget.placement?.saveNow();
    await widget.sessions.prepareForExit();
    return AppExitResponse.exit;
  }

  // 앱에서 다크를 골라도 OS가 라이트면 제목 표시줄은 밝게 남는다 (theming.md §4).
  @override
  void didChangePlatformBrightness() => _syncWindowBrightness();

  void _syncWindowBrightness() {
    if (!_isDesktop || Platform.isLinux) return;
    final brightness = switch (widget.settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    windowManager.setBrightness(brightness);
  }

  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final l10n = AppLocalizations.of(context);
    showAppAboutDialog(
      context,
      tagline: l10n.aboutTagline,
      description: l10n.aboutDescription,
      onCheckForUpdates: widget.updates == null ? null : () => widget.updates!.checkManually(context),
    );
  }

  void _checkForUpdates() {
    final context = _navigatorKey.currentContext;
    if (context != null) widget.updates?.checkManually(context);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionsController>.value(value: widget.sessions),
        ChangeNotifierProvider<TerminalPrefs>.value(value: widget.terminalPrefs),
        ChangeNotifierProvider<RefreshPrefs>.value(value: widget.refreshPrefs),
        ChangeNotifierProvider<RestorePrefs>.value(value: widget.restorePrefs),
      ],
      child: AppSettingsScope(
        settings: widget.settings,
        child: ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            title: AppIdentity.displayName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(dense: _isDesktop),
            darkTheme: AppTheme.dark(dense: _isDesktop),
            themeMode: widget.settings.themeMode,
            locale: widget.settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: AppSettings.resolveLocale,
            builder: (context, child) => AppMenuBar(
              onAbout: _showAbout,
              onCheckForUpdates: widget.updates == null ? null : _checkForUpdates,
              child: child!,
            ),
            home: HomeScreen(onAbout: _showAbout),
          ),
        ),
      ),
    );
  }
}
