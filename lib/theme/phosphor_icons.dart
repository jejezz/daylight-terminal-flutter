// Phosphor Icons (https://phosphoricons.com), duotone 스타일. MIT 라이선스 — assets/licenses/phosphor-icons.txt.
//
// phosphor_flutter 패키지(2.1.0)는 이 Flutter에서 컴파일되지 않는다(`IconData`가 final class라 상속할 수 없다).
// 그래서 패키지는 쓰지 않고, 같은 글꼴(assets/fonts/phosphor_duotone.ttf)과 코드 포인트를 직접 쓴다.
// 듀오톤 아이콘은 글꼴 안에 두 겹(주 글리프 + 흐린 보조 글리프)으로 들어 있어, 위젯이 보조를 20% 불투명도로 깔고
// 주를 위에 그린다. 색은 둘 다 같은 색(IconTheme/color)이라 밝은/어두운 테마 모두 배경과 어울린다.
//
// 이 파일은 tool/gen_phosphor_icons.py 없이 손으로 늘려도 된다: 이름과 (주, 보조) 코드 포인트를 [PhosphorIconsDuotone]과
// [_secondary]에 같이 넣는다 (코드 포인트는 phosphor_flutter 2.1.0의 phosphor_icons_duotone.dart에 있다).

import 'package:flutter/widgets.dart';

const _family = 'PhosphorDuotone';

/// 쓰는 아이콘들 (이름은 Phosphor 이름 그대로).
abstract final class PhosphorIconsDuotone {
  static const arrowSquareOut = IconData(0xe5df, fontFamily: _family, matchTextDirection: true);
  static const arrowUp = IconData(0xe08f, fontFamily: _family, matchTextDirection: true);
  static const arrowsClockwise = IconData(0xe095, fontFamily: _family, matchTextDirection: true);
  static const arrowsLeftRight = IconData(0xe0a1, fontFamily: _family, matchTextDirection: true);
  static const bookOpen = IconData(0xe0e7, fontFamily: _family, matchTextDirection: true);
  static const caretDown = IconData(0xe137, fontFamily: _family, matchTextDirection: true);
  static const circleHalf = IconData(0xe18d, fontFamily: _family, matchTextDirection: true);
  static const copy = IconData(0xe1cb, fontFamily: _family, matchTextDirection: true);
  static const downloadSimple = IconData(0xe20d, fontFamily: _family, matchTextDirection: true);
  static const file = IconData(0xe231, fontFamily: _family, matchTextDirection: true);
  static const fileArrowDown = IconData(0xe233, fontFamily: _family, matchTextDirection: true);
  static const filePlus = IconData(0xe237, fontFamily: _family, matchTextDirection: true);
  static const fileText = IconData(0xe23b, fontFamily: _family, matchTextDirection: true);
  static const floppyDisk = IconData(0xe249, fontFamily: _family, matchTextDirection: true);
  static const floppyDiskBack = IconData(0xeaf5, fontFamily: _family, matchTextDirection: true);
  static const folder = IconData(0xe24b, fontFamily: _family, matchTextDirection: true);
  static const folderOpen = IconData(0xe257, fontFamily: _family, matchTextDirection: true);
  static const folderPlus = IconData(0xe259, fontFamily: _family, matchTextDirection: true);
  static const gauge = IconData(0xe629, fontFamily: _family, matchTextDirection: true);
  static const gear = IconData(0xe271, fontFamily: _family, matchTextDirection: true);
  static const hardDrives = IconData(0xe2a1, fontFamily: _family, matchTextDirection: true);
  static const house = IconData(0xe2c3, fontFamily: _family, matchTextDirection: true);
  static const info = IconData(0xe2cf, fontFamily: _family, matchTextDirection: true);
  static const keyReturn = IconData(0xe783, fontFamily: _family, matchTextDirection: true);
  static const linkBreak = IconData(0xe2e5, fontFamily: _family, matchTextDirection: true);
  static const magnifyingGlass = IconData(0xe30d, fontFamily: _family, matchTextDirection: true);
  static const moon = IconData(0xe331, fontFamily: _family, matchTextDirection: true);
  static const notePencil = IconData(0xe34d, fontFamily: _family, matchTextDirection: true);
  static const paperPlaneTilt = IconData(0xe399, fontFamily: _family, matchTextDirection: true);
  static const pencilSimple = IconData(0xe3b5, fontFamily: _family, matchTextDirection: true);
  static const play = IconData(0xe3d1, fontFamily: _family, matchTextDirection: true);
  static const plus = IconData(0xe3d5, fontFamily: _family, matchTextDirection: true);
  static const power = IconData(0xe3db, fontFamily: _family, matchTextDirection: true);
  static const question = IconData(0xe3eb, fontFamily: _family, matchTextDirection: true);
  static const record = IconData(0xe3f3, fontFamily: _family, matchTextDirection: true);
  static const shield = IconData(0xe40d, fontFamily: _family, matchTextDirection: true);
  static const shieldCheck = IconData(0xe40f, fontFamily: _family, matchTextDirection: true);
  static const squaresFour = IconData(0xe465, fontFamily: _family, matchTextDirection: true);
  static const stopCircle = IconData(0xe46f, fontFamily: _family, matchTextDirection: true);
  static const sun = IconData(0xe473, fontFamily: _family, matchTextDirection: true);
  static const terminalWindow = IconData(0xeae9, fontFamily: _family, matchTextDirection: true);
  static const translate = IconData(0xe4a3, fontFamily: _family, matchTextDirection: true);
  static const trash = IconData(0xe4a7, fontFamily: _family, matchTextDirection: true);
  static const uploadSimple = IconData(0xe4c1, fontFamily: _family, matchTextDirection: true);
  static const usb = IconData(0xe957, fontFamily: _family, matchTextDirection: true);
  static const warning = IconData(0xe4e1, fontFamily: _family, matchTextDirection: true);
  static const warningCircle = IconData(0xe4e3, fontFamily: _family, matchTextDirection: true);
  static const x = IconData(0xe4f7, fontFamily: _family, matchTextDirection: true);
}

