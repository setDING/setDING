---
title: Installation
description: Install setDING on Android, Windows and Linux.
sidebar:
  order: 2
---

All versions are in the
[releases on GitHub](https://github.com/tafli/setDING/releases/latest).

## Android

setDING is installed and kept up to date with
[Obtainium](https://github.com/ImranR98/Obtainium). It runs on 64-bit ARM devices
(arm64), which includes practically all current tablets.

1. Install Obtainium (from its GitHub releases or from F-Droid).
2. In Obtainium, tap **Add app**, enter `https://github.com/tafli/setDING` and tap
   **Add**.
3. Install setDING. Obtainium reports new versions and offers the update.

## Windows

1. Download `setding-<version>-windows-x64-setup.exe` and run it. It installs
   setDING for your Windows user, without administrator rights.
2. The app is not code-signed, so Windows SmartScreen warns once; click
   **More info**, then **Run anyway**.

When a new version is available (see [Updates](#updates)), setDING offers
**Install** in the hint and under **Settings → Storage & info**. It downloads the
new version, closes setDING, updates it and starts it again; your data stays.
Running a newer setup by hand does the same.

Prefer no installation? `setding-<version>-windows-x64.zip` contains the same
app: unpack it and start `setding.exe`. This copy does not update itself.

## Linux

1. Download `setding-<version>-linux-x64.AppImage`.
2. Make it executable (in the file manager under *Properties*, or with
   `chmod +x setding-*.AppImage`) and start it.

When a new version is available (see [Updates](#updates)), setDING offers
**Install**. It downloads the new AppImage, replaces the file, closes and starts
again; your data stays. The file must be in a folder you can write to (e.g. your
home folder). If the AppImage does not start, FUSE is missing; install your
distribution's `fuse3` package.

Prefer no AppImage? `setding-<version>-linux-x64.tar.gz` contains the same app:
unpack it and start `setding`. This copy does not update itself.

## Updates

setDING checks once a day whether a newer version is available. A dot then
appears on **Settings**, and **Settings → Storage & info** shows the new version
with a link to its download page (with **Install** on Windows if you installed
setDING with the setup, and for the Linux AppImage). The hint never appears in live mode.

After an update, setDING briefly shows **New in setDING …** once; **Show**
lists what is new in this version; older versions are on the [news](/en/news/) page. You can read it again any
time with **What's new** next to the version under **Settings → Storage & info**.

## iOS

Coming later.
