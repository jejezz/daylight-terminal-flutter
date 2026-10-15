import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/widgets/tab_bar_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SessionsController> make() async {
    SharedPreferences.setMockInitialValues({});
    return SessionsController(await ProfileStore.load());
  }

  test('move: 순서가 바뀌고 선택된 탭이 유지된다', () async {
    final c = await make();
    c.add();
    c.add();
    final s = [...c.sessions];
    c.select(1);
    c.move(0, 2);
    expect(c.sessions, [s[1], s[2], s[0]]);
    expect(c.current, s[1]);
    c.move(2, 0);
    expect(c.sessions, [s[0], s[1], s[2]]);
    expect(c.current, s[1]);
    c.move(1, 1);
    c.move(5, 0);
    expect(c.sessions, [s[0], s[1], s[2]]);
    c.dispose();
  });

  testWidgets('탭을 끌어 놓으면 순서가 바뀐다', (tester) async {
    final c = await make();
    c.add();
    final first = c.sessions[0];
    final second = c.sessions[1];
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionsController>.value(
        value: c,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TabBarRow()),
        ),
      ),
    );
    final tabs = find.byType(Draggable<int>);
    expect(tabs, findsNWidgets(2));
    final gesture = await tester.startGesture(tester.getCenter(tabs.at(0)));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveTo(tester.getCenter(tabs.at(1)));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(c.sessions, [second, first]);
    expect(c.current, second);
    c.dispose();
  });
}
