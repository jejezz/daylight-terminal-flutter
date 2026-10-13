import 'dart:convert';

import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/address_book_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _saved = [
  {'id': '1', 'host': 'a.example', 'port': 22, 'username': 'root', 'name': 'Web', 'group': 'Prod', 'note': 'nginx'},
  {'id': '2', 'host': 'b.example', 'port': 2200, 'username': 'ubuntu', 'group': 'Prod'},
  {'id': '3', 'host': 'c.example', 'port': 22, 'username': 'me', 'name': 'Home NAS'},
];

Future<(SessionsController, ProfileStore)> _pump(WidgetTester tester, {Object? profiles = _saved}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({if (profiles != null) 'ssh_profiles': jsonEncode(profiles)});
  final store = await ProfileStore.load();
  final sessions = SessionsController(store);
  await tester.pumpWidget(
    ChangeNotifierProvider<SessionsController>.value(
      value: sessions,
      child: MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showAddressBook(context), child: const Text('open')),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (sessions, store);
}

void main() {
  testWidgets('lists connections grouped, ungrouped last, with names or user@host', (tester) async {
    await _pump(tester);
    expect(find.text('주소록'), findsOneWidget);
    expect(find.text('Prod'), findsOneWidget);
    expect(find.text('그룹 없음'), findsOneWidget);
    expect(find.text('Web'), findsOneWidget); // 이름이 있으면 이름
    expect(find.text('ubuntu@b.example:2200'), findsWidgets); // 이름이 없으면 user@host(:port)
    expect(find.textContaining('nginx'), findsOneWidget);
    // Prod 그룹이 '그룹 없음'보다 먼저 나온다.
    expect(tester.getTopLeft(find.text('Prod')).dy, lessThan(tester.getTopLeft(find.text('그룹 없음')).dy));
  });

  testWidgets('search filters by name, host, group and note', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'nas');
    await tester.pump();
    expect(find.text('Home NAS'), findsOneWidget);
    expect(find.text('Web'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'prod');
    await tester.pump();
    expect(find.text('Web'), findsOneWidget);
    expect(find.text('Home NAS'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump();
    expect(find.text('검색 결과가 없습니다'), findsOneWidget);
  });

  testWidgets('add a new connection and it is persisted without any secret', (tester) async {
    final (_, store) = await _pump(tester, profiles: null);
    expect(find.textContaining('저장된 접속이 없습니다'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '새 접속'));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'My Server'); // 이름
    await tester.enterText(fields.at(1), 'Lab'); // 그룹
    await tester.enterText(fields.at(2), '10.0.0.5'); // 호스트
    await tester.enterText(fields.at(4), 'dev'); // 사용자
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('My Server'), findsOneWidget);
    final p = store.profiles().single;
    expect((p.name, p.group, p.host, p.port, p.username), ('My Server', 'Lab', '10.0.0.5', 22, 'dev'));
    expect(p.toJson().keys, isNot(contains('password')));
  });

  testWidgets('save is disabled until host and user are filled', (tester) async {
    await _pump(tester, profiles: null);
    await tester.tap(find.widgetWithText(FilledButton, '새 접속'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장')).onPressed, isNull);
  });

  testWidgets('edit keeps the id and delete asks first', (tester) async {
    final (_, store) = await _pump(tester);
    await tester.tap(find.byTooltip('편집').first);
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Renamed');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(store.profiles(), hasLength(3));
    expect(store.profiles().map((p) => p.name), contains('Renamed'));

    await tester.tap(find.byTooltip('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소')); // 취소하면 남는다
    await tester.pumpAndSettle();
    expect(store.profiles(), hasLength(3));

    await tester.tap(find.byTooltip('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(store.profiles(), hasLength(2));
  });

  testWidgets('connecting asks for the password and cancel changes nothing', (tester) async {
    final (sessions, _) = await _pump(tester);
    await tester.tap(find.byTooltip('연결').first);
    await tester.pumpAndSettle();
    expect(find.text('비밀번호는 저장되지 않습니다'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(sessions.sessions, hasLength(1));
    expect(find.text('주소록'), findsOneWidget); // 주소록은 열려 있다
  });
}
