import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _IsUserAnAdminC = Int32 Function();
typedef _IsUserAnAdminDart = int Function();
typedef _ShellExecuteC =
    IntPtr Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Int32);
typedef _ShellExecuteDart =
    int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, int);

/// Windows에서 앱을 관리자 권한(UAC 상승)으로 쓰는 데 필요한 것.
/// 실행 중인 프로세스의 권한은 바꿀 수 없고, 로컬 셸(ConPTY)은 앱의 권한을 그대로 물려받는다.
/// 그래서 "관리자 모드"는 앱을 관리자 권한으로 다시 띄우는 것이다.
class Elevation {
  const Elevation._();

  static bool get supported => Platform.isWindows;

  /// 지금 프로세스가 관리자 권한으로 돌고 있는지. Windows가 아니면 false.
  static bool get isElevated => _elevated ??= _queryElevated();
  static bool? _elevated;

  static bool _queryElevated() {
    if (!supported) return false;
    try {
      final fn = DynamicLibrary.open('shell32.dll').lookupFunction<_IsUserAnAdminC, _IsUserAnAdminDart>('IsUserAnAdmin');
      return fn() != 0;
    } catch (_) {
      return false;
    }
  }

  /// 같은 실행 파일을 관리자 권한으로 띄운다 (UAC 확인 창이 뜬다).
  /// 새 프로세스가 시작되면 true, 사용자가 UAC를 거절했거나 실패하면 false — 이때 현재 앱은 그대로 둔다.
  static bool relaunchAsAdmin() {
    if (!supported) return false;
    final verb = 'runas'.toNativeUtf16();
    final file = Platform.resolvedExecutable.toNativeUtf16();
    try {
      final shellExecute = DynamicLibrary.open('shell32.dll').lookupFunction<_ShellExecuteC, _ShellExecuteDart>(
        'ShellExecuteW',
      );
      const swShowNormal = 1;
      // 32보다 크면 성공 (ShellExecute 규약).
      return shellExecute(0, verb, file, nullptr, nullptr, swShowNormal) > 32;
    } catch (_) {
      return false;
    } finally {
      calloc.free(verb);
      calloc.free(file);
    }
  }
}
