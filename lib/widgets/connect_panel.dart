import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/ssh_profile.dart';
import '../state/sessions_controller.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';
import 'address_book_dialog.dart';

/// 연결되지 않은 탭에 보이는 접속 폼. 저장된 접속을 고르거나 새로 입력한다.
/// 비밀번호와 키 암호는 저장하지 않는다.
class ConnectPanel extends StatefulWidget {
  const ConnectPanel({super.key});

  @override
  State<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends State<ConnectPanel> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _keyPath = TextEditingController();
  final _passphrase = TextEditingController();
  bool _save = true;
  String? _profileId;

  /// 불러온 주소록 항목. 이름·그룹·메모를 접속 때 잃지 않게 들고 있는다.
  SshProfile? _base;
  late List<SshProfile> _profiles;

  @override
  void initState() {
    super.initState();
    final session = context.read<SshSessionProvider>();
    _profiles = session.store.profiles();
    // 끊어진 탭을 다시 열 때는 마지막에 쓴 접속 정보를 채워 둔다.
    final last = session.profile;
    if (last != null) _fill(last);
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _password, _keyPath, _passphrase]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(SshProfile p) {
    _base = p;
    _profileId = p.id;
    _host.text = p.host;
    _port.text = '${p.port}';
    _user.text = p.username;
    _keyPath.text = p.keyPath ?? '';
  }

  Future<void> _pickKey() async {
    final file = await openFile();
    if (file != null) setState(() => _keyPath.text = file.path);
  }

  Future<void> _deleteProfile() async {
    final id = _profileId;
    if (id == null) return;
    final store = context.read<SshSessionProvider>().store;
    await store.deleteProfile(id);
    setState(() {
      _profiles = store.profiles();
      _profileId = null;
      _base = null;
    });
  }

  bool get _valid => _host.text.trim().isNotEmpty && _user.text.trim().isNotEmpty && int.tryParse(_port.text) != null;

  Future<void> _connect() async {
    if (!_valid) return;
    final session = context.read<SshSessionProvider>();
    final key = _keyPath.text.trim();
    final id = _profileId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final fields = SshProfile(
      id: id,
      host: _host.text.trim(),
      port: int.parse(_port.text),
      username: _user.text.trim(),
      keyPath: key.isEmpty ? null : key,
    );
    final base = _base;
    final profile = base == null
        ? fields
        : base.copyWith(
            host: fields.host,
            port: fields.port,
            username: fields.username,
            keyPath: fields.keyPath,
            clearKey: fields.keyPath == null,
          );
    if (_save) await session.store.saveProfile(profile);
    await session.connect(
      profile,
      password: _password.text.isEmpty ? null : _password.text,
      keyPassphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
    );
    // 연결에 성공하면 입력창에 비밀번호가 남지 않게 한다 (실패하면 다시 시도할 수 있게 둔다).
    if (session.connected) {
      _password.clear();
      _passphrase.clear();
    }
    if (mounted) setState(() => _profiles = session.store.profiles());
  }

  String _errorText(AppLocalizations l10n, SshSessionProvider s) => switch (s.error) {
    SessionError.hostKeyMismatch => l10n.connectHostKeyMismatch(s.errorDetail ?? ''),
    SessionError.closed => l10n.connectClosed,
    _ => l10n.connectFailed(s.errorDetail ?? ''),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<SshSessionProvider>();
    final scheme = Theme.of(context).colorScheme;
    final connecting = session.status == SessionStatus.connecting;
    final controller = context.watch<SessionsController>();
    final shells = controller.shells;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.connectTitle, style: Theme.of(context).textTheme.titleLarge)),
                  OutlinedButton.icon(
                    onPressed: () => showAddressBook(context),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(l10n.addressBookOpen),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (session.status == SessionStatus.error) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: SelectableText(_errorText(l10n, session), style: TextStyle(color: scheme.error)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_profiles.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _profiles.any((p) => p.id == _profileId) ? _profileId : null,
                        decoration: InputDecoration(labelText: l10n.connectSavedProfiles),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l10n.connectNewProfile)),
                          for (final p in _profiles) DropdownMenuItem(value: p.id, child: Text(p.label)),
                        ],
                        onChanged: (id) => setState(() {
                          if (id == null) {
                            _profileId = null;
                            _base = null;
                            for (final c in [_host, _user, _keyPath]) {
                              c.clear();
                            }
                            _port.text = '22';
                          } else {
                            _fill(_profiles.firstWhere((p) => p.id == id));
                          }
                        }),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.connectDeleteProfile,
                      onPressed: _profileId == null ? null : _deleteProfile,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.connectHost),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      decoration: InputDecoration(labelText: l10n.connectPort),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _user,
                decoration: InputDecoration(labelText: l10n.connectUser),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.connectPassword),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyPath,
                      decoration: InputDecoration(labelText: l10n.connectKeyFile),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(onPressed: _pickKey, child: Text(l10n.connectKeyBrowse)),
                ],
              ),
              if (_keyPath.text.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.connectKeyPassphrase),
                  onSubmitted: (_) => _connect(),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: _save,
                onChanged: (v) => setState(() => _save = v ?? true),
                title: Text(l10n.connectSaveProfile, style: Theme.of(context).textTheme.bodyMedium),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: connecting || !_valid ? null : _connect,
                child: connecting
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: AppSpacing.sm),
                          Text(l10n.connecting),
                        ],
                      )
                    : Text(session.status == SessionStatus.error ? l10n.connectReconnect : l10n.connectAction),
              ),
              // 서버 없이 이 PC의 셸을 바로 연다. 이 빈 탭이 그 셸 탭으로 바뀐다.
              if (shells.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        l10n.newTabLocalShell,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final shell in shells)
                      OutlinedButton.icon(
                        onPressed: connecting ? null : () => controller.openLocalHere(shell),
                        icon: const Icon(Icons.terminal_rounded, size: 18),
                        label: Text(shell.name),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
