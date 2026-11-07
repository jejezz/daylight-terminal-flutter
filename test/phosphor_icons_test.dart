import 'dart:io';

import 'package:daylight_terminal/theme/phosphor_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a duotone icon draws two layers in the same color; the back one is faint', (tester) async {
    await tester.pumpWidget(host(const PhosphorIcon(PhosphorIconsDuotone.folder, size: 20, color: Colors.teal)));
    final icons = tester.widgetList<Icon>(find.descendant(of: find.byType(PhosphorIcon), matching: find.byType(Icon)));
    expect(icons.length, 1, reason: '뒤 겹(보조)');
    final back = icons.single;
    expect(back.icon, isNot(PhosphorIconsDuotone.folder));
    expect(back.icon!.fontFamily, 'PhosphorDuotone');
    expect(back.color, Colors.teal);
    expect(tester.widget<Opacity>(find.descendant(of: find.byType(PhosphorIcon), matching: find.byType(Opacity))).opacity, 0.2);
    expect(tester.getSize(find.byType(PhosphorIcon)), const Size(20, 20));
  });

  testWidgets('the color follows the theme (IconTheme) in light and dark', (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(host(const IconTheme(
        data: IconThemeData(color: Colors.orange, size: 18),
        child: PhosphorIcon(PhosphorIconsDuotone.gear),
      ), brightness: b));
      final back = tester.widget<Icon>(find.descendant(of: find.byType(PhosphorIcon), matching: find.byType(Icon)));
      expect(back.color, isNull, reason: '색을 안 주면 IconTheme을 따른다 ($b)');
      expect(tester.getSize(find.byType(PhosphorIcon)), const Size(18, 18));
    }
  });

  testWidgets('a non-duotone icon is drawn like a plain Icon (one layer)', (tester) async {
    await tester.pumpWidget(host(const PhosphorIcon(Icons.circle, size: 8)));
    expect(find.descendant(of: find.byType(PhosphorIcon), matching: find.byType(Opacity)), findsNothing);
  });

  test('every icon constant has a back-layer glyph registered (else it would draw as a single layer)', () {
    final src = File('lib/theme/phosphor_icons.dart').readAsStringSync();
    final names = RegExp(r'static const (\w+) = IconData\(0x([0-9a-f]+)').allMatches(src).toList();
    final back = RegExp(r'^  0x([0-9a-f]+): IconData\(', multiLine: true).allMatches(src).map((m) => m.group(1)).toSet();
    expect(names, isNotEmpty);
    for (final m in names) {
      expect(back, contains(m.group(2)), reason: '${m.group(1)} has no back layer');
    }
  });
}
