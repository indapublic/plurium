# Plurium

Chromium for macOS where the tabs of **all your profiles** live in one window,
in one tab strip. Work, personal and side-project accounts stay fully isolated
(cookies, logins, extensions), but you see and switch between all their tabs at
once, in any order you like. Each tab is underlined in its profile's theme
color.

![Tabs of four profiles in one strip](docs/strip.jpg)

## Install

Apple Silicon, macOS 13 or later.

```bash
brew tap indapublic/plurium https://github.com/indapublic/plurium
brew trust --cask indapublic/plurium/plurium   # Homebrew 7+ asks to trust third-party taps
brew install --cask indapublic/plurium/plurium
```

Plurium updates itself through Homebrew: when a new version is out, an
**Update** button appears at the end of the tab strip (and *Plurium → Update
to …* in the menu bar). It quits, runs `brew update` and
`brew upgrade --cask plurium`, and reopens with all your tabs. The check runs a
minute after launch and every six hours by downloading the cask file from this
repository; *Plurium → Check for Updates…* checks right away. To turn the
automatic checks off:
`defaults write com.indapublic.plurium PluriumAutomaticUpdateChecks -bool NO`.
The update log is `~/Library/Logs/Plurium/update.log`.

Remove with `brew uninstall --cask plurium` (add `--zap` to also delete the
profiles).

The app is signed with a Developer ID and notarized by Apple.

## What it does

- One window for all profiles: each profile's browser window becomes a tab of
  one native macOS window tab group. Their AppKit tab bar is hidden.
- One tab strip with the tabs of all profiles, drawn the same way and
  underlined in the profile color. Click to switch (profiles switch as
  needed), drag to reorder anywhere, middle-click or × to close.
- Right-click a tab: Reload, Duplicate, Mute, **Move to profile** (reopens the
  URL in another profile at the same place), Close, Close other tabs of the
  profile. Right-click **+** to open a new tab in any profile.
- Chrome's tab shortcuts follow the shared strip: ⌘1…⌘8, ⌘9 (last tab),
  ⌃Tab / ⌃⇧Tab, ⌘⌥← / ⌘⌥→, ⌘⇧[ / ⌘⇧], ⌃PgUp / ⌃PgDn, and ⌃⇧PgUp / ⌃⇧PgDn to
  move a tab. ⌃1…⌃9 jump to the N-th profile.
- Incognito windows join too ("Work (Incognito)"). DevTools, popups, PWAs and
  dialogs stay separate windows.
- Shared fullscreen for the whole group, with the same strip in fullscreen.
- The order of the strip is kept across restarts.

Set each profile's color in *Customize Chromium → Color*.

## Data

- Profiles: `~/Library/Application Support/Plurium`
- Bundle id: `com.indapublic.plurium` — Plurium does not share data with
  Chromium or Google Chrome installed next to it.

## Limitations

- No Chrome Sync and no signing in to the browser itself (no Google API keys).
  Signing in to websites works as usual.
- No Widevine, so DRM video (Netflix, Spotify Web) does not play.
- Updates come only through new releases of this repository; every Chromium
  security release needs a rebuild.
- In place of Chromium's tab strip you lose hover previews, pinned tabs and tab
  groups (still in the model, not drawn), dragging a tab out into a new
  window, dropping links onto the strip, and tab search.
- Some built-in texts still say "Chromium".

## Build from source

The patches apply to the stable tag of Chromium they were made for
(currently **154.0.8037.98**):

```bash
mkdir -p /Volumes/Workspace/chromium && cd /Volumes/Workspace/chromium
git clone https://github.com/indapublic/plurium
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
fetch --nohooks chromium && cd src
git fetch origin +refs/tags/154.0.8037.98:refs/tags/154.0.8037.98
git checkout -b profile-tabs tags/154.0.8037.98
git am ../plurium/patches/000*.patch
gclient sync -D --with_branch_heads --with_tags
gn gen out/Release --args='is_debug=false is_component_build=false symbol_level=0 dcheck_always_on=false target_cpu="arm64" proprietary_codecs=true ffmpeg_branding="Chrome"'
autoninja -C out/Release chrome
```

A full build takes about 9 hours on an M1 with 16 GB. The detailed guide
(night build scripts, rebase procedure, checklist, signing) is in Russian:
[README.ru.md](README.ru.md).

| Patch | |
|---|---|
| `0001` | Join profile windows into one native window tab group |
| `0002` | ⌃1…⌃9 select the N-th profile |
| `0003` | Hide AppKit's tab bar, shared fullscreen |
| `0004` | One tab strip with the tabs of all profiles |
| `0005` | Plurium name, bundle id, data directory and icon |
| `0006` | Updates through Homebrew from inside the app |

Releases are made with `tools/release.sh` (Chromium's signing scripts,
notarization, DMG, cask bump).

## License

Plurium is a modified build of [Chromium](https://www.chromium.org/), whose
source is under a BSD-style license; see `chrome://credits` in the app for the
licenses of all components. Plurium is not affiliated with or endorsed by
Google. Chromium is a trademark of Google LLC.
