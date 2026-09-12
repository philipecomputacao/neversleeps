# neversleeps

**Keeps your Mac working with the lid closed.** A menu bar app for macOS.

[Português](README.pt-BR.md) · [Changelog](CHANGELOG.md) · [MIT](LICENSE)

Built for one real situation: you're running Claude Code (or any long terminal task), you close the MacBook, put it in a bag — and the task keeps running over Wi-Fi or your iPhone's hotspot.

<!-- screenshot: menu with the cup icon, lock line and settings item -->

## Install

**Download** the latest `neversleeps-<version>.zip` from [Releases](https://github.com/philipecomputacao/neversleeps/releases), unzip, and drag `neversleeps.app` to **Applications**.

**First launch: right-click → Open** (once). The app is not yet notarized by Apple, so macOS warns the first time and then stops asking.

Or with Homebrew (personal tap):

```bash
brew tap philipecomputacao/neversleeps https://github.com/philipecomputacao/neversleeps
brew install --cask neversleeps
```

Or build from source (macOS 14+, Command Line Tools only — no Xcode needed):

```bash
git clone https://github.com/philipecomputacao/neversleeps.git
cd neversleeps
bash construir.sh
```

## Use

| I want to | Do this |
|---|---|
| Work with the lid closed | Click the cup → **Prevent Sleep When Lid Is Closed** → authenticate. The cup fills up. |
| Know it's on without clicking | **Full cup** = lock on. **Empty cup** = normal sleep. |
| Be sure it actually works | **Test the Lid…** → close the Mac for 1 minute → open. The verdict appears on its own. |
| Change other power settings | **Power Settings…** (⌘,) — power adapter and battery side by side, one authentication for all changes. |
| Have it start with the Mac | **Open at Login** |
| Undo everything | **Restore Power Defaults…** |

**On is not the same as proven.** The lock line says *"On · not tested yet"* until the lid test passes. The test uses two independent witnesses — the system log (`pmset -g log`) and the app's own 5-second heartbeat — and both must agree.

### What the lock doesn't solve

- **Network on the go.** Let the iPhone join automatically: *System Settings → Wi-Fi → Personal Hotspot → Automatically*. This is a Wi-Fi setting; the app can't control it.
- **Heat.** A Claude Code session is light (the Mac mostly waits on the network). Heavy builds or looping tests inside a closed bag are not.

## How it works

- Reads the real state with `pmset -g`, `pmset -g custom`, `pmset -g batt` every time the menu opens. Never caches it — if you change something in Terminal, the menu tells the truth.
- Writes with `pmset` as root through **macOS's own authentication dialog** (Touch ID / password), one authentication per change. No `sudoers` rule, no privileged helper, nothing with root left behind.
- **Re-reads after every write.** If macOS accepted the command but ignored the value, you're told.
- **No network. No telemetry.** Nothing leaves your machine.

### Command line

```bash
/Applications/neversleeps.app/Contents/MacOS/neversleeps --estado        # what the app reads
/Applications/neversleeps.app/Contents/MacOS/neversleeps --repousos 60   # sleep events, last 60 min
```

## Uninstall

```bash
bash desinstalar.sh
```

**The lid lock is a macOS setting and does not go away with the app.** The uninstaller asks whether to restore power defaults; say yes unless you want the Mac to keep the lock.

## Development

```bash
swift build          # build
swift test           # core tests (parser, model) with real pmset output as fixtures
bash construir.sh    # bundle + install
bash publicar.sh     # zip + GitHub release
```

Swift Package, two targets: `NeversleepsCore` (no AppKit, testable) and the app. Interface in Portuguese (Brazil) and English, following the system language. Tested on Apple Silicon, macOS 26.

## License

[MIT](LICENSE) — © 2026 LP Digital ([lpdigital.me](https://lpdigital.me))
