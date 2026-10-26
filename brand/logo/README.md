# Trippo logo kit

The Trippo name comes from the app's hippo guide, so the logo is a hippo
peeking out of the water. The wavy waterline doubles as a travel route, with
dotted stops underneath. The pin version is a hippo-shaped map marker.

Everything in this folder is meant to be read by people and by Claude Code.
The SVGs are hand-written and commented, and the Flutter file draws the same
shapes in code.

## Files

| Path | What it is | Use it for |
|---|---|---|
| `svg/trippo-mark.svg` | The hippo on its own, terracotta | In-app headers, about screen, favicons |
| `svg/trippo-mark-reversed.svg` | Cream hippo, no background | On terracotta or dark backgrounds |
| `svg/trippo-pin.svg` | Hippo map pin; tip at (60, 112) of 120 | Map markers |
| `svg/trippo-wordmark.svg` | "Trippo" as outlines (no font needed) | Places where only the name fits |
| `svg/trippo-lockup.svg` | Hippo + wordmark | The main logo |
| `svg/trippo-lockup-on-dark.svg` | Main logo on ink background | Dark surfaces, social images |
| `svg/trippo-app-icon.svg` | 1024 square, full bleed, no rounded corners | iOS app icon source (the OS masks the corners) |
| `svg/trippo-app-icon-foreground.svg` | Transparent, art inside the safe zone | Android adaptive icon foreground |
| `png/` | The same, rendered | Anywhere an SVG can't go |
| `flutter/trippo_logo.dart` | `TrippoMark`, `TrippoPin`, `TrippoLogo`, `TrippoLogoAnimation` | In the app; no new packages |
| `animation/trippo-logo-animation.html` | The animation in CSS, open it in a browser | The reference the Flutter animation follows |
| `animation/*.mp4`, `*.gif`, `*.webm` | Rendered 6 s loops (the WebM has a transparent background) | Social posts, README, web |

## Colours

These match the app's existing tokens in `lib/design/tokens.dart`.

| Name | Hex | Token |
|---|---|---|
| Terracotta (hippo, water) | `#B8543A` | `WayfareColors.accent` |
| Deep terracotta (inner ears, nostrils, pin smile) | `#8F3D28` | `WayfareColors.accentDark` |
| Ink (pupils, wordmark) | `#241F1A` | `WayfareColors.ink` |
| Cream (background, wordmark on dark) | `#F4EFE6` | `WayfareColors.bgApp` |
| Surface (eye whites, reversed hippo) | `#FFFDF9` | `WayfareColors.surface` |
| Blush (reversed inner ears, nostrils) | `#E3A18A` | none, logo only |

## Type

The wordmark is Instrument Serif, regular, tracked -1%. The app's own display
face is a different serif, and that's deliberate: the wordmark is part of the
logo, not a heading. The SVG wordmark is converted to outlines, so it never
depends on the font. The Flutter `TrippoLogo` sets live text through
`google_fonts`.

## Sizes and spacing

- In the lockup, the wordmark's font size is 136/176 of the mark's height, with
  a gap of 22/176 of the mark's height between them.
- Leave clear space of at least one eye-bump width (about 20% of the mark's
  height) on every side.
- Smallest sizes: 24 px for the mark, 20 px for the pin, 96 px wide for the
  lockup.
- Don't stretch it, recolour individual parts, add shadows or outlines, or put
  the terracotta mark on a terracotta background.

## Animation timeline

A 6-second loop. Percentages are of the loop. The waves scroll continuously, one
wavelength (32 units) every 1.5 s.

| When | What | Easing |
|---|---|---|
| 6–18% | Hippo rises 72 units out of the water, with a small bounce | `cubic-bezier(.3, 1.4, .5, 1)` |
| 8–30% | Ripple ring grows from 0.3x to 1.6x and fades out | ease-out |
| 20–30% | Letters slide up 28 px and fade in, 0.05 s apart | `cubic-bezier(.2, .9, .3, 1.2)` |
| 22–32% | Route dots fade in to 55% | ease-in-out |
| 34–42% | Tagline fades in | ease-out |
| 42–48% | Blink: eyes squash to 8% and reopen | ease-in-out |
| 56–70% | Ear wiggle: 0, -16°, 12°, -6°, 0 (right ear 0.08 s later) | ease-in-out |
| 82–94% | Tagline, letters and dots fade out; hippo sinks | as above |

With reduced motion turned on, show the still logo instead.

## Using it in the Flutter app

```dart
import 'package:trippo/design/trippo_logo.dart';

TrippoMark(size: 40);                      // the hippo
TrippoLogo(height: 56);                    // hippo + "Trippo"
TrippoPin(size: 40);                       // map marker; anchor at TrippoPin.tipAlignment
TrippoLogoAnimation(height: 120);          // looping animation
TrippoLogoAnimation(                       // splash: plays once, then holds
  loop: false,
  onIntroComplete: () => /* go to the trip list */,
);
```

App icons: copy the two PNGs from `png/` into `app/assets/brand/` and use
`flutter_launcher_icons`:

```yaml
flutter_launcher_icons:
  image_path: "assets/brand/trippo-app-icon-1024.png"
  ios: true
  remove_alpha_ios: true
  android: true
  adaptive_icon_background: "#B8543A"
  adaptive_icon_foreground: "assets/brand/trippo-app-icon-foreground-1024.png"
```

## Handing this to Claude Code

Open Claude Code in the Trippo repo and paste:

> Read `brand/logo/README.md`. Then:
> 1. Move `brand/logo/flutter/trippo_logo.dart` to `app/lib/design/trippo_logo.dart`,
>    swap `TrippoBrandColors` for the matching `WayfareColors` tokens where they
>    exist, and run `flutter analyze` and fix anything it reports.
> 2. Add a widget test that pumps `TrippoMark`, `TrippoLogo` and
>    `TrippoLogoAnimation(loop: false)` and checks the intro callback fires.
> 3. Use `TrippoLogoAnimation(loop: false)` on a splash screen shown while the
>    session loads, then go to the trip list.
> 4. Use `TrippoLogo` in the trip list's empty state, and `TrippoPin` for
>    place markers on the `flutter_map` map.
> 5. Set up the app icons with `flutter_launcher_icons` as the README shows.
>
> Keep the shapes and timings exactly as in the README and the SVGs.
