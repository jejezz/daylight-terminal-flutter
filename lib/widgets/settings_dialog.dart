import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:provider/provider.dart';
import 'package:xterm2/ui.dart' show TerminalTheme;

import '../l10n/app_localizations.dart';
import '../services/elevation.dart';
import '../settings/refresh_prefs.dart';
import '../settings/settings_menus.dart';
import '../state/sessions_controller.dart';
import '../settings/restore_prefs.dart';
import '../settings/terminal_prefs.dart';
import '../settings/terminal_schemes.dart';
import '../theme/app_theme.dart';

/// 설정 창: 새로 고침 옵션, 시작할 때 탭 복원, 터미널 글꼴·크기·스크롤백·색상 구성표. 바꾸는 즉시 적용되고 저장된다.
Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  static const _customValue = '\u0000custom';

  late final TextEditingController _custom;
  bool _customMode = false;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<TerminalPrefs>();
    _customMode = !prefs.isPreset;
    _custom = TextEditingController(text: prefs.isPreset ? '' : prefs.family);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// 탭 목록을 저장한 뒤 관리자 권한으로 새로 띄우고, 성공하면 이 앱은 끝낸다. UAC를 거절하면 그대로 둔다.
  Future<void> _restartAsAdmin() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).adminRestartFailed;
    await context.read<SessionsController>().saveTabsNow();
    if (Elevation.relaunchAsAdmin()) {
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  /// Powerline·Nerd Font 글리프와 한글, 헷갈리기 쉬운 글자를 한 번에 보여 주는 미리보기.
  static const _sample =
      ' user@host   main   ~/src   ✔\n'
      '한글 가나다 ABC abc 0O 1lI {} [] -> =>';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = context.watch<TerminalPrefs>();
    final refresh = context.watch<RefreshPrefs>();
    final restore = context.watch<RestorePrefs>();
    final preview = prefs.style;

    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SingleChildScrollView(child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(l10n.settingsSectionAppearance),
            Text(l10n.settingsMode, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            const ModeSegmentedButton(),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.settingsPalette, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            const AccentPaletteChips(),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.languageMenuTooltip, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            const LanguageSegmentedButton(),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(l10n.settingsSectionRefresh),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.refreshLocal),
              subtitle: Text(l10n.refreshLocalHelp),
              value: refresh.local,
              onChanged: refresh.setLocal,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.refreshSsh),
              subtitle: Text(l10n.refreshSshHelp),
              value: refresh.ssh,
              onChanged: refresh.setSsh,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(l10n.settingsSectionStartup),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.restoreTabs),
              subtitle: Text(l10n.restoreTabsHelp),
              value: restore.enabled,
              onChanged: restore.setEnabled,
            ),
            if (Elevation.supported) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(l10n.settingsSectionAdmin),
              if (Elevation.isElevated)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_rounded),
                  title: Text(l10n.adminRunning),
                  subtitle: Text(l10n.adminRunningHelp),
                )
              else ...[
                Text(l10n.adminRestartHelp, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(l10n.adminRestart),
                    onPressed: _restartAsAdmin,
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(l10n.settingsSectionTerminalFont),
            DropdownButtonFormField<String>(
              initialValue: _customMode ? _customValue : prefs.family,
              decoration: InputDecoration(labelText: l10n.terminalFontFamily),
              items: [
                for (final (label, family) in TerminalPrefs.presets)
                  DropdownMenuItem(
                    value: family,
                    child: Text(family == TerminalPrefs.bundledFamily ? l10n.terminalFontBundled(label) : label),
                  ),
                DropdownMenuItem(value: _customValue, child: Text(l10n.terminalFontCustom)),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == _customValue) {
                  setState(() => _customMode = true);
                } else {
                  setState(() => _customMode = false);
                  prefs.setFamily(value);
                }
              },
            ),
            if (_customMode) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _custom,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.terminalFontCustomName,
                  helperText: l10n.terminalFontCustomHelp,
                  helperMaxLines: 3,
                ),
                onChanged: prefs.setFamily,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(l10n.terminalFontSize),
                Expanded(
                  child: Slider(
                    value: prefs.size,
                    min: TerminalPrefs.minSize,
                    max: TerminalPrefs.maxSize,
                    divisions: (TerminalPrefs.maxSize - TerminalPrefs.minSize).round(),
                    label: prefs.size.round().toString(),
                    onChanged: prefs.setSize,
                  ),
                ),
                SizedBox(width: 32, child: Text('${prefs.size.round()}', textAlign: TextAlign.end)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: prefs.scrollback,
              decoration: InputDecoration(
                labelText: l10n.terminalScrollback,
                helperText: l10n.terminalScrollbackHelp,
                helperMaxLines: 3,
              ),
              items: [
                for (final n in {...TerminalPrefs.scrollbackPresets, prefs.scrollback}.toList()..sort())
                  DropdownMenuItem(value: n, child: Text(l10n.terminalScrollbackLines(n))),
              ],
              onChanged: (n) {
                if (n != null) prefs.setScrollback(n);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(l10n.settingsSectionTerminalColors),
            DropdownButtonFormField<String>(
              initialValue: prefs.scheme.id,
              decoration: InputDecoration(labelText: l10n.terminalColorScheme),
              items: [
                for (final s in TerminalScheme.all)
                  DropdownMenuItem(
                    value: s.id,
                    child: Row(
                      children: [
                        _Swatches(s.theme),
                        const SizedBox(width: AppSpacing.md),
                        Text(s.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) prefs.setScheme(TerminalScheme.byId(id));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: prefs.scheme.theme.background,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Text(
                _sample,
                style: TextStyle(
                  color: prefs.scheme.theme.foreground,
                  fontSize: preview.fontSize,
                  height: preview.height,
                  fontFamily: preview.fontFamily,
                  fontFamilyFallback: preview.fontFamilyFallback,
                ),
              ),
            ),
          ],
        ),
      )),
      actions: [
        TextButton(
          onPressed: () async {
            await prefs.reset();
            await refresh.reset();
            await restore.reset();
            setState(() {
              _customMode = false;
              _custom.clear();
            });
          },
          child: Text(l10n.terminalFontReset),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
      ],
    );
  }
}

/// 구성표의 배경 위에 ANSI 8색을 늘어놓은 견본.
class _Swatches extends StatelessWidget {
  const _Swatches(this.theme);

  final TerminalTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = [
      theme.red,
      theme.green,
      theme.yellow,
      theme.blue,
      theme.magenta,
      theme.cyan,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final c in colors) Container(width: 10, height: 14, color: c)],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
