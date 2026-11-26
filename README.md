# Drift

Soft dots, stars, hearts and other little shapes drift slowly up and down
your screen while you work. Every few minutes Drift changes mood: new colours,
new shapes, a new pace. Most moods are soft and muted; now and then one is
bright.

Drift is a menu bar app built with Swift, AppKit and Core Animation. The
window server animates the shapes, so Drift itself stays nearly idle: about
0% CPU and 12 MB of memory.

Runs on macOS 13 or later, on Apple silicon and Intel Macs.

## Build

You need the Xcode Command Line Tools (`xcode-select --install`). You don't
need the Xcode app.

```sh
./build.sh            # builds build/Drift.app for this Mac
./build.sh install    # builds, then copies Drift.app to ~/Applications
./build.sh dist       # builds for Apple silicon and Intel, zips to build/Drift.zip
./build.sh test       # runs the logic checks
```

## Run

```sh
open ~/Applications/Drift.app
```

Drift has no Dock icon. Look for the dotted circle in the menu bar. The menu has:

- **Pause / Resume**
- **Layer**: Behind windows (just above the wallpaper) or Over windows
  (above everything, fainter). Both ignore clicks.
- **Number of dots**: Few (15), Some (25) or Many (40) per screen
- **Speed**: Slower, Normal or Faster
- **Opacity**: Subtle, Medium or Visible
- **Pause in Low Power Mode** (on by default)
- **Launch at Login**
- **Quit Drift**

Settings are saved between launches. Drift also pauses while the displays
sleep, the screen is locked, or you switch to another user. Only one copy runs
at a time; opening it again does nothing.

## Check its resource use

```sh
./monitor.sh          # 5 samples, 1 second apart
./monitor.sh 10 60    # 10 samples, a minute apart
```

It shows how many Drift processes are running (it should be 1), then CPU and
memory for each sample, then the average CPU.

## Launch at login

Pick **Launch at Login** in the menu. Drift must be in `~/Applications` or
`/Applications` first. If macOS asks for approval, Drift opens
System Settings › General › Login Items, where you can switch it on.

## Share with friends

Run `./build.sh dist` and send `build/Drift.zip`. It runs on Apple silicon and
Intel Macs with macOS 13 or later.

This build isn't notarized by Apple, so the first time a friend opens it,
macOS blocks it. To allow it:

1. Unzip it, move Drift.app to Applications, and double-click it. macOS shows
   a warning; click **Done** (or **OK**).
2. Open System Settings › Privacy & Security, scroll down, and click
   **Open Anyway** next to the message about Drift.
3. Open Drift again and confirm.

After that it opens normally.

## Uninstall

1. Turn off **Launch at Login** in the menu, then pick **Quit Drift**.
2. Delete the app and its settings:

```sh
rm -rf ~/Applications/Drift.app
defaults delete local.drift.Drift
```
