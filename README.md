## About this fork

This is a personal fork of [Hidden Bar](https://github.com/dwarvesf/hidden). It
is not intended to be merged back upstream. It branches from upstream `develop`
as of 2026-09-19 (after Notch Overflow landed). The rest of this README is
upstream's: the install links and releases it points to are upstream builds,
which do not include the changes below. To use this fork, build it locally
with `task install` (see [CLAUDE.md](CLAUDE.md) for signing).

### Changes from upstream

Behavior (macOS 27 items apply to the direct, non-App Store build only):

- **Hide the arrow while collapsed** (macOS 27): an optional Preferences
  checkbox takes the arrow away with the hidden icons and closes its gap. It
  only applies while a global shortcut or hover-to-expand can expand the bar.
- **Double-press the shortcut to show icons past the notch** (macOS 27,
  off by default): a double press expands and also opens the `«` overflow
  button macOS shows when icons do not fit beside the notch. macOS gives no
  way to open it except a click, so Hidden Bar synthesizes one: a menu open
  at that moment closes, and the pointer occasionally does not return.
- **Hover-to-expand checkbox**: upstream only offered it as a Terminal default.
  It now has a Preferences checkbox and takes effect without a relaunch.
- **Clearing the shortcut removes it** from the preferences instead of storing
  a `null` value.

Development:

- `Taskfile.yml` builds, tests, runs and installs the direct build, with the
  signing identity taken from a git-ignored `.env.local` instead of upstream's
  development team.
- `CLAUDE.md` is tracked and describes the fork's build and conventions.

### Cherry-picked from upstream pull requests

These commits keep their original authors:

- **Time Machine and other SystemUIServer menu extras can stay visible** on
  macOS 27 instead of always being hidden, with tests for how they are
  sectioned (by renovys).
- **The whole bar shows while a microphone or camera is in use** on macOS 27,
  so the menu-bar indicator naming the recording app is not hidden (by Kevin
  Hallmark).
- **Documentation of what macOS 27 restricts while collapsed**: Now Playing,
  Live Activities, and the clock not opening Notification Center (by Kevin
  Hallmark).

<p align="center">
	<img width="200" height="200" margin-right="100%" src="https://github.com/dwarvesf/hidden/blob/develop/img/icon_512%402x.png?raw=true">
</p>
<p align="center">
	<a href="https://webuild.community">
		<img src="https://raw.githubusercontent.com/webuild-community/badge/master/svg/love.svg" />
	</a>
	<a href="https://github.com/dwarvesf/hidden/releases/latest">
 		<img src="https://img.shields.io/badge/download-latest-brightgreen.svg" alt="download">
	</a>
	<a href="https://img.shields.io/badge/platform-macOS-lightgrey.svg">
 		<img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" alt="platform">
	</a>
	<a href="https://img.shields.io/badge/requirements-macOS Ventura+-ff69b4.svg">
 		<img src="https://img.shields.io/badge/requirements-macOS Ventura+-ff69b4.svg" alt="systemrequirements">
	</a>
</p>

## Hidden Bar
Hidden Bar lets you hide menu bar items to give your Mac a cleaner look.

<p align="center">
	<img width="400" src="img/screen1.png">
	<img width="400" src="img/screen2.png">
</p>

## 🚀 Install

###  App Store

[![AppStore](img/appstore.svg)](https://itunes.apple.com/app/hidden-bar/id1452453066)

### Others

The Hidden Bar is notarized before distributed out side App Store. It's safe to use 👍

#### Using Homebrew

```
brew install --cask hiddenbar
```

#### Manual download

- [Download latest version](https://github.com/dwarvesf/hidden/releases/latest)
- Open and drag the app to the Applications folder.
- Launch Hidden and drag the icon in your menu bar (hold CMD) to the right so it is between some other icons.

## 🕹 Usage

* `⌘` + drag to move the Hidden icons around in the menu bar.
* Click the Arrow icon to hide menu bar items.

<p align="center">
	<img src="img/tutorial.gif">
</p>

## 📚 Documentation

- [Manual](docs/MANUAL.md): every setting, the hidden Terminal-only options, and troubleshooting.
- [Architecture](docs/ARCHITECTURE.md): how the hiding trick works, topology, and known limits.
- [Maintainer runbook](docs/RUNBOOK.md): build, behavioral verification, and release process.

## ✨<a href="https://github.com/dwarvesf/hidden/graphs/contributors">Contributors</a>

This project exists thanks to all the people who contribute. Thank you guys so much 👏

[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/0)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/0)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/1)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/1)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/2)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/2)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/3)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/3)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/4)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/4)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/5)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/5)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/6)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/6)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/7)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/7)

Please read [this](CONTRIBUTING.md) before you make a contribution.

## Requirements
macOS version >= 13.0 (Ventura)

Running an older macOS? The last release supporting macOS 10.13 High Sierra
through 12 Monterey is [v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).
Later versions require macOS 13 because autostart moved to the `SMAppService`
API introduced there.

## You may also like
- [Blurred](https://github.com/dwarvesf/Blurred) - A macOS utility that helps reduce distraction by dimming your inactive noise
- [Micro Sniff](https://github.com/dwarvesf/micro-sniff) - An ultra-light macOS utility that notify whenever your micro-device is being used
- [VimMotion](https://github.com/dwarvesf/VimMotionPublic) Vim style shortcut for MacOS
## License

MIT &copy; [Dwarves Foundation](https://github.com/dwarvesf)
