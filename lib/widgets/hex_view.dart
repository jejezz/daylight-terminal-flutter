// portside-flutter의 hex_view.dart에서 가져와 고침.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/hex_dump.dart';
import '../settings/terminal_prefs.dart';
import '../state/serial_session.dart';
import '../theme/app_theme.dart';

/// 실제로 받은 바이트([SerialSession.rawBytes])를 hex dump로 보여 주는 읽기 전용 보기. 터미널 화면과 달리
/// 로컬 에코나 키 입력을 반영하지 않는다 — 오직 "진짜로 들어온 바이트"만 보인다. 글꼴은 터미널과 같다.
class HexView extends StatefulWidget {
  const HexView({super.key});

  @override
  State<HexView> createState() => _HexViewState();
}

class _HexViewState extends State<HexView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SerialSession>();
    final style = context.watch<TerminalPrefs>().style.toTextStyle();
    final scheme = Theme.of(context).colorScheme;
    final dump = hexDump(session.rawBytes);
    _scrollToBottom();

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: dump.isEmpty
          ? Text(l10n.serialHexEmpty, style: TextStyle(color: scheme.onSurfaceVariant))
          : SingleChildScrollView(
              controller: _scroll,
              child: SelectableText(dump, style: style.copyWith(color: scheme.onSurface, fontSize: (style.fontSize ?? 14) * 0.85)),
            ),
    );
  }
}
