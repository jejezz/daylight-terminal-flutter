#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwctype>
#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Impeller is off by default (startup is ~3x slower with it). Set
  // DAYLIGHT_IMPELLER=1/true/on/yes to enable. The engine reads switches from
  // FLUTTER_ENGINE_SWITCHES, so set it before the engine is created.
  {
    wchar_t value[16] = {0};
    bool impeller = false;
    if (::GetEnvironmentVariableW(L"DAYLIGHT_IMPELLER", value, 16) > 0 &&
        value[0] != L'\0') {
      std::wstring v(value);
      for (auto &c : v) c = static_cast<wchar_t>(::towlower(c));
      impeller = (v == L"1" || v == L"true" || v == L"on" || v == L"yes");
    }
    ::SetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCHES", L"1");
    ::SetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCH_1",
                              impeller ? L"enable-impeller=true"
                                       : L"enable-impeller=false");
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Daylight Terminal", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
