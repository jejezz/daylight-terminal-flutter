import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 도움말 모드에서 설명이 나오는 컨트롤 목록.
enum HelpId {
  helpButton,
  disconnect,
  addressBook,
  settings,
  theme,
  language,
  about,
  tabs,
  explorerSftp,
  explorerLocal,
  terminal,
  sender,
  statusBar,
  tabItem,
  tabNew,
  tabClose,
  paneUp,
  panePath,
  paneRefresh,
  paneNewFolder,
  panePathSync,
  panePlaces,
  fileRow,
  transferClear,
  statusStripAnsi,
  statusCopyBuffer,
  statusSaveBuffer,
  statusRecord,
  statusRevealLog,
  senderNew,
  senderOpen,
  senderSave,
  senderSaveAs,
  senderLineEnding,
  senderSend,
  emptyAction,
  serialBar,
}

/// 도움말 글: 첫 줄은 이름, 나머지는 설명 (arb의 한 문자열에 `\n`으로 나눠 둔다).
({String title, String body}) helpText(AppLocalizations l, HelpId id) {
  final raw = switch (id) {
    HelpId.helpButton => l.helpButton,
    HelpId.disconnect => l.helpDisconnect,
    HelpId.addressBook => l.helpAddressBook,
    HelpId.settings => l.helpSettings,
    HelpId.theme => l.helpTheme,
    HelpId.language => l.helpLanguage,
    HelpId.about => l.helpAbout,
    HelpId.tabs => l.helpTabs,
    HelpId.explorerSftp => l.helpExplorerSftp,
    HelpId.explorerLocal => l.helpExplorerLocal,
    HelpId.terminal => l.helpTerminal,
    HelpId.sender => l.helpSender,
    HelpId.statusBar => l.helpStatusBar,
    HelpId.tabItem => l.helpTabItem,
    HelpId.tabNew => l.helpTabNew,
    HelpId.tabClose => l.helpTabClose,
    HelpId.paneUp => l.helpPaneUp,
    HelpId.panePath => l.helpPanePath,
    HelpId.paneRefresh => l.helpPaneRefresh,
    HelpId.paneNewFolder => l.helpPaneNewFolder,
    HelpId.panePathSync => l.helpPanePathSync,
    HelpId.panePlaces => l.helpPanePlaces,
    HelpId.fileRow => l.helpFileRow,
    HelpId.transferClear => l.helpTransferClear,
    HelpId.statusStripAnsi => l.helpStatusStripAnsi,
    HelpId.statusCopyBuffer => l.helpStatusCopyBuffer,
    HelpId.statusSaveBuffer => l.helpStatusSaveBuffer,
    HelpId.statusRecord => l.helpStatusRecord,
    HelpId.statusRevealLog => l.helpStatusRevealLog,
    HelpId.senderNew => l.helpSenderNew,
    HelpId.senderOpen => l.helpSenderOpen,
    HelpId.senderSave => l.helpSenderSave,
    HelpId.senderSaveAs => l.helpSenderSaveAs,
    HelpId.senderLineEnding => l.helpSenderLineEnding,
    HelpId.senderSend => l.helpSenderSend,
    HelpId.emptyAction => l.helpEmptyAction,
    HelpId.serialBar => l.helpSerialBar,
  };
  final i = raw.indexOf('\n');
  return i < 0 ? (title: raw, body: '') : (title: raw.substring(0, i), body: raw.substring(i + 1));
}

/// 도움말 모드의 켜짐 여부와, 화면에 있는 [HelpTarget] 목록을 들고 있다.
class HelpModeController extends ChangeNotifier {
  bool _active = false;
  final Set<_HelpTargetState> _targets = {};

  bool get active => _active;

  void start() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void stop() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }

  /// 화면 좌표 [global]을 덮는 컨트롤 중 가장 작은(안쪽) 것. 가려진 탭의 컨트롤은 뺀다.
  ({HelpId id, Rect rect})? targetAt(Offset global) {
    ({HelpId id, Rect rect})? best;
    for (final t in _targets) {
      final rect = t._visibleRect();
      if (rect == null || !rect.contains(global)) continue;
      if (best == null || rect.width * rect.height < best.rect.width * best.rect.height) {
        best = (id: t.widget.id, rect: rect);
      }
    }
    return best;
  }
}

class _HelpScope extends InheritedWidget {
  const _HelpScope({required this.controller, required super.child});

  final HelpModeController controller;

  @override
  bool updateShouldNotify(_HelpScope old) => controller != old.controller;
}

/// 도움말 모드를 쓸 수 있는 범위. [HelpModeScope.maybeOf]는 범위 밖(테스트 등)이면 null이다.
class HelpModeScope extends StatelessWidget {
  const HelpModeScope({super.key, required this.controller, required this.child});

