#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutex[] =
    L"Local\\tech.lolli.toolbox.ServerBox.SingleInstance";
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"ServerBox";
constexpr DWORD kExistingWindowWaitTimeoutMs = 5000;
constexpr DWORD kExistingWindowPollIntervalMs = 50;

bool ActivateExistingWindow() {
  const ULONGLONG deadline = GetTickCount64() + kExistingWindowWaitTimeoutMs;
  while (true) {
    const HWND window = FindWindowW(kWindowClassName, kWindowTitle);
    if (window != nullptr) {
      ShowWindowAsync(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
      SetForegroundWindow(window);
      return true;
    }
    if (GetTickCount64() >= deadline) {
      return false;
    }
    Sleep(kExistingWindowPollIntervalMs);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  const HANDLE single_instance =
      CreateMutexW(nullptr, FALSE, kSingleInstanceMutex);
  const DWORD mutex_error = GetLastError();
  if (single_instance == nullptr) {
    const std::wstring message =
        L"CreateMutexW failed with Win32 error " +
        std::to_wstring(mutex_error) + L".\n";
    OutputDebugStringW(message.c_str());
    return EXIT_FAILURE;
  }
  if (mutex_error == ERROR_ALREADY_EXISTS) {
    const bool activated = ActivateExistingWindow();
    CloseHandle(single_instance);
    return activated ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(400, 777);
  if (!window.CreateAndShow(kWindowTitle, origin, size)) {
    if (single_instance != nullptr) {
      CloseHandle(single_instance);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance != nullptr) {
    CloseHandle(single_instance);
  }
  return EXIT_SUCCESS;
}
