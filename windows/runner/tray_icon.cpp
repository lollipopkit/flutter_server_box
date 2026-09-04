#include "tray_icon.h"

#include "resource.h"

#include <shellapi.h>
#include <vssym32.h>
#include <windowsx.h>

#include <algorithm>
#include <cstring>
#include <string>

namespace {

// Command ids for the menu. The rows take everything from kFirstRow upwards,
// so a click carries which server it was without a lookup table.
constexpr UINT kCmdOpen = 1;
constexpr UINT kCmdSettings = 2;
constexpr UINT kCmdQuit = 3;
constexpr UINT kFirstRow = 100;

constexpr int kLeading = 24;
constexpr int kTrailing = 12;
constexpr int kChartWidth = 60;
constexpr int kChartHeight = 18;
constexpr int kPadding = 5;
constexpr int kLineGap = 1;
constexpr int kMinRowWidth = 240;
constexpr int kMaxRowWidth = 420;

template <typename T>
T LoadUser32Function(const char* name) {
  const HMODULE user32 = GetModuleHandleW(L"user32.dll");
  if (user32 == nullptr) return nullptr;
  const FARPROC address = GetProcAddress(user32, name);
  T function = nullptr;
  static_assert(sizeof(function) == sizeof(address));
  std::memcpy(&function, &address, sizeof(function));
  return function;
}

UINT DpiForWindowCompat(HWND window) {
  using GetDpiForWindowFn = UINT(WINAPI*)(HWND);
  static const GetDpiForWindowFn get_dpi_for_window =
      LoadUser32Function<GetDpiForWindowFn>("GetDpiForWindow");
  if (get_dpi_for_window != nullptr && window != nullptr) {
    const UINT dpi = get_dpi_for_window(window);
    if (dpi != 0) return dpi;
  }

  HDC dc = GetDC(window);
  if (dc == nullptr) return USER_DEFAULT_SCREEN_DPI;
  const int dpi = GetDeviceCaps(dc, LOGPIXELSX);
  ReleaseDC(window, dc);
  return dpi > 0 ? static_cast<UINT>(dpi) : USER_DEFAULT_SCREEN_DPI;
}

UINT TrayDpi(HWND owner) {
  const HWND taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
  return DpiForWindowCompat(taskbar != nullptr ? taskbar : owner);
}

int SystemMetricForDpiCompat(int metric, UINT dpi) {
  using GetSystemMetricsForDpiFn = int(WINAPI*)(int, UINT);
  static const GetSystemMetricsForDpiFn get_system_metrics_for_dpi =
      LoadUser32Function<GetSystemMetricsForDpiFn>("GetSystemMetricsForDpi");
  if (get_system_metrics_for_dpi != nullptr) {
    return get_system_metrics_for_dpi(metric, dpi);
  }
  return GetSystemMetrics(metric);
}

bool ReadMenuMetrics(UINT dpi, NONCLIENTMETRICSW* metrics) {
  metrics->cbSize = sizeof(*metrics);
  using SystemParametersInfoForDpiFn = BOOL(WINAPI*)(UINT, UINT, PVOID, UINT,
                                                     UINT);
  static const SystemParametersInfoForDpiFn system_parameters_info_for_dpi =
      LoadUser32Function<SystemParametersInfoForDpiFn>(
          "SystemParametersInfoForDpi");
  if (system_parameters_info_for_dpi != nullptr) {
    return system_parameters_info_for_dpi(
               SPI_GETNONCLIENTMETRICS, sizeof(*metrics), metrics, 0, dpi) !=
           FALSE;
  }
  return SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(*metrics),
                               metrics, 0) != FALSE;
}

HICON LoadTrayIcon(UINT dpi) {
  const HINSTANCE instance = GetModuleHandleW(nullptr);
  if (instance == nullptr) return nullptr;
  return static_cast<HICON>(LoadImageW(
      instance, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      SystemMetricForDpiCompat(SM_CXSMICON, dpi),
      SystemMetricForDpiCompat(SM_CYSMICON, dpi), LR_DEFAULTCOLOR));
}

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                 static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), size);
  return out;
}

