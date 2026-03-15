# TopNotch: Next-Level Strategy

> March 14, 2026 — YouTube player as the star, beautiful card UI, zero paid APIs

---

## The One Thing That Matters

**No notch app has an embedded YouTube player.** Every competitor only does media remote control — they show what's playing in your browser but can't play anything themselves. You already have the player. Now make it beautiful.

---

## App Store & Private APIs — Reality Check

Other notch apps **are** on the Mac App Store using the same techniques you use:

| App | On App Store? | What They Ship With |
|-----|:---:|---|
| **Alcove** | Yes | Media controls, HUD replacement, window level tricks |
| **Perch** | Yes | Media controls, weather, calendar, camera |
| **NotchDrop** | Yes | File shelf, clipboard, music controls |
| **NotchNest** | Yes | Calendar, music, camera, Pomodoro |
| **NotchBox** | Yes | Music with album art, file manager, AirDrop |

Your NSPanel at `.mainMenu + 1`, borderless/transparent windows, `NSScreen.safeAreaInsets`, `CGEventTap` — all fine for App Store. The WKWebView YouTube embed is fully compliant. Keep `MediaRemote.framework` and `SkyLight.framework` behind `#if APP_STORE_BUILD` as you already do.

---

## Zero Paid APIs

Every API used is free, no keys required:

