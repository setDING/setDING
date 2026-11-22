#ifndef RUNNER_INPUT_DEVICES_H_
#define RUNNER_INPUT_DEVICES_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// The keyboards of the device for pairing the page turner (ADR-0057):
// the connected HID keyboards ("devices"), and on the event channel the
// device of every key pressed down ("key") and connects and disconnects
// ("changed"), through Raw Input. It only observes: the keys still reach
// Flutter as WM_KEYDOWN.
class InputDevicesChannel {
 public:
  InputDevicesChannel(flutter::BinaryMessenger* messenger, HWND window);
  ~InputDevicesChannel();

  // Handles WM_INPUT and WM_INPUT_DEVICE_CHANGE of the top-level window;
  // the caller passes every message on to the default handling.
  void HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  void Send(flutter::EncodableValue event);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
};

#endif  // RUNNER_INPUT_DEVICES_H_