const flutter::EncodableValue* Find(const flutter::EncodableMap& map,
                                    const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

std::string GetString(const flutter::EncodableMap& map, const char* key) {
  const auto* value = Find(map, key);
  if (value == nullptr) return std::string();
  const auto* str = std::get_if<std::string>(value);
  return str == nullptr ? std::string() : *str;
}

bool GetBool(const flutter::EncodableMap& map, const char* key) {
  const auto* value = Find(map, key);
  if (value == nullptr) return false;
  const auto* flag = std::get_if<bool>(value);
  return flag != nullptr && *flag;
}

// The colour of the dot. Only what is not ordinary gets a colour: a menu where
// every row is coloured is one where the colour has stopped meaning anything.
COLORREF DotColour(const std::wstring& state) {
  if (state == L"ok") return RGB(0x35, 0xA8, 0x53);
  if (state == L"working") return RGB(0xE3, 0x8C, 0x22);
  if (state == L"failed") return RGB(0xD9, 0x3A, 0x3A);
  return RGB(0x9A, 0x9A, 0x9A);
}

}  // namespace

TrayIcon::TrayIcon(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window) {
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "tech.lolli.toolbox/tray",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "update") {
          const auto* payload =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (payload != nullptr) Update(*payload);
          result->Success();
        } else if (call.method_name() == "destroy") {
          Destroy();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  RefreshVisualResources();
}

TrayIcon::~TrayIcon() {
  Destroy();
  if (menu_theme_ != nullptr) CloseThemeData(menu_theme_);
  if (name_font_ != nullptr) DeleteObject(name_font_);
  if (detail_font_ != nullptr) DeleteObject(detail_font_);
}

int TrayIcon::Scale(int value) const {
  return std::max(1, MulDiv(value, static_cast<int>(dpi_),
                            USER_DEFAULT_SCREEN_DPI));
}

HFONT TrayIcon::NameFont() const {
  return name_font_ != nullptr
             ? name_font_
             : static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
}

HFONT TrayIcon::DetailFont() const {
  return detail_font_ != nullptr ? detail_font_ : NameFont();
}

void TrayIcon::RefreshVisualResources() {
  dpi_ = TrayDpi(window_);

  if (menu_theme_ != nullptr) CloseThemeData(menu_theme_);
  menu_theme_ = OpenThemeData(window_, L"Menu");

  // The menu's own font, at the notification area's DPI. An owner-drawn row
  // that picked a private font would be the one row ignoring system settings.
  NONCLIENTMETRICSW metrics = {};
  if (ReadMenuMetrics(dpi_, &metrics)) {
    HFONT next_name = CreateFontIndirectW(&metrics.lfMenuFont);
    LOGFONTW small_font = metrics.lfMenuFont;
    // 85% of the menu font, floored so it does not vanish on a small setting.
    small_font.lfHeight = std::min(
        -static_cast<LONG>(Scale(11)), small_font.lfHeight * 85 / 100);
    HFONT next_detail = CreateFontIndirectW(&small_font);
    if (next_name != nullptr && next_detail != nullptr) {
      if (name_font_ != nullptr) DeleteObject(name_font_);
      if (detail_font_ != nullptr) DeleteObject(detail_font_);
      name_font_ = next_name;
      detail_font_ = next_detail;
    } else {
      if (next_name != nullptr) DeleteObject(next_name);
      if (next_detail != nullptr) DeleteObject(next_detail);
    }
  }

  HICON next_icon = LoadTrayIcon(dpi_);
  if (next_icon == nullptr) return;
  if (icon_added_) {
    NOTIFYICONDATAW update = icon_data_;
    update.uFlags = NIF_ICON;
    update.hIcon = next_icon;
    if (!Shell_NotifyIconW(NIM_MODIFY, &update)) {
      DestroyIcon(next_icon);
      return;
    }
  }
  if (icon_ != nullptr) DestroyIcon(icon_);
  icon_ = next_icon;
  icon_data_.hIcon = icon_;
}

