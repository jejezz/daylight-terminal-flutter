import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ssh_profile.dart';

/// 접속 정보 목록과 신뢰한 호스트 키(TOFU)를 SharedPreferences에 저장한다.
class ProfileStore {
  ProfileStore(this._prefs);

  static const _profilesKey = 'ssh_profiles';
  static const _hostKeysKey = 'ssh_known_hosts';

  final SharedPreferences _prefs;

  static Future<ProfileStore> load() async => ProfileStore(await SharedPreferences.getInstance());

  List<SshProfile> profiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final j in decoded) ?SshProfile.fromJson(j)];
    } on FormatException {
      return [];
    }
  }

  Future<void> saveProfile(SshProfile profile) async {
    final list = profiles();
    final i = list.indexWhere((p) => p.id == profile.id);
    if (i == -1) {
      list.add(profile);
    } else {
      list[i] = profile;
    }
    await _prefs.setString(_profilesKey, jsonEncode([for (final p in list) p.toJson()]));
  }

  Future<void> deleteProfile(String id) async {
    final list = profiles()..removeWhere((p) => p.id == id);
    await _prefs.setString(_profilesKey, jsonEncode([for (final p in list) p.toJson()]));
  }

  Map<String, String> _hostKeys() {
    final raw = _prefs.getString(_hostKeysKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  String? knownHostKey(String host, int port) => _hostKeys()['$host:$port'];

  Future<void> trustHostKey(String host, int port, String fingerprint) async {
    final keys = _hostKeys()..['$host:$port'] = fingerprint;
    await _prefs.setString(_hostKeysKey, jsonEncode(keys));
  }
}
