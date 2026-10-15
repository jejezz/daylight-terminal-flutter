import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/serial_settings.dart';
import '../services/serial_service.dart';
import '../state/serial_session.dart';
import '../state/terminal_session.dart';
import '../theme/app_theme.dart';

/// 연결되지 않은 시리얼 탭에 보이는 폼: 포트와 통신 설정(보드레이트, 데이터 비트, 패리티, 정지 비트, 흐름 제어).
/// 연결 안 한 동안은 2초마다 포트 목록을 다시 읽어서 USB 장치를 꽂고 뽑는 것을 반영한다.
class SerialConnectPanel extends StatefulWidget {
  const SerialConnectPanel({super.key, this.portLister});

  /// 포트 목록을 읽는 함수. 테스트에서 바꿔 끼운다.
  final List<String> Function()? portLister;

  @override
  State<SerialConnectPanel> createState() => _SerialConnectPanelState();
}

class _SerialConnectPanelState extends State<SerialConnectPanel> {
  static const _buttonHeight = 44.0;

  late final TextEditingController _baud;
  late List<String> _ports;
  Timer? _poll;
  bool _baudValid = true;

  List<String> _list() => (widget.portLister ?? SerialService.availablePorts)();

  @override
  void initState() {
    super.initState();
    final session = context.read<SerialSession>();
    _baud = TextEditingController(text: '${session.pendingBaud}');
    _ports = _list();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _baud.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final ports = _list();
    if (listEquals(ports, _ports)) return;
    setState(() => _ports = ports);
    final session = context.read<SerialSession>();
    // 고른 포트가 뽑혔으면 선택을 비운다.
    if (session.pendingPort != null && !ports.contains(session.pendingPort)) session.setPendingPort(null);
  }

  void _onBaudChanged(String text) {
    final value = int.tryParse(text.trim());
    final valid = value != null && value > 0;
    setState(() => _baudValid = valid);
    if (valid) context.read<SerialSession>().setPendingBaud(value);
  }

  void _pickBaud(int baud) {
    _baud.text = '$baud';
    _onBaudChanged(_baud.text);
  }

  void _connect() {
    if (!_baudValid) return;
    context.read<SerialSession>().connect();
  }

  String _errorText(AppLocalizations l10n, SerialServiceException e) => switch (e.kind) {
    SerialErrorKind.openFailed => l10n.serialErrorOpen(e.detail ?? ''),
    SerialErrorKind.io => l10n.serialErrorIo(e.detail ?? ''),
    SerialErrorKind.notOpen => l10n.serialErrorNotOpen,
    SerialErrorKind.deviceDisconnected => l10n.serialErrorDisconnected,
  };

  String _parityLabel(AppLocalizations l10n, SerialParity p) => switch (p) {
    SerialParity.none => l10n.serialParityNone,
    SerialParity.odd => l10n.serialParityOdd,
    SerialParity.even => l10n.serialParityEven,
    SerialParity.mark => l10n.serialParityMark,
    SerialParity.space => l10n.serialParitySpace,
  };

  String _flowLabel(AppLocalizations l10n, SerialFlow f) => switch (f) {
    SerialFlow.none => l10n.serialFlowNone,
    SerialFlow.rtsCts => l10n.serialFlowRtsCts,
    SerialFlow.xonXoff => l10n.serialFlowXonXoff,
    SerialFlow.dtrDsr => l10n.serialFlowDtrDsr,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SerialSession>();
    final scheme = Theme.of(context).colorScheme;
    final selected = _ports.contains(session.pendingPort) ? session.pendingPort : null;
    final error = session.error;
    final canConnect = selected != null && _baudValid;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.serialTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              if (session.status == SessionStatus.error && error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: SelectableText(_errorText(l10n, error), style: TextStyle(color: scheme.error)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(selected),
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.serialPort, hintText: l10n.serialPortHint),
                      items: [
                        for (final p in _ports)
                          DropdownMenuItem(
                            value: p,
                            // 포트 이름은 앞부분(/dev/)이 모두 같아서 좁은 폭에서는 구분되는 뒷부분이 안 보인다.
                            child: Tooltip(
                              message: p,
                              child: Text(SerialSession.shortPortName(p), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                      onChanged: session.setPendingPort,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.serialPortRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => setState(() {
                      _ports = _list();
                      if (session.pendingPort != null && !_ports.contains(session.pendingPort)) {
                        session.setPendingPort(null);
                      }
                    }),
                  ),
                ],
              ),
              if (_ports.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.serialNoPorts,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baud,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.serialBaud,
                        errorText: _baudValid ? null : l10n.serialBaudInvalid,
                      ),
                      onChanged: _onBaudChanged,
                      onSubmitted: (_) => canConnect ? _connect() : null,
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: l10n.serialBaud,
                    icon: const Icon(Icons.speed_rounded),
                    onSelected: _pickBaud,
                    itemBuilder: (context) => [
                      for (final b in SerialSettings.commonBaudRates) PopupMenuItem(value: b, child: Text('$b')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: session.pendingDataBits,
                      decoration: InputDecoration(labelText: l10n.serialDataBits),
                      items: [
                        for (final b in SerialSettings.dataBitsChoices) DropdownMenuItem(value: b, child: Text('$b')),
                      ],
                      onChanged: (v) => v == null ? null : session.setPendingDataBits(v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: session.pendingStopBits,
                      decoration: InputDecoration(labelText: l10n.serialStopBits),
                      items: [
                        for (final b in SerialSettings.stopBitsChoices) DropdownMenuItem(value: b, child: Text('$b')),
                      ],
                      onChanged: (v) => v == null ? null : session.setPendingStopBits(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<SerialParity>(
                initialValue: session.pendingParity,
                decoration: InputDecoration(labelText: l10n.serialParity),
                items: [
                  for (final p in SerialParity.values) DropdownMenuItem(value: p, child: Text(_parityLabel(l10n, p))),
                ],
                onChanged: (v) => v == null ? null : session.setPendingParity(v),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<SerialFlow>(
                initialValue: session.pendingFlow,
                decoration: InputDecoration(labelText: l10n.serialFlow),
                items: [
                  for (final f in SerialFlow.values) DropdownMenuItem(value: f, child: Text(_flowLabel(l10n, f))),
                ],
                onChanged: (v) => v == null ? null : session.setPendingFlow(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(_buttonHeight)),
                onPressed: canConnect ? _connect : null,
                child: Text(session.status == SessionStatus.error ? l10n.connectReconnect : l10n.connectAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