bool TrayIcon::AddIcon() {
  if (icon_added_) return true;

  if (icon_ == nullptr) {
    icon_ = LoadTrayIcon(dpi_);
    if (icon_ == nullptr) return false;
  }

  icon_data_ = {};
  icon_data_.cbSize = sizeof(icon_data_);
  icon_data_.hWnd = window_;
  icon_data_.uID = 1;
  icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  icon_data_.uCallbackMessage = kCallbackMessage;
  icon_data_.hIcon = icon_;
  wcscpy_s(icon_data_.szTip, L"ServerBox");
  if (!Shell_NotifyIconW(NIM_ADD, &icon_data_)) return false;

  icon_added_ = true;
  icon_data_.uVersion = NOTIFYICON_VERSION_4;
  modern_notifications_ =
      Shell_NotifyIconW(NIM_SETVERSION, &icon_data_) != FALSE;
  return true;
}

bool TrayIcon::OwnsRowItem(UINT id, ULONG_PTR data) const {
  if (menu_ == nullptr || id < kFirstRow) return false;
  const size_t index = static_cast<size_t>(data);
  if (index >= rows_.size() || id != kFirstRow + index) return false;

  MENUITEMINFOW info = {};
  info.cbSize = sizeof(info);
  info.fMask = MIIM_DATA | MIIM_FTYPE;
  if (!GetMenuItemInfoW(menu_, id, FALSE, &info)) return false;
  return (info.fType & MFT_OWNERDRAW) != 0 && info.dwItemData == data;
}

void TrayIcon::Destroy() {
  pending_payload_.reset();
  refresh_visuals_pending_ = false;
  if (menu_open_) EndMenu();
  menu_open_ = false;
  if (icon_added_) {
    Shell_NotifyIconW(NIM_DELETE, &icon_data_);
    icon_added_ = false;
  }
  modern_notifications_ = false;
  if (icon_ != nullptr) {
    DestroyIcon(icon_);
    icon_ = nullptr;
  }
  if (menu_ != nullptr) {
    DestroyMenu(menu_);
    menu_ = nullptr;
  }
}

void TrayIcon::Update(const flutter::EncodableMap& payload) {
  if (menu_open_) {
    // TrackPopupMenu runs a nested message loop, so status channel calls can
    // arrive while this menu is still being used. Keep its rows and itemData
    // stable until it closes, and retain only the freshest pending model.
    pending_payload_ = payload;
    return;
  }

  const auto* config_value = Find(payload, "config");
  const auto* config = config_value == nullptr
                           ? nullptr
                           : std::get_if<flutter::EncodableMap>(config_value);
  compact_ = config != nullptr && GetBool(*config, "compact");

  rows_.clear();
  const auto* lines_value = Find(payload, "lines");
  const auto* lines =
      lines_value == nullptr ? nullptr : std::get_if<flutter::EncodableList>(lines_value);
  if (lines != nullptr) {
    for (const auto& entry : *lines) {
      const auto* line = std::get_if<flutter::EncodableMap>(&entry);
      if (line == nullptr) continue;
      Row row;
      row.id = GetString(*line, "id");
      row.name = Widen(GetString(*line, "name"));
      row.state = Widen(GetString(*line, "state"));
      row.label = Widen(GetString(*line, "label"));
      if (const auto* readings_value = Find(*line, "readings")) {
        if (const auto* readings =
                std::get_if<flutter::EncodableList>(readings_value)) {
          for (const auto& item : *readings) {
            const auto* reading = std::get_if<flutter::EncodableMap>(&item);
            if (reading == nullptr) continue;
            row.readings.push_back({Widen(GetString(*reading, "label")),
                                    Widen(GetString(*reading, "value"))});
          }
        }
      }
      if (const auto* chart_value = Find(*line, "chart")) {
        if (const auto* chart =
                std::get_if<flutter::EncodableList>(chart_value)) {
          for (const auto& sample : *chart) {
            if (const auto* value = std::get_if<double>(&sample)) {
              row.chart.push_back(*value);
            }
          }
        }
      }
      rows_.push_back(std::move(row));
    }
  }

  AddIcon();

  // Rebuilt whole, because that is what a menu is: there is no API for editing
  // one item, and the Dart side already withholds a push that changes nothing.
  if (menu_ != nullptr) DestroyMenu(menu_);
  menu_ = CreatePopupMenu();

  AppendMenu(menu_, MF_STRING, kCmdOpen, L"Open ServerBox");
  AppendMenu(menu_, MF_SEPARATOR, 0, nullptr);

  AppendMenu(menu_, MF_STRING | MF_GRAYED | MF_DISABLED, 0, L"Servers");
  if (rows_.empty()) {
    AppendMenu(menu_, MF_STRING | MF_GRAYED | MF_DISABLED, 0, L"Empty");
  } else {
    for (size_t i = 0; i < rows_.size(); i++) {
      const UINT id = kFirstRow + static_cast<UINT>(i);
      if (compact_) {
        AppendMenu(menu_, MF_STRING, id, rows_[i].label.c_str());
      } else {
        // The index and not a pointer: `rows_` is replaced on every update,
        // and a menu outliving one would be holding freed rows.
        AppendMenu(menu_, MF_OWNERDRAW, id,
                   reinterpret_cast<LPCWSTR>(static_cast<UINT_PTR>(i)));
      }
    }
  }

  AppendMenu(menu_, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu_, MF_STRING, kCmdSettings, L"Settings");
  AppendMenu(menu_, MF_STRING, kCmdQuit, L"Quit");
}

