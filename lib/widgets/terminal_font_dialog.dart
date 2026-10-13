import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../settings/terminal_prefs.dart';
import '../theme/app_theme.dart';

/// 터미널 글꼴과 크기를 고른다. 바꾸는 즉시 모든 탭의 터미널에 적용되고 저장된다.
Future<void> showTerminalFontDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _TerminalFontDialog());

class _TerminalFontDialog extends StatefulWidget {
  const _TerminalFontDialog();

  @override
  State<_TerminalFontDialog> createState() => _TerminalFontDialogState();
}

class _TerminalFontDialogState extends State<_TerminalFontDialog> {
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
    final preview = prefs.style;

    return AlertDialog(
      title: Text(l10n.terminalFontTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: AppSpacing.sm),
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
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await prefs.reset();
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
