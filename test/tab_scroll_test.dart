import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/widgets/tab_bar_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SessionsController> pumpBar(WidgetTester tester, {required int tabs}) async {
    SharedPreferences.setMockInitialValues({});
    final c = SessionsController(await ProfileStore.load());
    for (var i = 1; i < tabs; i++) {
      c.add();
    }
    tester.view.physicalSize = const Size(600, 200); // 탭 10개(최소 120씩)가 들어가지 않는 폭
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pumpAndSettle();
    return c;
  }

  double scrollOffset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  testWidgets('the mouse wheel scrolls the tab bar sideways', (tester) async {
    final c = await pumpBar(tester, tabs: 10);
    c.select(0);
    await tester.pumpAndSettle();
    expect(scrollOffset(tester), 0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byType(TabBarRow))));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pump();
    expect(scrollOffset(tester), 300);

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -9999)));
    await tester.pump();
    expect(scrollOffset(tester), 0); // 처음을 넘어가지 않는다
    c.dispose();
  });

  testWidgets('selecting a tab off the right edge scrolls it into view', (tester) async {
    final c = await pumpBar(tester, tabs: 10);
    c.select(0);
    await tester.pumpAndSettle();
    final last = find.byType(Draggable<int>).last;
    expect(tester.getRect(last).right, greaterThan(600)); // 처음에는 화면 밖

    c.select(9);
    await tester.pumpAndSettle();
    final rect = tester.getRect(last);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(600));
    c.dispose();
  });
}