void TrayIcon::ShowMenu() {
  if (menu_ == nullptr) return;
  POINT cursor;
  GetCursorPos(&cursor);
  // Documented dance: the window has to be foreground or the menu never gets
  // a mouse-up and stays on screen after the pointer leaves it.
  SetForegroundWindow(window_);
  menu_open_ = true;
  const UINT command = TrackPopupMenu(
      menu_, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, cursor.x,
      cursor.y, 0, window_, nullptr);
  menu_open_ = false;
  PostMessage(window_, WM_NULL, 0, 0);
  if (command != 0) OnCommand(command);

  if (refresh_visuals_pending_) {
    refresh_visuals_pending_ = false;
    RefreshVisualResources();
  }
  auto pending = std::move(pending_payload_);
  pending_payload_.reset();
  if (pending.has_value()) Update(*pending);
}

void TrayIcon::Measure(MEASUREITEMSTRUCT* measure) {
  const size_t index = static_cast<size_t>(measure->itemData);
  if (index >= rows_.size()) return;
  const Row& row = rows_[index];

  HDC dc = GetDC(window_);
  if (dc == nullptr) {
    measure->itemHeight = Scale(28);
    measure->itemWidth = Scale(kMinRowWidth);
    return;
  }
  HGDIOBJ previous = SelectObject(dc, NameFont());
  TEXTMETRIC name_metrics = {};
  GetTextMetrics(dc, &name_metrics);
  SIZE name_size = {};
  GetTextExtentPoint32(dc, row.name.c_str(),
                       static_cast<int>(row.name.size()), &name_size);

  int detail_height = 0;
  int detail_width = 0;
  if (!row.readings.empty()) {
    SelectObject(dc, DetailFont());
    TEXTMETRIC detail_metrics = {};
    GetTextMetrics(dc, &detail_metrics);
    detail_height = detail_metrics.tmHeight;
    std::wstring detail;
    for (const auto& reading : row.readings) {
      if (!detail.empty()) detail += L"   ";
      detail += reading.label + L" " + reading.value;
    }
    SIZE detail_size = {};
    GetTextExtentPoint32(dc, detail.c_str(), static_cast<int>(detail.size()),
                         &detail_size);
    detail_width = detail_size.cx;
  }
  SelectObject(dc, previous);
  ReleaseDC(window_, dc);

  measure->itemHeight = Scale(kPadding) * 2 + name_metrics.tmHeight +
                        (detail_height > 0 ? Scale(kLineGap) + detail_height
                                           : 0);
  const int text = std::max<int>(name_size.cx, detail_width);
  const int desired_width =
      Scale(kLeading) + text + Scale(kTrailing) +
      (row.chart.empty() ? 0 : Scale(kChartWidth + 8));
  measure->itemWidth = std::clamp(
      desired_width, Scale(kMinRowWidth), Scale(kMaxRowWidth));
}

