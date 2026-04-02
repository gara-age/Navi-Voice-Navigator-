#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <shlwapi.h>
#include <windowsx.h>

#include <filesystem>
#include <fstream>
#include <vector>

#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] =
    L"AppsUseLightTheme";
constexpr const wchar_t kTrayMenuOpenLabel[] = L"\xC5F4\xAE30";
constexpr const wchar_t kTrayMenuSettingsLabel[] =
    L"\xC124\xC815";
constexpr const wchar_t kTrayMenuExitLabel[] =
    L"\xC885\xB8CC\xD558\xAE30";
constexpr DWORD kBorderlessWindowStyle =
    WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU |
    WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
constexpr int kWindowBorderThickness = 1;
constexpr int kResizeBorderThickness = 8;
constexpr int kDragRegionHeight = 56;

static int g_active_window_count = 0;
constexpr UINT kTrayCallbackMessage = WM_APP + 1;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

std::filesystem::path FindRuntimeDirectory() {
  std::filesystem::path candidates[2];
  wchar_t module_path[MAX_PATH];
  if (GetModuleFileNameW(nullptr, module_path, MAX_PATH) > 0) {
    candidates[0] = std::filesystem::path(module_path).parent_path();
  }
  wchar_t current_path[MAX_PATH];
  if (GetCurrentDirectoryW(MAX_PATH, current_path) > 0) {
    candidates[1] = std::filesystem::path(current_path);
  }

  for (const auto& start : candidates) {
    if (start.empty()) {
      continue;
    }

    auto current = start;
    for (int i = 0; i < 8; ++i) {
      const auto runtime_dir = current / "runtime";
      if (std::filesystem::exists(runtime_dir) &&
          std::filesystem::is_directory(runtime_dir)) {
        return runtime_dir;
      }

      if (!current.has_parent_path() || current.parent_path() == current) {
        break;
      }
      current = current.parent_path();
    }
  }

  return {};
}

void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

UINT ResolveTrayEventCode(LPARAM lparam) {
  const UINT raw_code = static_cast<UINT>(lparam);
  const UINT low_code = LOWORD(lparam);
  switch (low_code) {
    case WM_LBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
    case NIN_SELECT:
    case NIN_KEYSELECT:
      return low_code;
  }

  switch (raw_code) {
    case WM_LBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
    case NIN_SELECT:
    case NIN_KEYSELECT:
      return raw_code;
  }

  const UINT high_code = HIWORD(lparam);
  switch (high_code) {
    case WM_LBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
    case NIN_SELECT:
    case NIN_KEYSELECT:
      return high_code;
  }

  return raw_code;
}

}  // namespace

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  const wchar_t* GetWindowClass();
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;
  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground =
        CreateSolidBrush(RGB(214, 223, 240));
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), kBorderlessWindowStyle,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  UpdateFrame(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT Win32Window::MessageHandler(HWND hwnd,
                                    UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      if (!force_quit_) {
        MinimizeToTray();
        return 0;
      }
      break;

    case WM_DESTROY:
      RemoveTrayIcon();
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto new_rect_size = reinterpret_cast<RECT*>(lparam);
      LONG new_width = new_rect_size->right - new_rect_size->left;
      LONG new_height = new_rect_size->bottom - new_rect_size->top;

      SetWindowPos(hwnd, nullptr, new_rect_size->left, new_rect_size->top,
                   new_width, new_height, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_NCCALCSIZE:
      if (wparam == TRUE) {
        return 0;
      }
      break;

    case WM_NCHITTEST: {
      POINT cursor = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      const LRESULT hit = HitTestNCA(cursor);
      if (hit != HTCLIENT) {
        return hit;
      }
      break;
    }

    case WM_SIZE: {
      RECT rect = GetInsetsAwareClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;

    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case ID_TRAY_SHOW:
          RestoreFromTray();
          return 0;
        case ID_TRAY_SETTINGS:
          RestoreFromTray();
          DispatchLocalEvent(L"OPEN_SETTINGS");
          return 0;
        case ID_TRAY_EXIT:
          force_quit_ = true;
          RemoveTrayIcon();
          DestroyWindow(hwnd);
          return 0;
      }
      break;

    case kTrayCallbackMessage:
      switch (ResolveTrayEventCode(lparam)) {
        case WM_LBUTTONDBLCLK:
          RestoreFromTray();
          return 0;
        case WM_RBUTTONUP:
        case WM_RBUTTONDOWN:
        case WM_CONTEXTMENU:
          ShowTrayContextMenu();
          return 0;
      }
      break;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetInsetsAwareClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, TRUE);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

void Win32Window::UpdateFrame(HWND const window) {
  const MARGINS margins = {1, 1, 1, 1};
  DwmExtendFrameIntoClientArea(window, &margins);

  const DWORD corner_preference = DWMWCP_ROUND;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));
}

RECT Win32Window::GetInsetsAwareClientArea() {
  RECT frame = GetClientArea();
  const bool maximized = IsZoomed(window_handle_);
  const int inset = maximized ? 0 : kWindowBorderThickness;
  frame.left += inset;
  frame.top += inset;
  frame.right -= inset;
  frame.bottom -= inset;
  return frame;
}

