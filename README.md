# neversleeps: keep your MacBook awake with the lid closed

**Run Claude Code, builds, downloads or any long terminal task with the MacBook closed, in a bag.** A menu bar app for macOS that turns the lid-closed sleep lock on and off with one click, and then *proves* it works.

[![Release](https://img.shields.io/github/v/release/philipecomputacao/neversleeps?label=release)](https://github.com/philipecomputacao/neversleeps/releases/latest)
[![Build](https://github.com/philipecomputacao/neversleeps/actions/workflows/build.yml/badge.svg)](https://github.com/philipecomputacao/neversleeps/actions/workflows/build.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000?logo=apple)](#install)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Site:** [philipecomputacao.github.io/neversleeps/en](https://philipecomputacao.github.io/neversleeps/en/) · **Português:** [README.pt-BR.md](README.pt-BR.md), *usar o Claude com o MacBook fechado, sem o Mac dormir.*

## Install

One line, downloads the latest release, **verifies the sha256**, installs to `/Applications` and opens. No `sudo`.

```bash
curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/install.sh | bash
```

<details>
<summary>Other ways</summary>

**Homebrew** (third-party taps must be trusted before tapping):

```bash
brew trust philipecomputacao/neversleeps
brew tap philipecomputacao/neversleeps
brew install --cask neversleeps
```

**Manual:** download the `.zip` from [Releases](https://github.com/philipecomputacao/neversleeps/releases/latest), unzip, drag `neversleeps.app` to Applications. First launch: **right-click → Open** (once), the app is not notarized by Apple yet.

**From source** (macOS 14+, Command Line Tools only, no Xcode):

```bash
git clone https://github.com/philipecomputacao/neversleeps.git && cd neversleeps && bash construir.sh
```
</details>

## Use Claude Code with the MacBook closed

This is the situation the app was built for. Three things have to be true, and only the first one is the app's job:

1. **The Mac must not sleep when closed.** Click the cup in the menu bar → **Prevent Sleep When Lid Is Closed** → Touch ID. The cup fills up. That's the whole gesture.
2. **It needs internet while closed.** Let the iPhone join automatically: *System Settings → Wi-Fi → Personal Hotspot → Automatically*. Claude Code retries when the network comes back.
3. **Heat.** A Claude Code session is light, the Mac spends its time waiting on the API. Heavy builds or looping tests inside a closed bag are not.

Then click **Test the Lid…**, close the Mac for one minute, open it. The app reads the system log (`pmset -g log`) and its own heartbeat and shows the verdict. Until a test passes, the lock line says *"On · not tested yet"*, **on is not the same as proven.**

<p align="center"><img src="Recursos/capturas/en/menu.png" width="420" alt="neversleeps menu: lock line reading “On · tested and passed”, Power Settings, Test the Lid"></p>

## If the power goes out

With the lock on, the Mac does not sleep even when the battery is almost empty: the kernel refuses even the emergency sleep. If the power goes out and the battery runs down, it shuts off with everything that was running. The **Power Failure…** window takes care of what comes next:

1. **Start up on its own.** On a MacBook with Apple silicon (macOS 15+), a Mac that is off starts up when the charger delivers power. This is the macOS default (`nvram BootPreference`); the window shows it, lets you change it and verifies it. On a desktop Mac, the setting is **Start Up After Power Failure**, in Power Settings.
2. **Get past FileVault.** With FileVault on, the Mac stops at the unlock screen before macOS loads. On macOS 26, with **Remote Login** on, you can unlock it from another device on the same network with `ssh user@mac-name.local`; after that, log in through **Screen Sharing**. The window tells you what is on; the app never turns FileVault off.
3. **Resume.** Add the folders Claude Code works in. After an unexpected restart, the app opens each one in Terminal with the chosen command (`claude --continue` by default) and reports what happened: whether the battery ran out, when, and at what charge. **Resume Now** proves it works.

The app knows the restart was unexpected because shutting down or restarting from the Apple menu quits apps, and it sees that; a power failure, a freeze and the power button held down quit nothing.

<p align="center"><img src="Recursos/capturas/en/power-failure.png" width="560" alt="Power Failure window: Start Up on Its Own, After Starting Up, Resume Work, What Happened"></p>

## History

**History…** (⌘Y) shows what happened to the Mac: a strip of the last 24 hours (power adapter, battery, sleep, off) and every event of the last 30 days, grouped by day, with the time and the reason. Went to sleep when the lid closed with the lock off? Unplugged at 01:14 at 100%? The Mac restarted without anyone asking and the tasks came back? It is there. **Copy** takes it all as text. It is kept only on this Mac, in a small file the app writes the moment things happen.

<p align="center"><img src="Recursos/capturas/en/history.png" width="560" alt="History window: strip of the last 24 hours and events grouped by day"></p>

## What it does

| I want to | Do this |
|---|---|
| Work with the lid closed | Click the cup → **Prevent Sleep When Lid Is Closed** |
| Know it's on without clicking | **Full cup** = lock on · **empty cup** = normal sleep |
| Be sure it actually works | **Test the Lid…** (1 minute, real verdict) |
| Change other power settings | **Power Settings…** (⌘,), power adapter and battery side by side, one authentication for all changes |

<p align="center"><img src="Recursos/capturas/en/power-settings.png" width="640" alt="Power Settings window: power adapter and battery columns, Apply button"></p>
| Start with the Mac | On by default since the first launch. **Open at Login** in the menu is the switch to turn it off |
| Get back to work after a power failure | **Power Failure…**: starts up on its own, reports, and reopens your tasks in Terminal |
| Know what happened while I was not looking | **History…** (⌘Y): the 24-hour strip and every event |
| Undo everything | **Restore Power Defaults…** |

## Why not `caffeinate` or Amphetamine?

- `caffeinate` prevents *idle* sleep. Closing the lid overrides it, the Mac sleeps anyway. neversleeps sets `pmset disablesleep`, the only switch that survives the lid.
- Amphetamine can do it (Closed-Display Mode), but it is one option among dozens, and nothing tells you whether it actually held. neversleeps is one toggle, and it tests itself.
- `sudo pmset -a disablesleep 1` in Terminal works, that's exactly what the app runs. The app adds: a visible state in the menu bar, one-click on/off, a real test, and a reminder if you close the Mac with the lock off.

## How it works

- **Reads the real state** with `pmset -g`, `pmset -g custom` and `pmset -g batt` every time the menu opens. Never caches it, change something in Terminal and the menu tells the truth.
- **Writes** with `pmset` as root through **macOS's own authentication dialog** (Touch ID / password), one authentication per change. No `sudoers` rule, no privileged helper, nothing with root left behind.
- **Re-reads after every write.** If macOS accepted the command but ignored the value, you're told.
- **No network. No telemetry.** Nothing leaves your machine. ([SECURITY.md](SECURITY.md))

```bash
/Applications/neversleeps.app/Contents/MacOS/neversleeps --estado        # what the app reads
/Applications/neversleeps.app/Contents/MacOS/neversleeps --repousos 60   # sleep events, last 60 min
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/desinstalar.sh | bash
```

**The lid lock is a macOS setting and does not go away with the app.** The uninstaller asks whether to restore power defaults.

## Development

Swift Package, two targets: `NeversleepsCore` (no AppKit, tested with real `pmset` output) and the app. `swift build` · `swift run verificar` · `bash construir.sh` · `bash publicar.sh`. Interface in English and Portuguese (Brazil), following the system language. See [CONTRIBUTING.md](CONTRIBUTING.md) and the maintenance notes in [AGENTS.md](AGENTS.md).

Tested on Apple Silicon, macOS 26. Requires macOS 14+.

## License

[MIT](LICENSE) · © 2026 LP Digital ([lpdigital.me](https://lpdigital.me))

<sub>Keywords: keep MacBook awake lid closed · run Claude Code with laptop closed · macOS prevent sleep clamshell · pmset disablesleep menu bar · caffeinate alternative lid closed · MacBook fechado não dormir · usar Claude com o notebook fechado</sub>
