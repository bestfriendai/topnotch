# Top Notch — App Icon Specification

## Concept
A pure-black 1024×1024 square with a glowing pill/capsule shape centered slightly above-center, evoking the MacBook notch transformed into a Dynamic Island. Tiny, colorful widget icons live inside the pill. A diffuse purple-to-blue radial glow bleeds outward from the pill, fading to black.

---

## Canvas
| Property | Value |
|---|---|
| Dimensions | 1024 × 1024 px |
| Color profile | sRGB |
| Background | `#000000` (pure black) |
| Corner radius (macOS icon mask) | Applied automatically by macOS — do NOT pre-round the canvas |

---

## Layer Stack (bottom to top)

### 1. Background
- Fill: `#000000`
- Full canvas, no rounding

### 2. Outer Glow (radial gradient)
- Shape: Ellipse, centered at `(512, 500)`, width `780px`, height `340px`
- Gradient: radial, center → edge
  - Center stop: `rgba(120, 60, 255, 0.55)` — violet-purple
  - Mid stop (50%): `rgba(60, 100, 255, 0.28)` — indigo-blue
  - Edge stop: `rgba(0, 0, 0, 0)` — transparent
- Blend mode: Screen (or Normal with opacity 80%)

### 3. Notch Pill Shape
- Shape: Rounded rectangle (pill / stadium shape)
- Dimensions: `580px wide × 130px tall`
- Corner radius: `65px` (fully rounded ends)
- Position: centered at `(512, 490)` — top-left origin at `(221, 425)`
- Fill: `#0a0a0a` (near-black, slightly off black for depth)
- Border: 1.5px stroke, gradient from `rgba(180,140,255,0.6)` → `rgba(80,140,255,0.6)` (left to right)
- Inner shadow: `0 0 18px rgba(140, 100, 255, 0.4)` inset

### 4. Pill Inner Glow (subtle highlight)
- Thin horizontal highlight bar near top edge of pill
- Shape: Rounded rect, `520px × 4px`, corner radius `2px`
- Position: `(252, 432)` — 7px from top inner edge
- Fill: linear gradient left→right: `rgba(255,255,255,0.18)` → `rgba(255,255,255,0.04)`

### 5. Widget Icons (inside the pill, horizontally distributed)

Total usable pill interior: `~520px wide × 90px tall`, centered at `(512, 490)`

Lay out 3 icon clusters evenly spaced, each in a `120px` slot:

#### Widget A — Music Note (leftmost, centered at x=330)
- Symbol: Eighth note `♪` or two-beam note
- Size: `44px`
- Color: `#1DB954` (Spotify green) with a faint green glow `0 0 12px rgba(29,185,84,0.7)`
- Position center: `(330, 490)`

#### Widget B — Sun / Weather (center, at x=512)
- Symbol: Stylized sun — circle `20px` radius + 8 ray lines extending `12px`, 45° spaced
- Main circle fill: `#FFD60A` (iOS yellow)
- Rays: same yellow, 2px stroke, rounded caps
- Outer glow: `0 0 14px rgba(255,214,10,0.65)`
- Position center: `(512, 490)`

#### Widget C — Calendar (rightmost, centered at x=694)
- Shape: Rounded square `46×46px`, corner radius `8px`
- Fill: `#FF3B30` (iOS red) top strip `46×14px` (header), `#FFFFFF` body `46×32px`
- Header text: `MON` in white, `SF Pro` or `Helvetica Neue`, Bold, 9px
- Body text: Day number `16`, Bold, 20px, `#1C1C1E`
- Position center: `(694, 490)`

---

## Typography (if any wordmark is added — optional)
- Font: SF Pro Display or Helvetica Neue Thin
- Text: `top notch` (lowercase)
- Size: `48px`
- Color: `rgba(255,255,255,0.55)`
- Position: `(512, 622)` — 132px below pill center
- Letter spacing: `+0.12em`
- This layer is OPTIONAL — omit if the icon looks cleaner without it

---

## Color Palette
| Name | Hex | Usage |
|---|---|---|
| Background | `#000000` | Canvas |
| Near-black | `#0a0a0a` | Pill fill |
| Violet glow | `#7828FF` | Outer glow center |
| Indigo glow | `#3C64FF` | Outer glow edge |
| Pill border L | `#B48CFF` | Pill stroke left |
| Pill border R | `#508CFF` | Pill stroke right |
| Spotify green | `#1DB954` | Music icon |
| Sun yellow | `#FFD60A` | Weather icon |
| Calendar red | `#FF3B30` | Calendar header |
| White | `#FFFFFF` | Calendar body, highlights |
| Dark text | `#1C1C1E` | Calendar day number |

---

## Recommended Design Tools

### Option A: Figma (recommended)
1. New frame `1024×1024`, fill `#000000`
2. Use "Effects > Radial Gradient" for the glow layer
3. Draw pill with rounded rectangle tool
4. Add SF Symbols or draw icons manually
5. Export as PNG at `1x` → `AppIcon.png`

### Option B: Sketch
- Same approach; use "Shared Styles" for consistent glow effects

### Option C: Adobe Illustrator
- Artboard 1024×1024, export as PNG-24 with no background

### Option D: Pixelmator Pro (macOS native)
- Best for glow/blur effects on macOS

---

## Export Settings

### App Store submission (required)
| File | Size | Format | Notes |
|---|---|---|---|
| `AppIcon.png` | 1024×1024 | PNG-24, no alpha | Required by App Store Connect |

### Xcode asset catalog sizes (generated from 1024×1024 source)
Use `sips` or Xcode's automatic downscaling. Manual sizes if needed:

| Filename | Size | Scale | Usage |
|---|---|---|---|
| `AppIcon_16.png` | 16×16 | 1x | Menu bar, Finder small |
| `AppIcon_32.png` | 32×32 | 1x | Finder |
| `AppIcon_64.png` | 32×32 | 2x (Retina) | Finder Retina |
| `AppIcon_128.png` | 128×128 | 1x | Launchpad |
| `AppIcon_256.png` | 256×256 | 1x / 128@2x | Spotlight |
| `AppIcon_512.png` | 512×512 | 1x | Dock large |
| `AppIcon_1024.png` | 1024×1024 | 2x (512@2x) | App Store |

### Quick resize command (Terminal, once you have AppIcon.png)
```bash
cd /Users/iamabillionaire/Downloads/topnotch/MyDynamicIsland/Assets.xcassets/AppIcon.appiconset

for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size AppIcon.png --out AppIcon_${size}.png
done
```

---

## Placement in Xcode Project
- Drop `AppIcon.png` into:
  `/Users/iamabillionaire/Downloads/topnotch/MyDynamicIsland/Assets.xcassets/AppIcon.appiconset/`
- The `Contents.json` is already configured to use a single `AppIcon.png` at 1024×1024 (universal approach)
- Build and run — Xcode will use it automatically

---

## Visual Reference Description
Imagine the MacBook notch floating in space. It glows with an ethereal purple-indigo aura, as if powered. Inside it, three small bright widgets pulse with color — a green music note, a yellow sun, a red calendar tile. The whole composition sits on pure black, creating maximum contrast. Premium, minimal, instantly communicates what the app does.