LRESULT Win32Window::HitTestNCA(POINT cursor) noexcept {
  if (!window_handle_) {
    return HTNOWHERE;
  }

  RECT window_rect;
  GetWindowRect(window_handle_, &window_rect);

  const LONG x = cursor.x - window_rect.left;
  const LONG y = cursor.y - window_rect.top;
  const LONG width = window_rect.right - window_rect.left;
  const LONG height = window_rect.bottom - window_rect.top;

  const bool can_resize = !IsZoomed(window_handle_);
  if (can_resize) {
    const bool left = x >= 0 && x < kResizeBorderThickness;
    const bool right = x <= width && x >= width - kResizeBorderThickness;
    const bool top = y >= 0 && y < kResizeBorderThickness;
    const bool bottom = y <= height && y >= height - kResizeBorderThickness;

    if (top && left) {
      return HTTOPLEFT;
    }
    if (top && right) {
      return HTTOPRIGHT;
    }
    if (bottom && left) {
      return HTBOTTOMLEFT;
    }
    if (bottom && right) {
      return HTBOTTOMRIGHT;
    }
    if (left) {
      return HTLEFT;
    }
    if (right) {
      return HTRIGHT;
    }
    if (top) {
      return HTTOP;
    }
    if (bottom) {
      return HTBOTTOM;
    }
  }

  if (y >= 0 && y < kDragRegionHeight) {
    return HTCAPTION;
  }

  return HTCLIENT;
}

void Win32Window::MinimizeToTray() {
  if (!window_handle_) {
    return;
  }

  CreateTrayIcon();
  ShowWindow(window_handle_, SW_HIDE);
}

void Win32Window::RestoreFromTray() {
  if (!window_handle_) {
    return;
  }

  RemoveTrayIcon();
  ShowWindow(window_handle_, SW_RESTORE);
  ShowWindow(window_handle_, SW_SHOW);
  SetForegroundWindow(window_handle_);
}

bool Win32Window::CreateTrayIcon() {
  if (!window_handle_) {
    return false;
  }

  if (tray_icon_visible_) {
    return true;
  }

  notify_icon_data_ = {};
  notify_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
  notify_icon_data_.hWnd = window_handle_;
  notify_icon_data_.uID = ID_TRAY_APP_ICON;
  notify_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  notify_icon_data_.uCallbackMessage = kTrayCallbackMessage;
  notify_icon_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(notify_icon_data_.szTip, L"Navi: Voice Navigator");

  tray_icon_visible_ = Shell_NotifyIcon(NIM_ADD, &notify_icon_data_);
  if (tray_icon_visible_) {
    notify_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &notify_icon_data_);
  }
  return tray_icon_visible_;
}

void Win32Window::RemoveTrayIcon() {
  if (!tray_icon_visible_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &notify_icon_data_);
  tray_icon_visible_ = false;
}

void Win32Window::ShowTrayContextMenu() {
  if (!window_handle_) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  AppendMenu(menu, MF_STRING, ID_TRAY_SHOW, kTrayMenuOpenLabel);
  AppendMenu(menu, MF_STRING, ID_TRAY_SETTINGS, kTrayMenuSettingsLabel);
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, ID_TRAY_EXIT, kTrayMenuExitLabel);

  POINT cursor_pos;
  GetCursorPos(&cursor_pos);
  SetForegroundWindow(window_handle_);
  UINT selected = TrackPopupMenu(
      menu,
      TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD,
      cursor_pos.x,
      cursor_pos.y,
      0,
      window_handle_,
      nullptr);
  PostMessage(window_handle_, WM_NULL, 0, 0);
  DestroyMenu(menu);

  switch (selected) {
    case ID_TRAY_SHOW:
      RestoreFromTray();
      break;
    case ID_TRAY_SETTINGS:
      RestoreFromTray();
      DispatchLocalEvent(L"OPEN_SETTINGS");
      break;
    case ID_TRAY_EXIT:
      force_quit_ = true;
      RemoveTrayIcon();
      DestroyWindow(window_handle_);
      break;
  }
}

void Win32Window::DispatchLocalEvent(const wchar_t* event_name) {
  const auto runtime_dir = FindRuntimeDirectory();
  if (runtime_dir.empty()) {
    return;
  }

  const auto event_file = runtime_dir / "background_event.json";
  std::ofstream output(event_file, std::ios::trunc);
  if (!output.is_open()) {
    return;
  }

  std::wstring event_value = event_name == nullptr ? L"" : event_name;
  std::string utf8_event;
  if (!event_value.empty()) {
    const int required = WideCharToMultiByte(
        CP_UTF8, 0, event_value.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (required > 1) {
      std::vector<char> utf8_buffer(required, '\0');
      const int written = WideCharToMultiByte(
          CP_UTF8,
          0,
          event_value.c_str(),
          -1,
          utf8_buffer.data(),
          required,
          nullptr,
          nullptr);
      if (written > 1) {
        utf8_event.assign(utf8_buffer.data(), written - 1);
      }
    }
  }

  output << "{\"event\":\"" << utf8_event << "\"}";
}
