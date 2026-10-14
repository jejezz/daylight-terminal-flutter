// portside-flutter의 status_bar.dart(기록 버튼)에서 가져와 고침.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/file_reveal_service.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';
import '../utils/app_shortcuts.dart';

/// 연결 상태, 기록(Recording) 토글, 기록 파일 위치 열기, 터미널 내용 전체를 클립보드/파일로.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  static Future<void> _copyBuffer(BuildContext context, TerminalSession session) async {
    final l10n = AppLocalizations.of(context);
    final text = session.bufferText();
    if (text.isEmpty) {
      _toast(context, l10n.statusBufferEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _toast(context, l10n.statusBufferCopied('\n'.allMatches(text).length));
  }

  static Future<void> _saveBuffer(BuildContext context, TerminalSession session) async {
    final l10n = AppLocalizations.of(context);
    if (session.bufferText().isEmpty) {
      _toast(context, l10n.statusBufferEmpty);
      return;
    }
    final path = await session.saveBufferToFile(confirmButtonText: l10n.statusSaveBufferConfirm);
    if (path != null && context.mounted) _toast(context, l10n.statusBufferSaved(path.split(Platform.pathSeparator).last));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<TerminalSession>();
    final scheme = Theme.of(context).colorScheme;
    final key = AppShortcut.toggleLogging.label;
    final small = Theme.of(context).textTheme.bodySmall;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: session.connected ? AppColors.success : scheme.outline),
          const SizedBox(width: AppSpacing.sm),
          Text(session.statusLabel, style: small),
          const Spacer(),
          if (session.isLogging) ...[
            Flexible(
              child: Text(
                l10n.statusRecording(session.logFilePath?.split(Platform.pathSeparator).last ?? ''),
                style: small?.copyWith(color: AppColors.danger),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Tooltip(
            message: l10n.statusStripAnsiTooltip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.statusStripAnsi, style: small),
                const SizedBox(width: AppSpacing.xs),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(value: session.stripAnsi, onChanged: session.setStripAnsi),
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.statusCopyBuffer,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: () => _copyBuffer(context, session),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.statusSaveBuffer,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: () => _saveBuffer(context, session),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: session.isLogging ? l10n.statusStopRecording(key) : l10n.statusStartRecording(key),
            color: session.isLogging ? AppColors.danger : scheme.onSurfaceVariant,
            icon: Icon(session.isLogging ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded),
            onPressed: session.connected || session.isLogging
                ? () => session.toggleLogging(confirmButtonText: l10n.logSaveConfirm)
                : null,
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: session.logFilePath == null ? l10n.statusNoLogFile : l10n.statusRevealLog,
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: session.logFilePath == null ? null : () => FileRevealService.reveal(session.logFilePath!),
          ),
        ],
      ),
    );
  }
}