  final HelpModeController controller;
  final Widget child;

  static HelpModeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HelpScope>()?.controller;

  @override
  Widget build(BuildContext context) => _HelpScope(controller: controller, child: child);
}

/// 자식에 도움말을 붙인다. 도움말 모드에서 마우스가 이 영역에 있으면 박스가 그려지고 [id]의 설명이 나온다.
class HelpTarget extends StatefulWidget {
  const HelpTarget({super.key, required this.id, required this.child});

  final HelpId id;
  final Widget child;

  @override
  State<HelpTarget> createState() => _HelpTargetState();
}

class _HelpTargetState extends State<HelpTarget> {
  HelpModeController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = HelpModeScope.maybeOf(context);
    _controller?._targets.add(this);
  }

  @override
  void dispose() {
    _controller?._targets.remove(this);
    super.dispose();
  }

  Rect? _visibleRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    var hidden = false;
    // IndexedStack이 가린 탭은 크기와 위치를 갖고 있어도 보이지 않는다.
    context.visitAncestorElements((e) {
      final ro = e.renderObject;
      if (ro is RenderOffstage && ro.offstage) {
        hidden = true;
        return false;
      }
      return true;
    });
    if (hidden) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

extension HelpTargetX on Widget {
  /// `child.help(HelpId.x)` = `HelpTarget(id: HelpId.x, child: child)`.
  Widget help(HelpId id) => HelpTarget(id: id, child: this);
}

/// 도움말 모드 `?` 버튼: `?` 버튼. 다이얼로그 등이 위에 떠 있으면 누를 수 없다.
class HelpModeButton extends StatelessWidget {
  const HelpModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = HelpModeScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    return HelpTarget(
      id: HelpId.helpButton,
      child: IconButton(
        tooltip: l10n.helpModeTooltip,
        icon: const Icon(Icons.help_outline_rounded),
        onPressed: controller == null || !onTop ? null : controller.start,
      ),
    );
  }
}

/// 도움말 모드일 때 화면 전체를 덮는 막. 살짝 어둡게 하고, 마우스가 올라간 컨트롤에 박스와 설명을 보여 준다.
/// 아무 곳이나 누르면(또는 Esc) 끝나고, 그 누름은 아래로 전달하지 않는다. 키 입력도 아래(터미널)로 가지 않는다.
class HelpModeOverlay extends StatefulWidget {
  const HelpModeOverlay({super.key, required this.controller});

  final HelpModeController controller;

  @override
  State<HelpModeOverlay> createState() => _HelpModeOverlayState();
}

class _HelpModeOverlayState extends State<HelpModeOverlay> {
  final _focus = FocusNode(debugLabel: 'HelpModeOverlay');
  FocusNode? _previousFocus;
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    final previous = _previousFocus;
    _focus.dispose();
    if (previous != null && previous.context != null) previous.requestFocus();
    super.dispose();
  }

  void _setPointer(Offset global) => setState(() => _pointer = global);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final box = context.findRenderObject() as RenderBox?;
    final hit = _pointer == null ? null : widget.controller.targetAt(_pointer!);
    // 전역 좌표를 이 막 안의 좌표로 바꾼다.
    final local = hit != null && box != null && box.hasSize
        ? (box.globalToLocal(hit.rect.topLeft) & hit.rect.size)
        : null;

    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) widget.controller.stop();
        return KeyEventResult.handled;
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.controller.stop(),
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          onHover: (e) => _setPointer(e.position),
          onExit: (_) => setState(() => _pointer = null),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DimPainter(hole: local?.inflate(2), color: Colors.black.withValues(alpha: 0.22)),
                    ),
                  ),
                  if (local != null && hit != null) ...[
                    Positioned.fromRect(
                      rect: local.inflate(2),
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    _Bubble(target: local, area: size, text: helpText(l10n, hit.id)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(4))),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole || old.color != color;
}

/// 박스 아래(자리가 없으면 위)에 놓이는 설명 말풍선.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.target, required this.area, required this.text});

  final Rect target;
  final Size area;
  final ({String title, String body}) text;

  static const _width = 280.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = target.left.clamp(
      AppSpacing.sm,
      (area.width - _width - AppSpacing.sm).clamp(AppSpacing.sm, double.infinity),
    );
    final below = target.bottom + _gap + 110 <= area.height;
    final card = Material(
      color: scheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.title,
              style: theme.textTheme.titleSmall?.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.bold),
            ),
            if (text.body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(text.body, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface)),
            ],
          ],
        ),
      ),
    );
    return Positioned(
      left: left.toDouble(),
      top: below ? target.bottom + _gap : null,
      bottom: below ? null : area.height - target.top + _gap,
      width: _width,
      child: IgnorePointer(child: card),
    );
  }
}
