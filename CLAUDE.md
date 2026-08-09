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
   not what the line does. Match that or do not comment.
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
