import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 탭 이름을 묻는 창. 새 이름을 돌려주고, 빈 문자열이면 "자동 이름으로 되돌리기", 취소하면 null.
Future<String?> showTabRenameDialog(BuildContext context, {required String initial, required bool hasCustom}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TabRenameDialog(initial: initial, hasCustom: hasCustom),
    );

class _TabRenameDialog extends StatefulWidget {
  const _TabRenameDialog({required this.initial, required this.hasCustom});

  final String initial;
  final bool hasCustom;

  @override
  State<_TabRenameDialog> createState() => _TabRenameDialogState();
}

class _TabRenameDialogState extends State<_TabRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.tabRename),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: l10n.tabRenameField, helperText: l10n.tabRenameHelp),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        if (widget.hasCustom) TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(l10n.tabRenameAuto)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.commonOk)),
      ],
    );
  }
}
