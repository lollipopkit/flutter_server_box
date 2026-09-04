#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "tray_icon.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // After the engine, because it needs the messenger, and from here because
  // the tray's menu and its icon both hang off this window's message loop.
  tray_ = std::make_unique<TrayIcon>(
      GetHandle(), flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  // TrackPopupMenu runs a nested message loop in which WM_DESTROY can arrive.
  // Ask the tray to end that loop, but keep both it and its messenger alive
  // until the FlutterWindow itself unwinds after MessageHandler returns.
  if (tray_) tray_->Destroy();

  Win32Window::OnDestroy();
}

void FlutterWindow::ReleaseResourcesIfReady() {
  if (GetHandle() != nullptr || (tray_ && tray_->IsMenuOpen())) return;
  tray_ = nullptr;
  flutter_controller_ = nullptr;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The tray only claims its own callback and owner-drawn menu messages. It
  // has to see those before plugin delegates, since a handled result there
  // stops dispatch and leaves the native popup without a command or a row.
  if (tray_) {
    LRESULT tray_result = 0;
    if (tray_->HandleMessage(message, wparam, lparam, &tray_result)) {
      ReleaseResourcesIfReady();
      return tray_result;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  const LRESULT result =
      Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  ReleaseResourcesIfReady();
  return result;
}
