import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_identity.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_menus.dart';
import '../state/sessions_controller.dart';
import '../state/local_shell_session.dart';
import '../state/ssh_session_provider.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import '../utils/app_shortcuts.dart';
import '../widgets/address_book_dialog.dart';
import '../widgets/connect_panel.dart';
import '../widgets/line_sender.dart';
import '../widgets/local_folder_pane.dart';
import '../widgets/sftp_pane.dart';
import '../widgets/status_bar.dart';
import '../widgets/tab_bar_row.dart';
import '../widgets/terminal_font_dialog.dart';
import '../widgets/terminal_pane.dart';
import '../window/focus_tint.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onAbout});

  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SessionsController>();
    final current = controller.current;

    // Ctrl+Shift+T/W/R/K — 셸 제어 문자와 겹치지 않게 Shift를 더했다 (app_shortcuts.dart).
    return CallbackShortcuts(
      bindings: {
        AppShortcut.newTab.activator: controller.add,
        AppShortcut.newLocalTab.activator: controller.addLocal,
        AppShortcut.closeTab.activator: controller.closeCurrent,
        AppShortcut.toggleLogging.activator: () {
          current?.toggleLogging(confirmButtonText: l10n.logSaveConfirm);
        },
        AppShortcut.clearTerminal.activator: () => current?.clearTerminal(),
        AppShortcut.addressBook.activator: () => showAddressBook(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: const FocusTint(),
            title: const Text(AppIdentity.displayName),
            actions: [
              if (current != null)
                ListenableBuilder(
                  listenable: current,
                  builder: (context, _) => current.connected
                      ? IconButton(
                          tooltip: current is LocalShellSession ? l10n.shellTerminate : l10n.connectDisconnect,
                          icon: Icon(
                            current is LocalShellSession ? Icons.power_settings_new_rounded : Icons.link_off_rounded,
                          ),
                          onPressed: current.disconnect,
                        )
                      : const SizedBox.shrink(),
                ),
              IconButton(
                tooltip: l10n.addressBookTooltip(AppShortcut.addressBook.label),
                icon: const Icon(Icons.menu_book_rounded),
                onPressed: () => showAddressBook(context),
              ),
              IconButton(
                tooltip: l10n.terminalFontTooltip,
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: () => showTerminalFontDialog(context),
              ),
              const ThemeMenuButton(),
              const LanguageMenuButton(),
              IconButton(tooltip: l10n.aboutTooltip, icon: const Icon(Icons.info_outline_rounded), onPressed: onAbout),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: current == null
              ? _EmptyState(onConnect: controller.add)
              : Column(
                  children: [
                    const TabBarRow(),
                    Expanded(
                      // 탭을 바꿔도 각 탭의 터미널·탐색기 상태가 유지되도록 모두 살려 둔다.
                      child: IndexedStack(
                        index: controller.selected,
                        children: [
                          for (final s in controller.sessions)
                            // 공통 위젯(터미널, LineSender, 상태 바)은 TerminalSession으로, 탭 종류별 위젯은
                            // 자기 타입으로 찾을 수 있게 둘 다 제공한다.
                            MultiProvider(
                              key: ObjectKey(s),
                              providers: [
                                ChangeNotifierProvider<TerminalSession>.value(value: s),
                                if (s is SshSessionProvider) ChangeNotifierProvider<SshSessionProvider>.value(value: s),
                                if (s is LocalShellSession) ChangeNotifierProvider<LocalShellSession>.value(value: s),
                              ],
                              child: _SessionView(session: s),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppIdentity.iconAsset, width: 48, height: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.homeEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onConnect, child: Text(l10n.homeEmptyAction)),
        ],
      ),
    );
  }
}

/// 한 탭의 내용: 연결 전에는 접속 폼, 연결 후에는 [탐색기 | 터미널 + LineSender] 분할 화면.
class _SessionView extends StatefulWidget {
  const _SessionView({required this.session});

  final TerminalSession session;

  @override
  State<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<_SessionView> {
  double _explorerWidth = 320;
  double _senderHeight = 120;

  static const _minExplorer = 220.0;
  static const _minTerminal = 360.0;
  static const _minSender = 64.0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TerminalSession>();
    // SSH 탭은 연결하기 전에 접속 폼을 보여 준다.
    if (!session.connected && widget.session is SshSessionProvider) return const ConnectPanel();

    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final maxExplorer = (box.maxWidth - _minTerminal).clamp(_minExplorer, 800.0);
              final explorer = _explorerWidth.clamp(_minExplorer, maxExplorer);
              final maxSender = (box.maxHeight - 120).clamp(_minSender, 600.0);
              final sender = _senderHeight.clamp(_minSender, maxSender);
              return Row(
                children: [
                  // 왼쪽: SSH 탭은 서버의 폴더(SFTP), 로컬 셸 탭은 이 PC의 폴더.
                  SizedBox(
                    width: explorer,
                    child: widget.session is LocalShellSession ? const LocalFolderPane() : const SftpPane(),
                  ),
                  _Divider(
                    axis: Axis.vertical,
                    color: scheme.outlineVariant,
                    onDrag: (d) => setState(() => _explorerWidth = (explorer + d).clamp(_minExplorer, maxExplorer)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.session case final LocalShellSession local) _ShellBanner(session: local),
                        const Expanded(child: TerminalPane()),
                        _Divider(
                          axis: Axis.horizontal,
                          color: scheme.outlineVariant,
                          onDrag: (d) => setState(() => _senderHeight = (sender - d).clamp(_minSender, maxSender)),
                        ),
                        SizedBox(height: sender, child: const LineSender()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const StatusBar(),
      ],
    );
  }
}

/// 드래그로 영역 크기를 조절하는 구분선.
class _Divider extends StatelessWidget {
  const _Divider({required this.axis, required this.color, required this.onDrag});

  final Axis axis;
  final Color color;
  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    return MouseRegion(
      cursor: vertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: vertical ? (d) => onDrag(d.delta.dx) : null,
        onVerticalDragUpdate: vertical ? null : (d) => onDrag(d.delta.dy),
        child: Container(
          width: vertical ? 6 : null,
          height: vertical ? null : 6,
          alignment: Alignment.center,
          child: Container(width: vertical ? 1 : null, height: vertical ? null : 1, color: color),
        ),
      ),
    );
  }
}

/// 로컬 셸이 끝났거나 띄우지 못했을 때 터미널 위에 보이는 안내 줄.
class _ShellBanner extends StatelessWidget {
  const _ShellBanner({required this.session});

  final LocalShellSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        final failed = session.startError != null;
        if (!failed && session.exitCode == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          color: failed ? scheme.error.withValues(alpha: 0.14) : scheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  failed ? l10n.shellStartFailed(session.startError!) : l10n.shellExited(session.exitCode!),
                  style: TextStyle(color: failed ? scheme.error : scheme.onSurface, fontSize: 12.5),
                ),
              ),
              TextButton(onPressed: session.restart, child: Text(l10n.shellRestart)),
            ],
          ),
        );
      },
    );
  }
}
