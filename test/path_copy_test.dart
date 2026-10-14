import 'package:daylight_terminal/l10n/app_localizations.dart';
import 'package:daylight_terminal/theme/app_theme.dart';
import 'package:daylight_terminal/widgets/file_pane_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clicking the address bar copies the full path and says so', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          body: PaneHeader(
            path: '/home/tester/sub',
            canGoUp: true,
            onUp: () {},
            onRefresh: () {},
            onNewFolder: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('/home/tester/sub'));
    await tester.pump();
    expect(clip, '/home/tester/sub');
    expect(find.text('경로를 클립보드에 복사했습니다: /home/tester/sub'), findsOneWidget);
  });
}