void TrayIcon::Draw(DRAWITEMSTRUCT* draw) {
  const size_t index = static_cast<size_t>(draw->itemData);
  if (index >= rows_.size()) return;
  const Row& row = rows_[index];

  const bool selected = (draw->itemState & ODS_SELECTED) != 0;
  HDC dc = draw->hDC;
  RECT rect = draw->rcItem;

  const int theme_state = selected ? MPI_HOT : MPI_NORMAL;
  const bool themed =
      menu_theme_ != nullptr &&
      SUCCEEDED(DrawThemeBackground(menu_theme_, dc, MENU_POPUPITEM,
                                    theme_state, &rect, nullptr));
  if (!themed) {
    FillRect(dc, &rect,
             GetSysColorBrush(selected ? COLOR_HIGHLIGHT : COLOR_MENU));
  }

  COLORREF text_colour =
      GetSysColor(selected ? COLOR_HIGHLIGHTTEXT : COLOR_MENUTEXT);
  if (menu_theme_ != nullptr) {
    COLORREF themed_text = 0;
    if (SUCCEEDED(GetThemeColor(menu_theme_, MENU_POPUPITEM, theme_state,
                                TMT_TEXTCOLOR, &themed_text))) {
      text_colour = themed_text;
    }
  }
  SetBkMode(dc, TRANSPARENT);

  HGDIOBJ previous_font = SelectObject(dc, NameFont());
  TEXTMETRIC name_metrics = {};
  GetTextMetrics(dc, &name_metrics);

  int detail_height = 0;
  std::wstring detail;
  if (!row.readings.empty()) {
    for (const auto& reading : row.readings) {
      if (!detail.empty()) detail += L"   ";
      detail += reading.label + L" " + reading.value;
    }
    SelectObject(dc, DetailFont());
    TEXTMETRIC detail_metrics = {};
    GetTextMetrics(dc, &detail_metrics);
    detail_height = detail_metrics.tmHeight;
    SelectObject(dc, NameFont());
  }

  const int text_left = rect.left + Scale(kLeading);
  const int chart_width = Scale(kChartWidth);
  const int chart_left = rect.right - Scale(kTrailing) - chart_width;
  const int text_right = row.chart.empty()
                             ? rect.right - Scale(kTrailing)
                             : chart_left - Scale(8);
  const int name_y = rect.top + Scale(kPadding);
  RECT name_rect = {text_left, name_y, text_right,
                    name_y + name_metrics.tmHeight};
  SetTextColor(dc, text_colour);
  DrawTextW(dc, row.name.c_str(), static_cast<int>(row.name.size()),
            &name_rect,
            DT_END_ELLIPSIS | DT_LEFT | DT_NOPREFIX | DT_SINGLELINE | DT_TOP);

  if (!detail.empty()) {
    SelectObject(dc, DetailFont());
    COLORREF detail_colour =
        selected ? text_colour : GetSysColor(COLOR_GRAYTEXT);
    if (!selected && menu_theme_ != nullptr) {
      COLORREF themed_detail = 0;
      if (SUCCEEDED(GetThemeColor(menu_theme_, MENU_POPUPITEM, MPI_DISABLED,
                                  TMT_TEXTCOLOR, &themed_detail))) {
        detail_colour = themed_detail;
      }
    }
    SetTextColor(dc, detail_colour);
    const int detail_y =
        name_y + name_metrics.tmHeight + Scale(kLineGap);
    RECT detail_rect = {text_left, detail_y, text_right,
                        detail_y + detail_height};
    DrawTextW(dc, detail.c_str(), static_cast<int>(detail.size()),
              &detail_rect,
              DT_END_ELLIPSIS | DT_LEFT | DT_NOPREFIX | DT_SINGLELINE |
                  DT_TOP);
  }

  // A font glyph remains round under RDP and fractional DPI scaling, where a
  // seven-pixel GDI ellipse is reduced to a visible diamond.
  SelectObject(dc, NameFont());
  SetTextColor(dc, selected ? text_colour : DotColour(row.state));
  RECT dot_rect = {rect.left + Scale(4), name_y,
                   rect.left + Scale(kLeading - 3),
                   name_y + name_metrics.tmHeight};
  DrawTextW(dc, L"●", 1, &dot_rect,
            DT_CENTER | DT_NOPREFIX | DT_SINGLELINE | DT_VCENTER);
  SelectObject(dc, previous_font);

  if (row.chart.size() < 2) return;

  const int chart_height = Scale(kChartHeight);
  const int chart_top =
      rect.top + (rect.bottom - rect.top - chart_height) / 2;
  std::vector<POINT> points;
  points.reserve(row.chart.size());
  for (size_t i = 0; i < row.chart.size(); i++) {
    const double value = std::clamp(row.chart[i], 0.0, 1.0);
    points.push_back(
        {chart_left +
             static_cast<int>(chart_width * i / (row.chart.size() - 1)),
         chart_top + chart_height - static_cast<int>(chart_height * value)});
  }
  HPEN pen = CreatePen(PS_SOLID, Scale(1),
                       selected ? text_colour : GetSysColor(COLOR_HOTLIGHT));
  HGDIOBJ previous_chart_pen = SelectObject(dc, pen);
  Polyline(dc, points.data(), static_cast<int>(points.size()));
  SelectObject(dc, previous_chart_pen);
  DeleteObject(pen);
}