| API | Cost | What It Does |
|-----|------|-------------|
| YouTube iframe embed (WKWebView) | Free | Video playback — fully ToS compliant |
| [Open-Meteo](https://open-meteo.com) | Free, no key | Weather data (you already use this) |
| macOS EventKit | Free (system) | Calendar events |
| MediaRemote.framework | Free (private) | Now Playing info from Spotify/Apple Music |
| [SponsorBlock](https://sponsor.ajay.app) | Free, no key | Skip sponsor segments |
| [Return YouTube Dislike](https://returnyoutubedislikeapi.com) | Free, no key | Like/dislike counts |

---

## The MVP Design — Card-Based Notch Expansion

Inspired by NotchNook's card layout: three rounded cards side-by-side in the expanded notch, each showing a focused widget. Dark backgrounds, rounded corners, clean typography.

### Layout Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│     ┌─ Home ─┐  ┌─ 📋 ─┐  ┌─ 📺 ─┐                              ▲ close  │
│     └────────┘  └──────┘  └──────┘                                         │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────────┐  ┌──────────────────────┐    │
│  │                  │  │                      │  │                      │    │
│  │   🎵 NOW PLAYING │  │   🌤 WEATHER         │  │   📺 YOUTUBE         │    │
│  │   Card           │  │   Card               │  │   Card               │    │
│  │                  │  │                      │  │                      │    │
│  └─────────────────┘  └─────────────────────┘  └──────────────────────┘    │
│                                                                             │
│                        •  •  •   (page dots)                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Visual Design Spec

**Overall feel**: iOS Dynamic Island meets macOS. Dark, glassy, minimal.

```
Background:         Pure black (#000000) — seamless with the notch
Card backgrounds:   #1C1C1E (dark gray) with 20pt corner radius, continuous
Card padding:       12pt internal, 10pt between cards
Typography:         SF Pro Rounded for numbers, SF Pro for text
Accent colors:      Red for YouTube, Blue for weather, Green for music
Corner radius:      Cards: 20pt  |  Buttons: 10pt  |  Notch: 8pt top, 20pt bottom
Shadow:             0 10 20 black/30% on expanded notch
```

**The three cards are NOT swipeable pages. They sit side-by-side, all visible at once** — just like the NotchNook screenshot. This is simpler and more scannable than your current paging deck.

### Card 1: Now Playing (Left)

```
┌──────────────────────┐
│  ┌──────┐            │
│  │album │  Sweet Boy  │
│  │ art  │  take       │
│  │      │            │
│  └──────┘            │
│   ◁    ▶︎⏸    ▷      │
└──────────────────────┘
```

**Details:**
- Album art: 48x48pt, 10pt corner radius, pulled from MediaRemote artwork data
- Title: 13pt semibold white, 1 line truncated
- Artist: 12pt medium white/60%, 1 line truncated
- Controls: SF Symbols `backward.fill`, `playpause.fill`, `forward.fill` — 14pt, tappable
- If nothing playing: show "No media" in muted text, or hide card

### Card 2: Weather (Center)

```
┌────────────────────────────┐
│                            │
│    24°C    ☁️              │
│    19°C  26°C              │
│                            │
│  📍 Eyup  • Mostly Cloudy  │
└────────────────────────────┘
```

**Details:**
- Temperature: 28pt bold SF Rounded, white
- Hi/Lo: 11pt medium white/50%
- Weather icon: SF Symbols (`cloud.fill`, `sun.max.fill`, etc.) — 22pt
- Location: 11pt medium white/60% with pin icon
- Condition: 11pt medium white/60%
- Data: Open-Meteo API (free, no key — you already use this via `NotchWeatherStore`)

### Card 3: YouTube (Right) — THE STAR

Two states: **Empty** and **Playing**

**Empty state:**
```
┌──────────────────────────┐
│                          │
│    📺  YouTube           │
│                          │
│  ┌──────────────────┐   │
│  │ Paste URL...      │   │
│  └──────────────────┘   │
│                          │
│   ▶ Play    📋 Paste     │
└──────────────────────────┘
```

- Text field: dark inset (`#2C2C2E`), 11pt, placeholder "youtube.com/watch?v=..."
- Play button: red pill, 11pt semibold
- Paste button: detects YouTube URL on clipboard, one-tap paste+play

**Playing state (compact in card):**
```
┌──────────────────────────┐
│  ┌──────┐  Video Title   │
│  │thumb │  Channel       │
│  │ nail │                │
│  └──────┘  ◁  ▶⏸  ▷    │
│                          │
│  ▒▒▒▒▒▒░░░ 1:23 / 5:42  │
│              ⊡ Pop Out   │
└──────────────────────────┘
```

- Thumbnail: 48x48pt, 8pt corner radius (grab from YouTube embed)
- Title: 12pt semibold white, 1 line truncated
- Channel: 11pt medium white/50%
- Controls: small play/pause, prev/next
- Progress: thin capsule scrubber (red fill on dark track)
- Pop-out button: opens the full floating video panel

**When user clicks "Pop Out":**
- Video launches in your existing `VideoPlayerPanel` — resizable, always on top, 16:9
- The card updates to show "Playing in window" with a "Bring Back" button
- Clicking "Bring Back" closes the panel and returns video to the notch inline player

### Notch Header Bar

```
┌─ 🏠 Home ─┐  ┌─ 📋 ─┐  ┌─ 📺 ─┐                                ▲
```

- Compact tab bar at the top of the expanded notch
- `Home` has icon + label (active state: white text on white/14% bg)
- Other tabs: icon-only (inactive: white/56%)
- Active tab has subtle rounded rect highlight
- Close/collapse button on the right (chevron up)

**BUT — reconsider tabs entirely.** The NotchNook screenshot shows all 3 cards at once, no tabs needed. The tab bar only makes sense when you have more cards than can fit. For the MVP with 3 cards, **show all 3 side by side** and remove the tab/paging system. This is simpler and matches the reference design.

### Three-Card Side-by-Side Layout (Recommended)

Replace your current paging `HStack` with a fixed 3-column layout:

```swift
HStack(spacing: 10) {
    nowPlayingCard
        .frame(maxWidth: .infinity)
    weatherCard
        .frame(maxWidth: .infinity)
    youtubeCard
        .frame(maxWidth: .infinity)
}
.padding(.horizontal, 12)
```

Each card gets equal width (~160-170pt in a 540pt expansion). This is how NotchNook does it — all visible at a glance, no swiping needed.

When YouTube is playing inline (not popped out), the YouTube card can expand wider and the other two shrink:

```
┌───────────┐  ┌─────────┐  ┌───────────────────────────┐
│  Now      │  │ Weather │  │  ▶ YouTube Video            │
│  Playing  │  │  24°C   │  │  (wider, showing video)     │
└───────────┘  └─────────┘  └───────────────────────────┘
```

### Inline YouTube Player (Notch Video Mode)

When user taps "Play in Notch" instead of "Pop Out":
- The notch expands taller to accommodate a 16:9 video
- Video plays directly in the notch expansion area
- All 3 cards collapse into a thin control bar below the video:

```
┌────────────────────────────────────────────────────┐
│                                                    │
│              ┌──────────────────────┐              │
│              │                      │              │
│              │   YouTube Video      │              │
│              │   (WKWebView)        │              │
│              │                      │              │
│              └──────────────────────┘              │
│                                                    │
│  Video Title — Channel      ◁  ▶⏸  ▷   ⊡ Pop Out │
│  ▒▒▒▒▒▒▒▒▒░░░░░░░░  1:23 / 5:42                  │
└────────────────────────────────────────────────────┘
```

You already have `isShowingInlineYouTubePlayer` and `NotchInlineYouTubePlayerView`. This is the right pattern — keep it.

---

## Floating Video Panel — Best-in-Class

Your `VideoPlayerPanel` is the pop-out experience. Polish these details:

| Detail | Implementation |
|--------|---------------|
| **Smooth resize** | 16:9 aspect ratio enforced at all times via `contentAspectRatio` |
| **Corner snapping** | After drag ends, animate to nearest screen corner (16px margin) |
| **Size memory** | Persist position/size with `@AppStorage` (already done) |
| **Opacity fade** | 85% opacity when mouse leaves, 100% on hover |
| **Auto-hide controls** | Overlay controls appear on hover, fade after 2s idle |
| **Keyboard shortcuts** | Space = play/pause, ←→ = seek 5s, F = fullscreen, Esc = close |
| **Double-click** | Toggle fullscreen |
| **Window chrome** | No title bar, 12pt corner radius, subtle shadow |

### Controls Overlay (on hover)

```
┌────────────────────────────────────────┐
│                                        │
│            YouTube Video               │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │  ◁    ▶⏸    ▷    🔊 ▬▬▬   ⊡   │  │
│  │  ▒▒▒▒▒▒▒▒▒░░░░░  1:23 / 5:42   │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

- Semi-transparent black gradient at bottom
- Controls: prev, play/pause, next, volume slider, pop-back-to-notch button
- Scrubber bar with red progress on dark track
- Time display: current / total
- All controls fade in/out with 0.2s animation

---

## Enhanced Features (Free APIs, Direct Edition)

### SponsorBlock — Auto-Skip Sponsors

Free API, no key, no cost. Works with WKWebView.

```
GET https://sponsor.ajay.app/api/skipSegments?videoID={id}&categories=["sponsor"]
→ [{ "segment": [12.5, 45.2], "category": "sponsor", "actionType": "skip" }]
```

Poll playback time via JS bridge every 500ms. When inside a sponsor segment, seek forward. Show a brief toast: "Sponsor skipped →"

The scrubber bar can show sponsor segments as colored marks (yellow for self-promo, green for sponsor) so users see what was skipped.

### Return YouTube Dislike

Free API, no key.

```
GET https://returnyoutubedislikeapi.com/votes?videoId={id}
→ { "likes": 31885, "dislikes": 579, "viewCount": 3762293 }
```

Show as a small like/dislike bar in the controls overlay. Attribution link to returnyoutubedislike.com in settings.

---

## macOS 15.4 MediaRemote Fix

NotchNook and Boring Notch are broken on 15.4. Fix: [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — uses `/usr/bin/perl` as an entitled host process. No SIP disable. Direct edition only.

---

## What NOT to Build

| Skip This | Why |
|-----------|-----|
| File shelf / AirDrop | Complex, NotchNook's territory |
| AI chat | Gimmick |
| Custom widget SDK | Massive effort, tiny audience |
| System stats | Niche |
| Pomodoro timer | Dozens of apps do this |
| Camera mirror | Novelty, used once |
| Clipboard manager | Paste, Maccy exist |
| Screen recording | Unrelated to core value |

**The MVP is 3 cards**: Now Playing, Weather, YouTube. That's it.

---

## Competitor Weaknesses

| Competitor | Their Problem | Your Advantage |
|-----------|--------------|----------------|
| **NotchNook** | Battery drain, crashes on 15.4, $25 | Lightweight, YouTube player, cheaper |
| **Boring Notch** | MediaRemote broken, rough UI | Polished design, video playback |
| **Alcove** | No YouTube, $17 | YouTube at lower price |
| **MediaMate** | HUD only, no expansion | Full notch experience |

---

## Distribution & Pricing

**App Store**: Free with $4.99 Pro unlock
**Direct**: $14.99 one-time (includes SponsorBlock, MediaRemote, lock screen)

---

## Implementation Priority

### Phase 1: Three-Card Layout + YouTube Polish
1. Replace paging deck with 3 side-by-side cards (Now Playing, Weather, YouTube)
2. Style cards to match the dark rounded design (20pt radius, #1C1C1E bg)
3. Polish floating video panel (corner snap, opacity fade, auto-hide controls, keyboard shortcuts)
4. Smooth URL detection → play flow

### Phase 2: SponsorBlock + Dislikes
1. SponsorBlock integration (JS bridge time polling, auto-skip)
2. Return YouTube Dislike display
3. Sponsor segment markers on scrubber

### Phase 3: Ship
1. Notarize Direct edition
2. App Store submission
3. DMG + website
4. Product Hunt launch

---

## Key References

| Resource | What It's For | Cost |
|----------|--------------|------|
| [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) | WKWebView iframe wrapper | Free |
| [Open-Meteo API](https://open-meteo.com) | Weather data | Free, no key |
| [SponsorBlock API](https://wiki.sponsor.ajay.app/w/API_Docs) | Skip sponsors | Free, no key |
| [Return YouTube Dislike](https://returnyoutubedislikeapi.com/docs) | Show dislikes | Free, no key |
| [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | Fix MediaRemote 15.4+ | Free |
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | Reference architecture | Free |

---

## TL;DR

1. **3 cards side-by-side**: Now Playing, Weather, YouTube — all visible at once, no swiping
2. **YouTube player is THE feature** — paste URL, play in notch or pop out to floating panel
3. **Zero paid APIs** — YouTube iframe, Open-Meteo, SponsorBlock, Return YT Dislike all free
4. **Polish the floating panel** — corner snap, auto-hide controls, keyboard shortcuts, opacity fade
5. **Don't overcomplicate** — 3 cards, beautiful design, works perfectly. Ship it.
