# marmar — roadmap

*Lightweight, fully on-device push-to-talk dictation for macOS 26. Hold a hotkey, speak, the
transcript pastes at the cursor.*

**Updated** 2026-08-13 · v0.1.0 public · ~1.7k LOC · no cloud, no accounts, no LLM

---

## Where this actually is

- **It works and it is used.** SwiftPM executable, `build.sh` assembles a signed `.app` with
  Command Line Tools only. Right-⌘ + Right-⌥ chord via a CGEventTap on device-specific
  modifier bits, mic → PCM → convert → `SpeechAnalyzer` → paste, with near-perfect
  transcription on clean speech. Locale fallback (`en_DE` → `en_US`) and the documented
  result-drain hang avoided by calling `finalizeAndFinishThroughEndOfInput()`.
- **Runs at login** via a launchd agent, relaunches on crash, stays quit when quit manually.
- **A dictation HUD is merged and public** (PR #2) — a non-activating floating `NSPanel` with
  a live transcript and an RMS→dB level meter, which never steals key focus so paste-at-cursor
  still targets the frontmost app.
- **A further round of work is uncommitted, though.** Eleven modified files plus a new
  `Log.swift` sit on `feat-dictation-hud` — logging, hotkey handling, settings, the installer,
  and the README — alongside a stray `test_hotkey.swift`. The local `master` is four commits
  behind origin. None of it is lost, and none of it is shared either.
- **It is essentially finished.** This is the smallest project here and the one with the
  clearest scope. The remaining list is three optional items and one CI question.
- **It depends entirely on macOS 26's `SpeechAnalyzer`** — a new system API, benchmarked at
  ~2.1% WER and 12–40× realtime on Apple Silicon. That is the whole reason marmar can be this
  small, and it is also its only real dependency.

## The one thing that decides this project

**Nothing. It is done.**

marmar is a finished tool that does one thing well. The correct roadmap for a finished tool is
a short one, and the main failure mode available to it is being turned into something larger —
LLM reformatting, cloud sync, a settings app — which would destroy the property that makes it
good.

The one real obligation is to **land the loose round of work**, so the public repository
matches the working tool.

---

## M1 — Land the loose changes ← next

- [ ] Commit and push the pending `feat-dictation-hud` work — eleven modified files plus the
      new `Log.swift`, covering logging, hotkey handling, settings, and `install.sh` — then
      merge to master.
- [ ] `git checkout master && git pull` — local master is four commits behind origin.
- [ ] Delete the stray `test_hotkey.swift` from the working tree, or commit it as a real check.
- [ ] Confirm CI goes green. It depends on GitHub's `macos-26` runner being available; if it
      is not yet, adjust the runner label rather than leaving a permanently red badge on a
      public repository.
- [ ] Tag v0.2.0 and let the release workflow attach `marmar.app.zip`.

**Done when:** the public repository builds, releases, and matches what runs on this machine.

## M2 — The two things a second user would ask for

Optional, small, and both are "without editing source" problems.

- [ ] A menu item to pick the input device and the hotkey. Right-⌘ + Right-⌥ is a good default
      and it is also a hardcoded opinion about someone else's keyboard.
- [ ] Keystroke-synthesis insertion mode as an alternative to clipboard paste, preserving the
      clipboard. The save-and-restore dance works and is the classic source of "it ate my
      clipboard" bug reports.

## M3 — Only if asked

- [ ] User-selectable model and locale in the menu, rather than `Locale.current`. Low priority
      and explicitly flagged as such — the fallback chain already handles the common case.

---

## Not doing

- **LLM reformatting or "clean up my speech".** The named anti-feature. marmar is a minimal
  alternative to tools that do exactly this; adding it means becoming the thing it replaced.
- **Cloud, accounts, sync, or history.** Fully on-device is the product.
- **Real-time streaming into the target app.** Push-to-talk, then paste. The bounded
  interaction is why it never gets in the way.
- **iOS or a cross-platform port.** It is a thin shell over an Apple system API. There is no
  port; there would be a rewrite.

## Risks worth naming

- **A single-API dependency on a new OS release.** `SpeechAnalyzer` is macOS 26 only. Every
  OS update is a regression risk, and CI can only catch it if the `macos-26` runner exists —
  which is currently the open CI question.
- **CGEventTap on device-specific modifier bits is fragile.** It reads raw hardware modifier
  flags to distinguish right-⌘ from left-⌘. Keyboard remappers, external keyboards, and
  Karabiner-style tools all interfere, and accessibility permissions silently break event taps
  after some OS updates.
- **The clipboard save-and-restore path** is where the first real bug report will come from.
  M2's keystroke-synthesis mode is the mitigation.
