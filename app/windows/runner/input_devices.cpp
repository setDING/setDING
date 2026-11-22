#include "input_devices.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <hidsdi.h>

#include <cwchar>
#include <cwctype>
#include <optional>
#include <string>
#include <vector>

#include "utils.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// The device path of a Raw Input device, e.g.
// "\\?\HID#{00001124-…}_VID&0002046d_PID&b342&Col01#…".
std::wstring DevicePath(HANDLE device) {
  UINT size = 0;
  if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, nullptr, &size) != 0 ||
      size == 0) {
    return L"";
  }
  std::wstring path(size, L'\0');
  if (GetRawInputDeviceInfoW(device, RIDI_DEVICENAME, path.data(), &size) ==
      static_cast<UINT>(-1)) {
    return L"";
  }
  path.resize(wcslen(path.c_str()));
  return path;
}

// Only HID keyboards: not the RDP keyboard ("\\?\Root#RDP_KBD…") or a
// built-in one on the ACPI bus.
bool IsHid(const std::wstring& path) {
  if (path.size() < 8) return false;
  std::wstring start = path.substr(4, 4);
  for (auto& c : start) c = static_cast<wchar_t>(std::towupper(c));
  return start == L"HID#";
}

// The last four hex digits after "VID" / "PID" in [path] (USB "VID_046D",
// Bluetooth "VID&0002046d"); 0 when not found.
int IdFromPath(const std::wstring& path, const std::wstring& tag) {
  std::wstring upper = path;
  for (auto& c : upper) c = static_cast<wchar_t>(std::towupper(c));
  auto at = upper.find(tag);
  if (at == std::wstring::npos) return 0;
  at += tag.size() + 1;  // "VID_" or "VID&"
  std::wstring hex;
  while (at < upper.size() && std::iswxdigit(upper[at])) hex += upper[at++];
  if (hex.empty()) return 0;
  if (hex.size() > 4) hex = hex.substr(hex.size() - 4);
  return static_cast<int>(std::wcstol(hex.c_str(), nullptr, 16));
}

// Name, vendor and product of the keyboard [device]; nothing for one that
// is not a HID keyboard.
std::optional<EncodableMap> Describe(HANDLE device) {
  std::wstring path = DevicePath(device);
  if (!IsHid(path)) return std::nullopt;
  int vendor = IdFromPath(path, L"VID");
  int product = IdFromPath(path, L"PID");
  std::string name;
  // Access 0: enough for the attributes and strings of a device the system
  // keeps open, such as a keyboard.
  HANDLE file = CreateFileW(path.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE,
                            nullptr, OPEN_EXISTING, 0, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    HIDD_ATTRIBUTES attributes{};
    attributes.Size = sizeof(attributes);
    if (HidD_GetAttributes(file, &attributes)) {
      vendor = attributes.VendorID;
      product = attributes.ProductID;
    }
    wchar_t buffer[127] = {};
    if (HidD_GetProductString(file, buffer, sizeof(buffer))) {
      name = Utf8FromUtf16(buffer);
    }
    CloseHandle(file);
  }
  return EncodableMap{
      {EncodableValue("name"), EncodableValue(name)},
      {EncodableValue("vendorId"), EncodableValue(vendor)},
      {EncodableValue("productId"), EncodableValue(product)},
  };
}

EncodableList ConnectedKeyboards() {
  EncodableList result;
  UINT count = 0;
  if (GetRawInputDeviceList(nullptr, &count, sizeof(RAWINPUTDEVICELIST)) != 0 ||
      count == 0) {
    return result;
  }
  std::vector<RAWINPUTDEVICELIST> list(count);
  count = GetRawInputDeviceList(list.data(), &count, sizeof(RAWINPUTDEVICELIST));
  if (count == static_cast<UINT>(-1)) return result;
  for (UINT i = 0; i < count; i++) {
    if (list[i].dwType != RIM_TYPEKEYBOARD) continue;
    if (auto device = Describe(list[i].hDevice)) {
      result.push_back(EncodableValue(*device));
    }
  }
  return result;
}

}  // namespace

InputDevicesChannel::InputDevicesChannel(flutter::BinaryMessenger* messenger,
                                         HWND window)
    : window_(window) {
  const auto& codec = flutter::StandardMethodCodec::GetInstance();
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "app.setding/input_devices", &codec);
  methods_->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "devices") {
          result->Success(EncodableValue(ConnectedKeyboards()));
        } else {
          result->NotImplemented();
        }
      });
  events_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "app.setding/input_devices/events", &codec);
  events_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue*,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            sink_ = std::move(events);
            return nullptr;
          },
          [this](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            sink_ = nullptr;
            return nullptr;
          }));
  // Keyboards (usage page 1, usage 6), with connects and disconnects. No
  // RIDEV_NOLEGACY: WM_KEYDOWN still reaches Flutter.
  RAWINPUTDEVICE keyboards{0x01, 0x06, RIDEV_DEVNOTIFY, window_};
  RegisterRawInputDevices(&keyboards, 1, sizeof(keyboards));
}

InputDevicesChannel::~InputDevicesChannel() {
  RAWINPUTDEVICE keyboards{0x01, 0x06, RIDEV_REMOVE, nullptr};
  RegisterRawInputDevices(&keyboards, 1, sizeof(keyboards));
}

void InputDevicesChannel::Send(EncodableValue event) {
  if (sink_) sink_->Success(event);
}

void InputDevicesChannel::HandleMessage(UINT message, WPARAM wparam,
                                        LPARAM lparam) {
  if (!sink_) return;
  if (message == WM_INPUT_DEVICE_CHANGE) {
    Send(EncodableValue(
        EncodableMap{{EncodableValue("type"), EncodableValue("changed")}}));
    return;
  }
  if (message != WM_INPUT) return;
  RAWINPUT input{};
  UINT size = sizeof(input);
  if (GetRawInputData(reinterpret_cast<HRAWINPUT>(lparam), RID_INPUT, &input,
                      &size, sizeof(RAWINPUTHEADER)) == static_cast<UINT>(-1)) {
    return;
  }
  if (input.header.dwType != RIM_TYPEKEYBOARD) return;
  const RAWKEYBOARD& key = input.data.keyboard;
  if (key.Flags & RI_KEY_BREAK) return;  // Only key down.
  if (auto device = Describe(input.header.hDevice)) {
    Send(EncodableValue(EncodableMap{
        {EncodableValue("type"), EncodableValue("key")},
        {EncodableValue("device"), EncodableValue(*device)},
    }));
  }
}
