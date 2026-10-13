import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/ssh_profile.dart';
import '../services/profile_store.dart';
import '../state/sessions_controller.dart';
import '../state/ssh_session_provider.dart';
import '../theme/app_theme.dart';

/// 주소록을 연다. 접속을 고르면 비밀번호를 물은 뒤 연결한다 — 지금 탭이 비어 있으면 그 탭에서,
/// 이미 연결 중이면 새 탭에서.
Future<void> showAddressBook(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _AddressBookDialog());

class _AddressBookDialog extends StatefulWidget {
  const _AddressBookDialog();

  @override
  State<_AddressBookDialog> createState() => _AddressBookDialogState();
}

class _AddressBookDialogState extends State<_AddressBookDialog> {
  final _search = TextEditingController();
  late ProfileStore _store;
  List<SshProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _store = context.read<SessionsController>().store;
    _profiles = _store.profiles();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _profiles = _store.profiles());

  List<SshProfile> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return [
      for (final p in _profiles)
        if ('${p.name} ${p.host} ${p.username} ${p.group} ${p.note}'.toLowerCase().contains(q)) p,
    ];
  }

  /// 그룹 이름 순서(그룹 없음은 맨 뒤)로 묶는다. 같은 그룹 안에서는 이름 순.
  Map<String, List<SshProfile>> _grouped(List<SshProfile> list) {
    final groups = <String, List<SshProfile>>{};
    for (final p in list) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return {
      for (final k in keys) k: groups[k]!..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())),
    };
  }

  Future<void> _edit([SshProfile? profile]) async {
    final result = await showDialog<SshProfile>(
      context: context,
      builder: (_) => _EditDialog(
        profile: profile,
        groups: {
          for (final p in _profiles)
            if (p.group.isNotEmpty) p.group,
        },
      ),
    );
    if (result == null) return;
    await _store.saveProfile(result);
    _reload();
  }

  Future<void> _delete(SshProfile profile) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addressBookDelete),
        content: Text(l10n.addressBookDeleteConfirm(profile.label)),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.addressBookDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.deleteProfile(profile.id);
    _reload();
  }

  Future<void> _connect(SshProfile profile) async {
    final credentials = await showDialog<_Credentials>(
      context: context,
      builder: (_) => _PromptDialog(profile: profile),
    );
    if (credentials == null || !mounted) return;
    final controller = context.read<SessionsController>();
    // 지금 탭이 비어 있는 SSH 탭이면 거기에, 아니면 새 SSH 탭에 연결한다.
    var session = controller.current;
    if (session is! SshSessionProvider || session.connected || session.status == SessionStatus.connecting) {
      controller.add();
      session = controller.current!;
    }
    final ssh = session as SshSessionProvider;
    Navigator.pop(context);
    unawaited(ssh.connect(profile, password: credentials.password, keyPassphrase: credentials.passphrase));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final groups = _grouped(filtered);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.addressBookTitle, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.commonClose,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.addressBookSearch,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            _profiles.isEmpty ? l10n.addressBookEmpty : l10n.addressBookNoMatch,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, 0, AppSpacing.xs),
                              child: Text(
                                entry.key.isEmpty ? l10n.addressBookUngrouped : entry.key,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.primary),
                              ),
                            ),
                            for (final p in entry.value)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.dns_outlined),
                                title: Text(p.label, style: AppFonts.userContent),
                                subtitle: Text(
                                  p.note.isEmpty ? p.address : '${p.address} · ${p.note}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.userContent,
                                ),
                                onTap: () => _connect(p),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l10n.addressBookConnect,
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      onPressed: () => _connect(p),
                                    ),
                                    IconButton(
                                      tooltip: l10n.addressBookEdit,
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _edit(p),
                                    ),
                                    IconButton(
                                      tooltip: l10n.addressBookDelete,
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onPressed: () => _delete(p),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addressBookNew),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Credentials {
  const _Credentials({this.password, this.passphrase});
  final String? password;
  final String? passphrase;
}

/// 연결할 때마다 비밀번호(와 키 암호)를 묻는다. 저장하지 않는다.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.profile});

  final SshProfile profile;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _password = TextEditingController();
  final _passphrase = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
    context,
    _Credentials(
      password: _password.text.isEmpty ? null : _password.text,
      passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasKey = widget.profile.keyPath != null;
    return AlertDialog(
      title: Text(l10n.connectPromptTitle(widget.profile.label)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.profile.address, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.connectPassword, helperText: l10n.connectPromptHint),
              onSubmitted: (_) => _submit(),
            ),
            if (hasKey) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passphrase,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.connectKeyPassphrase),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.addressBookConnect)),
      ],
    );
  }
}

/// 접속 추가/편집. 저장하면 [SshProfile]을 돌려준다.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.profile, required this.groups});

  final SshProfile? profile;
  final Set<String> groups;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _group = TextEditingController(text: widget.profile?.group);
  late final _host = TextEditingController(text: widget.profile?.host);
  late final _port = TextEditingController(text: '${widget.profile?.port ?? 22}');
  late final _user = TextEditingController(text: widget.profile?.username);
  late final _key = TextEditingController(text: widget.profile?.keyPath);
  late final _note = TextEditingController(text: widget.profile?.note);

  @override
  void dispose() {
    for (final c in [_name, _group, _host, _port, _user, _key, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _portNumber {
    final n = int.tryParse(_port.text.trim());
    return n != null && n > 0 && n < 65536 ? n : null;
  }

  bool get _valid => _host.text.trim().isNotEmpty && _user.text.trim().isNotEmpty && _portNumber != null;

  Future<void> _pickKey() async {
    final file = await openFile();
    if (file != null) setState(() => _key.text = file.path);
  }

  void _save() {
    if (!_valid) return;
    final key = _key.text.trim();
    Navigator.pop(
      context,
      SshProfile(
        id: widget.profile?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        host: _host.text.trim(),
        port: _portNumber!,
        username: _user.text.trim(),
        keyPath: key.isEmpty ? null : key,
        name: _name.text.trim(),
        group: _group.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = widget.groups.toList()..sort();
    return AlertDialog(
      title: Text(widget.profile == null ? l10n.addressBookNew : l10n.addressBookEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.addressBookName),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _group,
                decoration: InputDecoration(labelText: l10n.addressBookGroup),
              ),
              if (groups.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final g in groups)
                        ActionChip(
                          label: Text(g, style: AppFonts.userContent.copyWith(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _group.text = g),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      decoration: InputDecoration(labelText: l10n.connectHost),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.connectPort),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _user,
                decoration: InputDecoration(labelText: l10n.connectUser),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _key,
                      decoration: InputDecoration(labelText: l10n.connectKeyFile),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(onPressed: _pickKey, child: Text(l10n.connectKeyBrowse)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                decoration: InputDecoration(labelText: l10n.addressBookNote),
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _valid ? _save : null, child: Text(l10n.addressBookSave)),
      ],
    );
  }
}
