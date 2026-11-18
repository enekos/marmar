# marmar

A lightweight, **fully on-device** push-to-talk dictation tool for macOS 26+.
Hold **Right-Command + Right-Shift**, speak, release — the transcript is pasted at your cursor.

Think "ghostpepper, but minimal": no cloud, no accounts, no LLM reformatting.
Just Apple's new [`SpeechAnalyzer` / `SpeechTranscriber`](https://get-inscribe.com/blog/apple-speech-api-benchmark.html)
API (macOS 26), which benchmarks at ~2.1% word error rate and 12–40× realtime
on Apple Silicon.

## Requirements

- macOS 26+ (uses the `Speech` framework's on-device `SpeechAnalyzer`)
- Swift toolchain (Command Line Tools is enough — **no Xcode needed**)

## Build & run

```sh
./build.sh              # compiles + assembles .build/marmar.app
open .build/marmar.app  # launches into the menu bar (mic icon)
```

Run the binary directly to see logs:

```sh
.build/marmar.app/Contents/MacOS/marmar
```

Headless sanity check (records the mic for N seconds and prints the transcript):

```sh
.build/marmar.app/Contents/MacOS/marmar --record 8
```

## Run at login

```sh
./install.sh     # builds, copies to ~/Applications, enables launch-at-login, starts it
./uninstall.sh   # disables launch-at-login and removes it
```

Launch-at-login uses `SMAppService` (a self-contained login item) — toggle it
any time from the menu-bar icon ▸ **Settings… ▸ Service status ▸ Start marmar at
login**. macOS may list it under System Settings ▸ General ▸ Login Items as
"needs approval" the first time. Because the installed copy has a different code
signature than a dev build, you may need to re-grant Microphone + Accessibility.

(Earlier versions used a hand-rolled LaunchAgent; `install.sh` migrates away from
it automatically.)

## Download a prebuilt release

Tagged builds are attached to [GitHub Releases](../../releases) as
`marmar.app.zip` (built in CI on a macOS 26 runner). After downloading, clear
the Gatekeeper quarantine on the ad-hoc-signed bundle:

```sh
xattr -dr com.apple.quarantine marmar.app
```

Then move it to `~/Applications` and run `install.sh`'s launch-agent steps, or
just `open marmar.app`.

## First launch — grant two permissions

1. **Microphone** — prompted automatically on first launch.
2. **Accessibility** — needed to read the global hotkey and synthesize the
   paste. macOS opens System Settings → Privacy & Security → Accessibility;
   enable `marmar`, then **relaunch** the app.

The first dictation also downloads the ~small on-device language model for your
current locale (one time; the menu shows "Downloading speech model…").

## Usage

- **Hold Right-Command + Right-Shift** → the icon fills in and the menu shows a live partial
  transcript.
- **Release** → the finalized text is pasted into the focused app. Your previous
  clipboard contents are saved and restored.
- **Quit** from the menu (or ⌘Q while the menu is open).
- **Settings…** in the menu (or ⌘,) opens a small preferences window:
  - **Language** — system default, or any on-device locale
  - **Dictation hotkey** — Right ⌘+⇧ / Right ⌘+⌥ / Right ⌘+⌃ / Right ⌥ / Right ⌃
  - **Add a trailing space** after each transcript
  - **Sound feedback** when listening starts/stops

  Changes apply immediately and persist across launches. You can also open just
  the settings window headlessly with `marmar --settings`.

## How it works

| Piece | File |
|-------|------|
| Menu bar app + permissions | `AppDelegate.swift` |
| Hold-to-talk hotkey (CGEventTap on right-side modifiers) | `HotKey.swift` |
| Mic capture (AVAudioEngine) | `AudioCapture.swift` |
| On-device recognition (SpeechAnalyzer) | `LiveTranscriber.swift` |
| Session coordination | `DictationController.swift` |
| Clipboard paste + restore | `TextInserter.swift` |

Each hold starts a fresh `SpeechAnalyzer` session, streams converted PCM
buffers in, and on release calls `finalizeAndFinishThroughEndOfInput()` to flush
the final transcript (skipping this hangs the pipeline — a documented footgun).

## Tweaks

- **Different language**: it follows `Locale.current`. `SpeechTranscriber`
  supports ~30 locales on-device.
- **Keep clipboard untouched**: swap `TextInserter` for a keystroke-synthesis
  approach (slower, preserves clipboard).
