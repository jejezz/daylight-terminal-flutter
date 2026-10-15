import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../settings/refresh_prefs.dart';
import '../settings/restore_prefs.dart';
import '../settings/terminal_prefs.dart';
import '../theme/app_theme.dart';

/// 설정 창: 새로 고침 옵션, 시작할 때 탭 복원, 터미널 글꼴·크기·스크롤백. 바꾸는 즉시 적용되고 저장된다.
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
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Text(
                _sample,
                style: TextStyle(
                  color: const Color(0xFFE5E5E5),
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
