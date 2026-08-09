# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rules

Read these before writing code. They are mirrored in `.cursor/` for Cursor,
which does not read this file.

- `.claude/rules/dart-rules.md` — Dart and Flutter conventions for this repo.
- `.claude/rules/filefly-contexto.mdc` — project context in short form.
- `.claude/rules/commit-message-rules.md` — commit format, applied by
  `.claude/commands/commit-message.md`.

**Code in English, comments in Spanish.** Identifiers, class names, function
names and file names are English; comments and dartdoc are neutral, professional
Spanish. UI copy is Spanish. This file and `README.md` stay in English — they
address the agent and the reader, not the compiler.

## Commands

```bash
flutter pub get
flutter analyze                     # must be clean; CI fails on any issue
flutter test                        # full suite
flutter test test/palette_test.dart # one file
flutter test --plain-name 'the served page carries the marker and gets it replaced'
flutter run -d linux                # dev run
flutter build linux --release && tool/install_linux.sh   # user-level install, no root
```

`tool/install_linux.sh` installs into `~/.local/share/filefly`, registers the
`.desktop` entry and the hicolor icons, and links `~/.local/bin/filefly`. Re-run
build + install after changing code. `tool/uninstall_linux.sh` removes it and
leaves the shared folder and the token alone.

Windows is built by `.github/workflows/windows.yml` (Flutter pinned to 3.38.5,
analyze → test → build → Inno Setup installer). A `v*` tag publishes a release.

Only one instance can run: the server holds port 8765. If a run fails to start,
another FileFly is already up.

## Architecture

The desktop window and the phone browser are **two clients of the same folder**.
The window never goes through HTTP — it reads and writes the shared directory
directly and repaints when `FileServer.changes` emits.

```
main.dart          loads assets/web/index.html, injects the palette, boots the app
ui/home_screen.dart owns the FileServer instance, the file list and the layout
server/file_server.dart  dart:io HttpServer, routes, auth, shared folder
server/lan_addresses.dart which IPs a phone can actually reach
server/app_paths.dart     token + shared_dir pointer, per platform convention
app/palette.dart          the only place a hex lives; also the CSS token source
app/theme.dart            ThemeData, Space/Radii/kMotion, AppCard, SectionTitle
assets/web/index.html     the phone page, ~2000 lines, self-contained (QR encoder inline)
```

Three facts that are not obvious from any single file:

**The palette crosses the language boundary at startup.** `main()` calls
`withPaletteTokens()` on the asset string before handing it to `FileServer`,
replacing the `/*__FILEFLY_TOKENS__*/` marker inside `:root` with the hexes from
`AppColors`. The server layer never touches Flutter's asset bundle; it receives
a plain string. `palette_test.dart` asserts every `var(--color)` the page reads
is one `buildCssTokens()` emits.

**Auth is token → cookie, and the token is persistent.** `app_paths.loadToken()`
reads or creates a 32-hex-char token in the platform config dir, mode 600, and
reuses it across runs. A first visit to `/?token=…` sets an `HttpOnly`,
`SameSite=Lax`, 30-day cookie and redirects to a clean `/`. Rotating the token
per launch would invalidate the QR, the bookmarked link and every paired phone's
cookie at once — `loadToken(rotate: true)` is the deliberate lock-everyone-out
path. Comparison is constant-time.

Three paths are served without a token — `/manifest.webmanifest`,
`/icon-256.png`, `/icon-512.png` (`FileServer.publicAssets`, built in `main()`).
The browser fetches them outside the page's cookie context during "add to home
screen"; gating them yields a blank icon.

**Every file name is reduced by `safeFileName()`** before it touches the
filesystem, on upload, download and delete alike. That is the whole path
traversal defense. `uniqueTarget()` then resolves collisions as `name (1).ext`.

**Reachable IPs are filtered, not detected.** `lan_addresses.dart` walks
`NetworkInterface.list()`, drops virtual interfaces by name regex (VPN tunnels,
container bridges, hypervisor adapters) and prefers RFC1918 addresses. A VPN
address in the QR produces a code no phone can open — this is why the filter
exists, not a nicety.

Known limits, stated in the README and deliberate: plain HTTP with no TLS, a
long-lived token, and uncapped upload size.

## Tests

- `file_server_test.dart` — binds on port 0, exercises the token/cookie
  handshake, stale cookies, upload, name collisions, download, delete, traversal.
- `palette_test.dart` — palette injection, the CSS-var/token match, WCAG AA
  contrast for every foreground/surface pair, manifest icons.