/// 주 글리프 코드 포인트 → 보조(흐린 겹) 글리프. 아이콘 글꼴 줄이기(tree shaking)가 알아보도록 모두 const다.
const _secondary = <int, IconData>{
  0xe5df: IconData(0xe5de, fontFamily: _family, matchTextDirection: true), // arrowSquareOut
  0xe08f: IconData(0xe08e, fontFamily: _family, matchTextDirection: true), // arrowUp
  0xe095: IconData(0xe094, fontFamily: _family, matchTextDirection: true), // arrowsClockwise
  0xe0a1: IconData(0xe0a0, fontFamily: _family, matchTextDirection: true), // arrowsLeftRight
  0xe0e7: IconData(0xe0e6, fontFamily: _family, matchTextDirection: true), // bookOpen
  0xe137: IconData(0xe136, fontFamily: _family, matchTextDirection: true), // caretDown
  0xe18d: IconData(0xe18c, fontFamily: _family, matchTextDirection: true), // circleHalf
  0xe1cb: IconData(0xe1ca, fontFamily: _family, matchTextDirection: true), // copy
  0xe20d: IconData(0xe20c, fontFamily: _family, matchTextDirection: true), // downloadSimple
  0xe231: IconData(0xe230, fontFamily: _family, matchTextDirection: true), // file
  0xe233: IconData(0xe232, fontFamily: _family, matchTextDirection: true), // fileArrowDown
  0xe237: IconData(0xe236, fontFamily: _family, matchTextDirection: true), // filePlus
  0xe23b: IconData(0xe23a, fontFamily: _family, matchTextDirection: true), // fileText
  0xe249: IconData(0xe248, fontFamily: _family, matchTextDirection: true), // floppyDisk
  0xeaf5: IconData(0xeaf4, fontFamily: _family, matchTextDirection: true), // floppyDiskBack
  0xe24b: IconData(0xe24a, fontFamily: _family, matchTextDirection: true), // folder
  0xe257: IconData(0xe256, fontFamily: _family, matchTextDirection: true), // folderOpen
  0xe259: IconData(0xe258, fontFamily: _family, matchTextDirection: true), // folderPlus
  0xe629: IconData(0xe628, fontFamily: _family, matchTextDirection: true), // gauge
  0xe271: IconData(0xe270, fontFamily: _family, matchTextDirection: true), // gear
  0xe2a1: IconData(0xe2a0, fontFamily: _family, matchTextDirection: true), // hardDrives
  0xe2c3: IconData(0xe2c2, fontFamily: _family, matchTextDirection: true), // house
  0xe2cf: IconData(0xe2ce, fontFamily: _family, matchTextDirection: true), // info
  0xe783: IconData(0xe782, fontFamily: _family, matchTextDirection: true), // keyReturn
  0xe2e5: IconData(0xe2e4, fontFamily: _family, matchTextDirection: true), // linkBreak
  0xe30d: IconData(0xe30c, fontFamily: _family, matchTextDirection: true), // magnifyingGlass
  0xe331: IconData(0xe330, fontFamily: _family, matchTextDirection: true), // moon
  0xe34d: IconData(0xe34c, fontFamily: _family, matchTextDirection: true), // notePencil
  0xe399: IconData(0xe398, fontFamily: _family, matchTextDirection: true), // paperPlaneTilt
  0xe3b5: IconData(0xe3b4, fontFamily: _family, matchTextDirection: true), // pencilSimple
  0xe3d1: IconData(0xe3d0, fontFamily: _family, matchTextDirection: true), // play
  0xe3d5: IconData(0xe3d4, fontFamily: _family, matchTextDirection: true), // plus
  0xe3db: IconData(0xe3da, fontFamily: _family, matchTextDirection: true), // power
  0xe3eb: IconData(0xe3e8, fontFamily: _family, matchTextDirection: true), // question
  0xe3f3: IconData(0xe3ee, fontFamily: _family, matchTextDirection: true), // record
  0xe40d: IconData(0xe40a, fontFamily: _family, matchTextDirection: true), // shield
  0xe40f: IconData(0xe40c, fontFamily: _family, matchTextDirection: true), // shieldCheck
  0xe465: IconData(0xe464, fontFamily: _family, matchTextDirection: true), // squaresFour
  0xe46f: IconData(0xe46e, fontFamily: _family, matchTextDirection: true), // stopCircle
  0xe473: IconData(0xe472, fontFamily: _family, matchTextDirection: true), // sun
  0xeae9: IconData(0xeae8, fontFamily: _family, matchTextDirection: true), // terminalWindow
  0xe4a3: IconData(0xe4a2, fontFamily: _family, matchTextDirection: true), // translate
  0xe4a7: IconData(0xe4a6, fontFamily: _family, matchTextDirection: true), // trash
  0xe4c1: IconData(0xe4c0, fontFamily: _family, matchTextDirection: true), // uploadSimple
  0xe957: IconData(0xe956, fontFamily: _family, matchTextDirection: true), // usb
  0xe4e1: IconData(0xe4e0, fontFamily: _family, matchTextDirection: true), // warning
  0xe4e3: IconData(0xe4e2, fontFamily: _family, matchTextDirection: true), // warningCircle
  0xe4f7: IconData(0xe4f6, fontFamily: _family, matchTextDirection: true), // x
};

/// 듀오톤 아이콘도 그리는 [Icon]. 듀오톤이 아닌 아이콘(Material 등)은 [Icon]과 똑같이 그린다.
class PhosphorIcon extends Icon {
  const PhosphorIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
    super.textDirection,
    this.secondaryOpacity = 0.20,
  });

  /// 보조(흐린 겹)의 불투명도.
  final double secondaryOpacity;

  @override
  Widget build(BuildContext context) {
    final data = icon;
    final secondary = data != null && data.fontFamily == _family ? _secondary[data.codePoint] : null;
    if (secondary == null) return super.build(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: secondaryOpacity,
          child: Icon(secondary, size: size, color: color, textDirection: textDirection),
        ),
        super.build(context),
      ],
    );
  }
}
