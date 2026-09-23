# CLAUDE.md

## What this repository is

A personal fork of [Hidden Bar](https://github.com/dwarvesf/hidden), a macOS
menu bar app that hides other apps' status items. The `upstream` remote points
at dwarvesf/hidden; `develop` is the default branch on both sides.

Because this is a fork that tracks upstream, **keep the diff against upstream
small and localized**. Prefer adding a new method next to the existing ones over
rewriting existing code, and do not reformat or refactor code that the change
does not touch.

Upstream's own documentation applies here and is the first place to look:

- `docs/ARCHITECTURE.md`: how hiding works, the `MenuBarEngine` split, and the
  known architectural limits.
- `docs/RUNBOOK.md`: behavioral verification against the real menu bar.
- `docs/MANUAL.md`: user-facing behavior.

## Build

Use `task` (see `Taskfile.yml`). `task --list` shows the available tasks.

Machine-local configuration lives in `.env.local`, which `Taskfile.yml` loads
via `dotenv` and direnv loads via `.envrc`. It is git-ignored; `.env.example` is
the tracked template and must stay free of machine-specific values. A missing
`.env.local` is not an error, the build falls back to ad-hoc signing.

The tasks build the **Hidden Bar** scheme in its `Debug-Direct` and
`Release-Direct` configurations. That is the unsandboxed direct build, compiled
with `HIDDENBAR_NATIVE_VISIBILITY`, and the only one that can hide on macOS 27
(`NativeVisibilityEngine`). The **Hidden Bar App Store** scheme builds the
sandboxed `Debug` / `Release` configurations and always uses
`LegacyLengthEngine`.

Build output goes to Xcode's own DerivedData directory: the tasks do not pass
`-derivedDataPath`, so `xcodebuild` and Xcode.app share one build directory and
nothing lands in the working tree. The product path carries a hash, so the build
tasks ask `xcodebuild -showBuildSettings` for `BUILT_PRODUCTS_DIR` and print the
resulting path when they finish.

## Verification

- `task test` runs the unit tests (`HiddenBarTests`, `HiddenTests`). They cover
  the pure parts: engine decisions against fakes, action mapping, notch
  geometry, preferences.
- `task lint:strings` checks that every `.strings` table still parses.
- Status-item behavior can only be checked in the real menu bar; follow
  `docs/RUNBOOK.md`.

The dev build shares the preferences domain `com.dwarvesv.minimalbar` with the
installed app, and the app refuses to run a second instance. `task run` quits
the running copy first. Before testing something that writes preferences, back
the domain up with `defaults export com.dwarvesv.minimalbar <file>`.

## Code signing

Signing is overridden on the `xcodebuild` command line, never in
`project.pbxproj`: upstream ships `DEVELOPMENT_TEAM = W777S7V8TN`, and editing
that file adds fork drift to something that conflicts badly on merge. The
override comes from `.env.local` (`HB_CODE_SIGN_IDENTITY`,
`HB_DEVELOPMENT_TEAM`); `task signing` prints what is in effect.

The app is only ever run locally, so Gatekeeper and notarization do not apply.
What does apply is TCC: Accessibility permission is needed by Notch Overflow
and by the macOS 27 native engine, and TCC stores it against the app's
designated requirement:

- Ad-hoc (`CODE_SIGN_IDENTITY=-`) produces `designated => cdhash H"..."`, the
  hash of that exact build. Every rebuild is a different app to macOS:
  Accessibility has to be granted again and a dead entry is left behind in
  System Settings.
- A certificate produces a requirement on the identifier and the certificate,
  which does not depend on the build's contents. Grant Accessibility once and
  rebuilds keep it.

So prefer a real certificate for anything that gets used, and keep ad-hoc for
throwaway checks. Changing the identity changes the designated requirement, so
the first launch after a switch needs Accessibility granted again and the stale
entry removed.

## Code style

There is no formatter or linter in this project. Follow the surrounding code:
4-space indentation, `guard`-based early returns, and comments that explain why
a mechanism is the way it is (the menu bar is full of undocumented macOS
behavior, and the comments are where that knowledge lives).

Status-item mechanics belong in an engine under
`hidden/Features/StatusBar/Engine/`; `StatusBarController` decides what the user
wants and never writes a status-item length itself.

## Language

- Swift code, comments, commit messages and documentation: English.
- User-facing strings: `"English text".localized`, with the English text as the
  key. Translations live in `hidden/*.lproj/Localizable.strings`, storyboard
  strings in `hidden/*.lproj/Main.strings`. When adding a string, add it to
  `en` and `ja` at least.