- `layout_test.dart` — the `IntrinsicHeight` + `stretch` pairing in the wide
  layout; drop either half and the send card silently shrink-wraps.

---

# FileFly — design directive

FileFly moves files between a desktop and a phone over the LAN. It renders **two
surfaces** and they must look like one product:

1. The Flutter desktop window (`lib/ui/`)
2. The page the server hands to the phone (`assets/web/index.html`)

This file governs any UI change to either one.

## The design system already exists. Use it, do not restate it.

| Concern | Single source of truth |
|---|---|
| Color | `lib/app/palette.dart` → `AppColors` |
| Spacing, radii, motion, type | `lib/app/theme.dart` → `Space`, `Radii`, `kMotion`, `kMonoStyle` |
| Web tokens | injected from `palette.dart` into `:root` by `withPaletteTokens()` |
| Panel shell | `AppCard` |
| Section heading | `SectionTitle` |

**The palette is injected, not duplicated.** `buildCssTokens()` writes the Dart
colors into the served page at startup, and `withPaletteTokens()` throws if the
`/*__FILEFLY_TOKENS__*/` marker is missing. Never hardcode a color in
`index.html`, and never add a hex outside `palette.dart`. Two hand-kept lists
already drifted once; that is why this mechanism exists.

Adding a color means adding it to `AppColors`, adding it to the `tokens` map in
`buildCssTokens()`, and checking contrast in `test/palette_test.dart`.

## Hard bans

These are the patterns that make software look machine-generated. None of them
currently exist in this repo. Do not introduce them.

- **No gradients.** Not on buttons, not on the hero, not on cards. If a surface
  feels flat, reach for a better neutral or a hairline rule.
- **No glow and no shadows.** Elevation here is a hairline border, one language
  throughout. No `BoxShadow`, no `elevation:`, no `box-shadow`, no colored halo
  to make something "pop". The status dot is flat on purpose.
- **No second accent.** `AppColors.accent` is the only one. `accentDeep` carries
  accent meaning where a fill would shout. A new accent color needs a reason
  stated in the diff.
- **No four-card feature grid**, no eyebrow + H1 + H2 + paragraph + tag-pill
  stack, no everything-centered layout. The window is deliberately asymmetric
  (`Expanded` send panel beside a fixed 420px connect panel).
- **No `transition: all`.** Name the properties, use `var(--motion)` and
  `var(--ease-out)`.
- **No off-scale values.** Every gap comes from `Space` or `--s1`..`--s7`. No
  `SizedBox(height: 13)`.
- **No AI tooling residue.** No sparkle icon, no "built with" badge, no model or
  editor name anywhere in the UI.
- **No em dashes in UI copy.** Use a period, a comma, or a colon. Code comments
  are exempt.
- **No placeholder text.** UI copy is Spanish, plain and short, matching the
  existing voice: "Archivos entre la PC y el celular. Sin cable ni apps."

## Documented exceptions — do not "fix" these

- **The QR renders pure white and pure black.** `connect_panel.dart` and the
  `.qrCard` rule in `index.html` are correct as written: a scanner needs a white
  quiet zone and maximum module contrast. This is the one place `#fff`/`#000`
  is right.
- **`errorCorrectionLevel: L`** is deliberate. A URL carrying a 32-char token
  needs the density, and low correction keeps the modules large enough to scan.
- **`IntrinsicHeight` in the top row** is load-bearing, not a smell. The QR card
  is the taller of the two and the send panel would otherwise leave a hole.

## Every change

1. Both surfaces or neither, when the change is systemic. A token added to the
   window and not to the page is a drift bug.
2. Design the unhappy paths. Loading, empty, error, disabled. `_ErrorCard` and
   `_NoNetwork` are the pattern to follow.
3. Keep the comment discipline. This codebase explains *why* a value was chosen,
   not what the line does, and it does it in Spanish. Match that or do not
   comment.
4. Run `flutter test`. `palette_test.dart` enforces WCAG AA contrast,
   `layout_test.dart` enforces the responsive breakpoint at `kNarrowWindow`.

## Before you call a UI change done

- Grep your own diff for: `Gradient`, `BoxShadow`, `box-shadow`, `elevation:`,
  `transition: all`, `Colors.white`, `Colors.black`, `#fff`, `#000`, `z-index`,
  and any raw hex. Every hit needs a one-line justification or it comes out.
- Squint at the window. If every block reads as the same weight, hierarchy is
  gone.
- If you deviated from anything above, say so explicitly. Silent deviation is a
  failure.
