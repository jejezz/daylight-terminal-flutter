import 'dart:io';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/models/serial_settings.dart';
import 'package:daylight_terminal/screens/home_screen.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/settings/app_settings.dart';
import 'package:daylight_terminal/settings/terminal_prefs.dart';
import 'package:daylight_terminal/state/serial_session.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/hex_view.dart';
import 'package:daylight_terminal/widgets/line_sender.dart';
import 'package:daylight_terminal/widgets/local_folder_pane.dart';
import 'package:daylight_terminal/widgets/serial_connect_panel.dart';
import 'package:daylight_terminal/widgets/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_serial.dart';

void main() {
  late FakeSerialService serial;

  setUp(() => serial = FakeSerialService());

  Future<SessionsController> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionsController(await ProfileStore.load(), serialFactory: () => serial);
    final settings = await AppSettings.load();
    final prefs = await TerminalPrefs.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
          ChangeNotifierProvider<TerminalPrefs>.value(value: prefs),
        ],
        child: AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            home: HomeScreen(onAbout: () {}),
          ),
        ),
      ),
    );
    return sessions;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the + menu opens a serial tab that shows the port form first', (tester) async {
    final sessions = await pumpApp(tester);
    await tester.tap(find.byTooltip('새 연결'));
    await settle(tester);
    await tester.tap(find.ancestor(of: find.text('시리얼 포트'), matching: find.byType(PopupMenuItem<Object>)));
    await settle(tester);

    expect(sessions.sessions, hasLength(2));
    expect(sessions.current, isA<SerialSession>());
    expect(find.byType(SerialConnectPanel), findsOneWidget);
    expect(find.byType(TerminalPane), findsNothing);
    expect(find.byIcon(Icons.usb_rounded), findsWidgets); // 탭 아이콘
  });

  testWidgets('the connect form on an empty SSH tab can turn it into a serial tab', (tester) async {
    final sessions = await pumpApp(tester);
    await tester.ensureVisible(find.text('시리얼 연결'));
    await tester.tap(find.text('시리얼 연결'));
    await settle(tester);
    expect(sessions.sessions, hasLength(1)); // 빈 탭을 그 자리에서 바꾼다
    expect(sessions.current, isA<SerialSession>());
  });

  testWidgets('the form connects with the chosen port and line settings', (tester) async {
    final session = SerialSession(service: serial);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SerialSession>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Scaffold(body: SerialConnectPanel(portLister: () => ['COM3', 'COM4'])),
        ),
      ),
    );

    // 포트를 고르기 전에는 연결할 수 없다.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COM4').last);
    await tester.pumpAndSettle();
    session
      ..setPendingParity(SerialParity.odd)
      ..setPendingStopBits(2);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '9600');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(session.connected, isTrue);
    final used = serial.openedWith!;
    expect((used.portName, used.baudRate, used.parity, used.stopBits), ('COM4', 9600, SerialParity.odd, 2));
  });

  testWidgets('a connected serial tab shows folder view, terminal, bar, sender and can switch to hex', (tester) async {
    // 진짜 파일 입출력은 가짜 시계 밖(runAsync)에서 해야 끝난다.
    final tmp = (await tester.runAsync(() => Directory.systemTemp.createTemp('dt_serial_ui_')))!;
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}${Platform.pathSeparator}log.txt').writeAsStringSync('x');

    final sessions = await pumpApp(tester);
    final session = sessions.addSerial();
    await tester.runAsync(() => session.loadFolder(tmp.path));
    session.connect(const SerialSettings(portName: 'COM3'));
    await settle(tester);

    expect(find.byType(LocalFolderPane), findsOneWidget);
    expect(find.byType(TerminalPane), findsOneWidget);
    expect(find.byType(LineSender), findsOneWidget);
    expect(find.text('log.txt'), findsOneWidget);
    // 셸이 없으니 "터미널을 이 폴더로 이동" 메뉴는 없다.
    expect(find.byIcon(Icons.sync_alt_rounded), findsNothing);

    serial.emitBytes([0x41, 0x42]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await settle(tester);
    expect(find.text('수신 4 바이트'), findsNothing); // 깨우는 Enter는 보낸 것이지 받은 것이 아니다
    expect(find.text('수신 2 바이트'), findsOneWidget);

    await tester.tap(find.byTooltip('Hex 보기'));
    await settle(tester);
    expect(find.byType(HexView), findsOneWidget);
    expect(find.textContaining('41 42'), findsOneWidget);
    expect(session.status, SessionStatus.connected);
  });
}
