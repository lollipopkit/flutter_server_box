#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

// The notification-area icon, and the rows in its menu.
//
// Hand-written for the same reason as the macOS one: a row here is a name, a
// sparkline and a line of readings, and a menu item's text is one line of one
// font. Windows draws anything else through owner-drawn items — the menu tells
// this class how big each row is (WM_MEASUREITEM) and then asks it to paint
// (WM_DRAWITEM) — which is the whole of the difference from an ordinary popup.
//
// Everything drawn is decided in Dart and arrives formatted; see `TrayModel`.
// Nothing here knows what a percentage is or what any of it means.
class TrayIcon {
 public:
  // `window` owns the message loop this listens on, and is what the menu is
  // posted from — a popup menu needs a window to send its notifications to.
  TrayIcon(HWND window, flutter::BinaryMessenger* messenger);
  ~TrayIcon();

  // The messages this answers, from the runner's own handler. Returns true
  // when the message was ours and should go no further.
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                     LRESULT* result);

  // The tray's own callback, and the two the owner-drawn items need. Kept
  // apart from `WM_APP` so the runner can forward exactly these.
  static constexpr UINT kCallbackMessage = WM_APP + 1;

 private:
  struct Reading {
    std::wstring label;
    std::wstring value;
  };

  struct Row {
    std::string id;
    std::wstring name;
    std::wstring state;
    std::wstring label;
    std::vector<Reading> readings;
    std::vector<double> chart;
  };

  bool AddIcon();
  bool OwnsRowItem(UINT id, ULONG_PTR data) const;
  void Update(const flutter::EncodableMap& payload);
  void Destroy();
  void ShowMenu();
  void Measure(MEASUREITEMSTRUCT* measure);
  void Draw(DRAWITEMSTRUCT* draw);
  bool OnCommand(UINT id);

  HWND window_ = nullptr;
  NOTIFYICONDATA icon_data_ = {};
  bool icon_added_ = false;
  bool modern_notifications_ = false;
  HICON icon_ = nullptr;
  HMENU menu_ = nullptr;
  HFONT name_font_ = nullptr;
  HFONT detail_font_ = nullptr;
  bool compact_ = false;
  UINT taskbar_created_message_ = 0;

  // Indexed by the command id a menu item was given, which is how a click
  // finds the row it came from.
  std::vector<Row> rows_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_TRAY_ICON_H_
