# ADR-0057: Pairing the page turner and detecting its connection

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

A Bluetooth page turner (foot pedal) is a keyboard: it sends arrow keys, Page
Up/Down or Space, which live mode turns pages with (ADR-0007). The overview's
readiness card (ADR-0045, #911) can only say when a page-turn key last arrived
and offer a quick test. Before a gig the musician wants to know whether **their
pedal** is connected right now (#913).

Flutter's key events do not say which device a key came from, and Flutter has
no API to list input devices. What the platforms offer differs:

- **Android:** `InputManager` lists the input devices with name, vendor and
  product ID and whether they are external, and reports when one is added or
  removed. Every `KeyEvent` names its device.
- **Windows:** Raw Input names the device of every key (`WM_INPUT`) and lists
  the keyboards (`GetRawInputDeviceList`); `WM_INPUT_DEVICE_CHANGE` reports
  added and removed ones. The device path carries vendor and product ID; the
  HID product string gives the name.
- **iOS / iPadOS:** `GCKeyboard` (GameController) tells only whether **a**
  hardware keyboard is connected; all keyboards are merged into one, without a
  name.
- **Web, Linux and macOS:** no such information in the app (Linux is a
  development platform only).

## Decision

1. **Pairing by a key press**, in *Settings › Live › Page turner*: the app asks
   "Press the pedal now" and remembers the device the next key came from: its
   **name, vendor ID and product ID**. No list of device names to choose from:
   many page turners report generic names ("BT Keyboard") or show up as two
   devices. *Pair again* and *Forget* replace or remove it.
2. The pairing is a **device setting** in the shared preferences
   (`pageTurnerName`, `pageTurnerVendor`, `pageTurnerProduct`), never synced:
   another tablet has another pedal (like the automatic backup, ADR-0054).
3. **Matching:** a connected device is the paired one when vendor and
   product ID are equal; the name is not compared then, because some page
   turners put their firmware version into it (an AirTurn DUO500 reports
   `DUO500 v3.0.13 6887`). When either side has no IDs (0), the name alone.
   Two identical page turners on one device cannot be told apart.
4. **One platform channel** `app.setding/input_devices` per platform, behind
   the Dart interface `InputDevices` (`app/lib/platform/input_devices.dart`):
   - method `devices`: the connected external keyboards (`name`, `vendorId`,
     `productId`);
   - event channel `app.setding/input_devices/events`: `{"type": "key", …}`
     with the device of every key pressed down and `{"type": "changed"}` when a
     keyboard was connected or disconnected.

   The native side only observes: keys still reach Flutter unchanged.
   Virtual and built-in devices (on-screen keyboard, volume keys) are left out
   where the platform can tell (`InputDevice.isVirtual`, `isExternal` on
   Android 10+).
5. **Support per platform** (`InputDeviceSupport`): `devices` on Android and
   Windows (pairing and connection), `keyboardOnly` on iOS (only "a keyboard is
   connected", no pairing), `none` elsewhere. Where pairing is not possible,
   the setting says why, and the readiness card keeps the last use and the
   quick test of #911.
6. **Readiness card:** with a paired page turner, the page turner line is
   *"Page turner <name> connected"* or a warning *"… not connected"*, leading
   to *Settings › Live*. On iOS a missing keyboard is a warning only when a
   page turner was used on the device before.
7. Tests use a fake `InputDevices`; the native code is checked by hand with a
   real page turner.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Pairing by a key press (chosen) | Always the right device; no cryptic names to choose from | Needs native key observation |
| A list of connected devices to choose from | No key observation needed | Generic or duplicate names; the user cannot tell which one is the pedal |
| CoreBluetooth / Android Bluetooth APIs | Bluetooth names and state | HID devices are hidden from apps on iOS; Bluetooth permissions; misses USB pedals |
| A plugin from pub.dev | No own native code | None covers Android, Windows and iOS input devices with device-per-key; an extra dependency |
| Only last use and quick test (#911) | No native code | Cannot tell whether the pedal is connected now |

## Consequences

- Native code in three runners (Kotlin, C++, Swift) that `make check` does not
  compile on Linux; the Android build of `make release-gate` covers Kotlin, the
  Windows and iOS builds their platforms.
- A wrong match is harmless: the line shows "not connected" until the user
  pairs again.
- Key observation adds one message per key press on Android and Windows; it
  carries no key code and nothing leaves the device.

## Decision log

- 2026-11-22: Proposed for #913, implemented in the same PR.
- 2026-11-22: Owner decision during the manual test: with IDs, match by
  vendor and product ID only, not the name, since the AirTurn DUO500's name
  carries its firmware version.
- 2026-11-22: **Accepted** by the owner (#913, PR #921) after the manual test
  on Android (Galaxy Tab S5e, Android 15, AirTurn DUO500): pairing,
  connect and disconnect without a restart, live mode, forget and pair
  again. The Windows build and test and the iPad check were not done yet.

## Open points

- Windows: the runner code (`windows/runner/input_devices.cpp`) was not
  compiled when accepted; build it and repeat the manual test with a page
  turner.
- iPad: check that "A keyboard is connected" follows the page turner.
- macOS (`IOHIDManager`) if a macOS build comes.