bool TrayIcon::OnCommand(UINT id) {
  if (channel_ == nullptr) return false;
  switch (id) {
    case kCmdOpen:
      channel_->InvokeMethod("open", nullptr);
      return true;
    case kCmdSettings:
      channel_->InvokeMethod("settings", nullptr);
      return true;
    case kCmdQuit:
      channel_->InvokeMethod("quit", nullptr);
      return true;
    default:
      break;
  }
  if (id < kFirstRow) return false;
  const size_t index = id - kFirstRow;
  if (index >= rows_.size()) return false;
  channel_->InvokeMethod(
      "server",
      std::make_unique<flutter::EncodableValue>(rows_[index].id));
  return true;
}

bool TrayIcon::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam,
                             LRESULT* result) {
  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    // Explorer owns the notification area. When it restarts every registered
    // icon is lost, while this process still believes its previous add exists.
    const bool should_restore = icon_added_ || menu_ != nullptr;
    icon_added_ = false;
    modern_notifications_ = false;
    if (should_restore) {
      RefreshVisualResources();
      AddIcon();
    }
    *result = 0;
    return true;
  }

  if (message == WM_DPICHANGED || message == WM_FONTCHANGE ||
      message == WM_SETTINGCHANGE || message == WM_DISPLAYCHANGE ||
      message == WM_THEMECHANGED || message == WM_SYSCOLORCHANGE) {
    if (menu_open_) {
      refresh_visuals_pending_ = true;
    } else {
      RefreshVisualResources();
    }
    // Flutter and its plugins also need these system notifications.
    return false;
  }

  switch (message) {
    case kCallbackMessage: {
      const bool ours = modern_notifications_
                            ? HIWORD(lparam) == icon_data_.uID
                            : wparam == icon_data_.uID;
      if (!ours) return false;
      const UINT event = modern_notifications_ ? LOWORD(lparam)
                                               : static_cast<UINT>(lparam);
      // Either button opens the menu. A left click on Windows usually shows
      // the window instead — but this icon exists to be read, and what there
      // is to read is in the menu.
      if (event == WM_LBUTTONUP || event == WM_RBUTTONUP ||
          event == WM_CONTEXTMENU || event == NIN_SELECT ||
          event == NIN_KEYSELECT) {
        ShowMenu();
      }
      *result = 0;
      return true;
    }
    case WM_MEASUREITEM: {
      auto* measure = reinterpret_cast<MEASUREITEMSTRUCT*>(lparam);
      if (measure == nullptr || measure->CtlType != ODT_MENU ||
          !OwnsRowItem(measure->itemID, measure->itemData)) {
        return false;
      }
      Measure(measure);
      *result = TRUE;
      return true;
    }
    case WM_DRAWITEM: {
      auto* draw = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
      if (draw == nullptr || draw->CtlType != ODT_MENU ||
          !OwnsRowItem(draw->itemID, draw->itemData)) {
        return false;
      }
      Draw(draw);
      *result = TRUE;
      return true;
    }
    default:
      return false;
  }
}
