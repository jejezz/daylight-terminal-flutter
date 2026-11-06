import 'dart:ui' show Brightness, Color;

import 'package:flutter/painting.dart' show HSLColor;

import '../models/local_shell.dart';
import '../state/local_shell_session.dart';
import '../state/terminal_session.dart';

/// 탭에 보이는 글: 첫 줄(폴더 이름), 둘째 줄(실행 중인 명령 또는 셸 이름), 툴팁.
class TabLabel {
  const TabLabel({
    required this.primary,
    this.shell,
    this.secondary,
    this.running = false,
    this.tooltip,
    this.exitCode,
    this.colorKey,
  });

  final String primary;

  /// 첫 줄 앞에 옅게 붙는 짧은 셸 이름(`pwsh`, `bash` …). 폴더를 모르는 탭은 null (그때는 [primary]가 이미 셸 이름이다).
  final String? shell;

  /// 명령이 실행 중이면 그 명령, 아니면 셸 이름 같은 보조 글. 없으면 null.
  final String? secondary;

  /// [secondary]가 실행 중인 명령인가 (옅은 색 대신 본문 색으로 그린다).
  final bool running;

  final String? tooltip;

  /// 마지막으로 끝난 명령의 종료 코드. 모르면 null.
  final int? exitCode;

  /// 탭 색 막대의 색을 정하는 값 (같은 값이면 같은 색). 색을 줄 수 없는 탭(폴더를 모르는 로컬 셸)은 null.
  final String? colorKey;
}

abstract final class TabLabels {
  /// 막대 색의 가짓수. 색상환을 이만큼 나눠 쓴다.
  static const colorCount = 12;

  /// [key]에서 정한 색 막대 색 (같은 [key]는 늘 같은 색). 실행마다 같도록 FNV-1a 해시를 쓴다.
  /// 어두운 테마에서는 밝게, 밝은 테마에서는 어둡게 해서 둘 다 배경과 구분된다.
  static Color colorFor(String key, Brightness brightness) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final hue = (hash % colorCount) * (360 / colorCount);
    return HSLColor.fromAHSL(
      1,
      hue,
      0.62,
      brightness == Brightness.dark ? 0.62 : 0.42,
    ).toColor();
  }

  /// 탭에 붙이는 짧은 셸 이름. WSL은 배포판 이름.
  static String shortShellName(LocalShell s) =>
      s.kind == ShellKind.wsl ? (s.wslDistro ?? 'wsl') : s.id;

  /// 셸이 알려 준 경로(`/C:/Users/me`, `/home/me`)를 사람이 읽는 경로(`C:\Users\me`, `/home/me`)로.
  static String displayPath(String reported) {
    final m = RegExp(r'^/([A-Za-z]:)(.*)$').firstMatch(reported);
    if (m == null) return reported;
    final tail = m.group(2)!.replaceAll('/', r'\');
    return tail.isEmpty ? '${m.group(1)}\\' : '${m.group(1)}$tail';
  }

  /// 경로의 마지막 [depth]개 이름. 집 폴더는 `~`, 뿌리는 그대로. 예: `app\src`.
  static String folderName(String path, {String? home, int depth = 1}) {
    final norm = path.replaceAll(r'\', '/');
    if (home != null && _sameDir(norm, home.replaceAll(r'\', '/'))) return '~';
    final parts = norm.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return path; // `/`
    if (parts.length == 1 && parts.first.endsWith(':'))
      return '${parts.first}\\'; // `C:\`
    final take = depth.clamp(1, parts.length);
    return parts.sublist(parts.length - take).join('/');
  }

  static bool _sameDir(String a, String b) {
    String clean(String s) =>
        s.length > 1 && s.endsWith('/') ? s.substring(0, s.length - 1) : s;
    return clean(a).toLowerCase() == clean(b).toLowerCase();
  }

  /// [sessions]의 탭 글을 만든다. 폴더 이름이 겹치는 탭끼리는 부모 폴더를 붙여 구분한다.
  static List<TabLabel> compute(
    List<TerminalSession> sessions, {
    required String Function(TerminalSession) fallbackTitle,
  }) {
    final home = LocalShellSession.homeDirectory();
    final paths = <String?>[
      for (final s in sessions)
        s.reportedCwd == null ? null : displayPath(s.reportedCwd!),
    ];
    final names = <String?>[
      for (final p in paths) p == null ? null : folderName(p, home: home),
    ];
    return [
      for (var i = 0; i < sessions.length; i++)
        _label(
          sessions[i],
          paths[i],
          names[i] == null
              ? null
              : _unique(paths[i]!, names[i]!, names, i, home),
          fallbackTitle(sessions[i]),
        ),
    ];
  }

  /// 같은 이름이 다른 탭에도 있으면 부모 폴더까지 붙인다 (그래도 같으면 같은 폴더의 탭이다).
  static String _unique(
    String path,
    String name,
    List<String?> names,
    int self,
    String? home,
  ) {
    final clash = [
      for (var j = 0; j < names.length; j++)
        if (j != self && names[j] == name) j,
    ];
    if (clash.isEmpty || name == '~') return name;
    return folderName(path, home: home, depth: 2);
  }

  static TabLabel _label(
    TerminalSession s,
    String? path,
    String? folder,
    String fallback,
  ) {
    final shellName = s is LocalShellSession ? s.shell.name : null;
    final shortName = s is LocalShellSession ? shortShellName(s.shell) : null;
    final command = s.runningCommand;
    final running = s.commandRunning;
    final lines = <String>{
      if (path != null) path else fallback,
      ?shellName,
      if (command != null) '▶ $command',
      if (s.lastExitCode != null && command == null) 'exit ${s.lastExitCode}',
    };
    // 탭 글자와 똑같은 내용뿐이면 툴팁은 없다 (새 탭의 "새 연결" 등).
    final tip = lines.length == 1 && lines.first == fallback
        ? null
        : lines.join('\n');
    // 폴더를 알면 그 경로(Windows는 대소문자 무시)로, SSH·시리얼은 접속 이름으로 색을 정한다.
    final colorKey = path != null
        ? path.toLowerCase()
        : (s is LocalShellSession || s.tabTitle.isEmpty ? null : s.tabTitle);
    if (folder == null) {
      return TabLabel(
        primary: fallback,
        secondary: command,
        running: running,
        tooltip: tip,
        colorKey: colorKey,
      );
    }
    return TabLabel(
      primary: folder,
      shell: shortName,
      // 실행 중이면 명령, 아니면 전체 경로.
      secondary: running ? command : path,
      running: running,
      tooltip: tip,
      exitCode: s.lastExitCode,
      colorKey: colorKey,
    );
  }
}
