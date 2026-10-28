import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// [child](비밀번호 칸)에 포커스가 있는 동안 Caps Lock이 켜져 있으면 그 아래에 경고를 보여준다.
/// 포커스를 얻은 뒤 키를 눌러야 상태를 알 수 있으므로, 포커스를 얻는 순간에는 그 전에 알아낸
/// 값을 그대로 쓴다(시작할 때는 꺼져 있다고 가정).
class CapsLockWarning extends StatefulWidget {
  const CapsLockWarning({super.key, required this.focusNode, required this.child});

  final FocusNode focusNode;
  final Widget child;

  @override
  State<CapsLockWarning> createState() => _CapsLockWarningState();
}

class _CapsLockWarningState extends State<CapsLockWarning> {
  bool _capsLockOn = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  bool _onKey(KeyEvent event) {
    final on = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (on != _capsLockOn) setState(() => _capsLockOn = on);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.focusNode.hasFocus && _capsLockOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.child,
        if (show)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).capsLockWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
