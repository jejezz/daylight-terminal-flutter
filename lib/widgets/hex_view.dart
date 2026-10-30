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
    final session = context.watch<SerialSession>();
    // 터미널 보기로 돌아가 있어도 IndexedStack이 이 위젯을 계속 데리고 있어서(스크롤 위치를 잃지 않으려고)
    // session이 알릴 때마다 build가 불린다. 안 보이는 동안은 2MB까지 자랄 수 있는 rawBytes를 hex 문자열로
    // 바꾸고 그 큰 글을 배치하는 비싼 일을 하지 않는다 — 이게 매번 돌면 화면 전체가 느려진다.
    if (session.viewMode != SerialViewMode.hex) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
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
