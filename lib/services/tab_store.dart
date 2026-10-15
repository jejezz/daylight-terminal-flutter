import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/serial_settings.dart';
import '../models/ssh_profile.dart';

/// 다시 열 탭 하나. 비밀번호·키 암호는 어디에도 없다 (SSH는 접속 정보만 채운 접속 화면으로 다시 연다).
sealed class SavedTab {
  const SavedTab();

  Map<String, Object?> toJson();

  static SavedTab? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      switch (json['type']) {
        case 'ssh':
          final profile = SshProfile.fromJson(json['profile']);
          return profile == null ? null : SavedSshTab(profile);
        case 'local':
          final shell = json['shell'], folder = json['folder'];
          return shell is String && folder is String ? SavedLocalTab(shell, folder) : null;
        case 'serial':
          final folder = json['folder'], s = json['settings'];
          if (folder is! String || s is! Map || s['port'] is! String) return null;
          return SavedSerialTab(
            SerialSettings(
              portName: s['port'] as String,
              baudRate: s['baud'] is int ? s['baud'] as int : 115200,
              dataBits: SerialSettings.dataBitsChoices.contains(s['dataBits']) ? s['dataBits'] as int : 8,
              parity: SerialParity.values.asNameMap()[s['parity']] ?? SerialParity.none,
              stopBits: SerialSettings.stopBitsChoices.contains(s['stopBits']) ? s['stopBits'] as int : 1,
              flow: SerialFlow.values.asNameMap()[s['flow']] ?? SerialFlow.none,
            ),
            folder,
          );
      }
    } catch (_) {}
    return null;
  }
}

class SavedSshTab extends SavedTab {
  const SavedSshTab(this.profile);
  final SshProfile profile;

  @override
  Map<String, Object?> toJson() => {'type': 'ssh', 'profile': profile.toJson()};
}

class SavedLocalTab extends SavedTab {
  const SavedLocalTab(this.shellId, this.folder);
  final String shellId;
  final String folder;

  @override
  Map<String, Object?> toJson() => {'type': 'local', 'shell': shellId, 'folder': folder};
}

class SavedSerialTab extends SavedTab {
  const SavedSerialTab(this.settings, this.folder);
  final SerialSettings settings;
  final String folder;

  @override
  Map<String, Object?> toJson() => {
    'type': 'serial',
    'folder': folder,
    'settings': {
      'port': settings.portName,
      'baud': settings.baudRate,
      'dataBits': settings.dataBits,
      'parity': settings.parity.name,
      'stopBits': settings.stopBits,
      'flow': settings.flow.name,
    },
  };
}

/// 열려 있던 탭 목록과 선택된 탭.
class SavedTabs {
  const SavedTabs(this.tabs, this.selected);
  final List<SavedTab> tabs;
  final int selected;

  String encode() => jsonEncode({'selected': selected, 'tabs': [for (final t in tabs) t.toJson()]});

  /// 읽을 수 없는 것(깨진 값, 모르는 종류)은 건너뛴다.
  static SavedTabs? decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['tabs'] is! List) return null;
      final tabs = [for (final t in json['tabs'] as List) ?SavedTab.fromJson(t)];
      final sel = json['selected'];
      return SavedTabs(tabs, sel is int ? sel.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1) : 0);
    } on FormatException {
      return null;
    }
  }
}

/// 마지막으로 열어 둔 탭을 SharedPreferences에 저장한다.
class TabStore {
  TabStore(this._prefs);

  static const _key = 'open_tabs';

  final SharedPreferences _prefs;

  static Future<TabStore> load() async => TabStore(await SharedPreferences.getInstance());

  SavedTabs? read() => SavedTabs.decode(_prefs.getString(_key));

  /// 저장된 것과 같으면 쓰지 않는다 (시리얼처럼 자주 알리는 탭이 있어도 디스크를 덜 쓴다).
  Future<void> write(SavedTabs tabs) async {
    final raw = tabs.encode();
    if (_prefs.getString(_key) == raw) return;
    await _prefs.setString(_key, raw);
  }

  Future<void> clear() => _prefs.remove(_key);
}
