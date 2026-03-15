# YouTube Video Player for macOS — Comprehensive Research Document

> Research compiled March 2026 for TopNotch (macOS notch/Dynamic Island app)

---

## Table of Contents

1. [YouTube Playback Methods for macOS](#1-youtube-playback-methods-for-macos)
2. [How Existing Apps Play YouTube](#2-how-existing-apps-play-youtube)
3. [Technical Implementation Details](#3-technical-implementation-details)
4. [Mini-Player / Floating Player Patterns](#4-mini-player--floating-player-patterns)
5. [Legal and Policy Considerations](#5-legal-and-policy-considerations)
6. [SponsorBlock, Return YouTube Dislike, DeArrow Integration](#6-sponsorblock-return-youtube-dislike-dearrow-integration)
7. [Recommended Architecture for TopNotch](#7-recommended-architecture-for-topnotch)

---

## 1. YouTube Playback Methods for macOS

### 1A. WKWebView with YouTube iFrame API

**How it works:** Embed YouTube's official iframe player inside a WKWebView. The iframe API provides JavaScript hooks for play/pause/seek/volume, and SwiftUI communicates with the player via `evaluateJavaScript` and `WKScriptMessageHandler`.

**Pros:**
- Fully compliant with YouTube ToS (uses official embed player)
- No signature decryption or anti-bot circumvention needed
- Supports all video types: regular, live streams, premieres, age-restricted (with login)
- Ads play normally (YouTube is happy)
- Handles DRM/Widevine content automatically
- No maintenance burden when YouTube changes internal APIs
- App Store safe

**Cons:**
- Limited UI customization (YouTube's chrome is baked in)
- Higher memory/CPU than native AVPlayer
- Requires internet (no offline)
- Cannot extract audio-only streams for background playback
- Cannot integrate SponsorBlock (no access to underlying stream timeline at segment level)
- WKWebView works on macOS but requires `WKWebViewConfiguration` with `allowsInlineMediaPlayback = true`
- Minimum view size constraints from YouTube (200x200px)

**Key Swift Libraries:**

| Library | GitHub | Notes |
|---------|--------|-------|
| **YouTubePlayerKit** (SvenTiigi) | [github.com/SvenTiigi/YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) | Best option. SwiftUI-native, supports macOS 12+, async API, full iFrame API access, fullscreen/volume observation. Wraps WKWebView. |
| **YoutubePlayer-in-WKWebView** (hmhv) | [github.com/hmhv/YoutubePlayer-in-WKWebView](https://github.com/hmhv/YoutubePlayer-in-WKWebView) | Mature UIKit-based, BuzzFeed fork also available. iOS-focused but adaptable. |
| **Unofficial SwiftUI Wrapper** | [github.com/CongLeSolutionX/Unofficial-SwiftUI-Wrapper-for-YouTube-IFrame-Player-API](https://github.com/CongLeSolutionX/Unofficial-SwiftUI-Wrapper-for-YouTube-IFrame-Player-API) | Lightweight SwiftUI bridge to YouTube iframe API. |

**YouTubePlayerKit Usage (recommended):**
```swift
import YouTubePlayerKit

// Initialize with video ID and parameters
let player = YouTubePlayer(
    source: .video(id: "dQw4w9WgXcQ"),
    configuration: .init(autoPlay: true)
)

// SwiftUI View
YouTubePlayerView(player)
    .frame(width: 480, height: 270)

// Programmatic control
await player.play()
await player.pause()
await player.seek(to: 30, allowSeekAhead: true)
```

When targeting macOS/Mac Catalyst: enable "Outgoing Connections (Client)" in Signing & Capabilities.

---

### 1B. yt-dlp for Extracting Direct Video URLs + AVPlayer

**How it works:** Use yt-dlp (command-line tool) to resolve a YouTube URL into direct `googlevideo.com/videoplayback?...` URLs, then feed those into AVPlayer for native playback.

**yt-dlp key commands:**
```bash
# Get direct stream URL without downloading
yt-dlp -g -f "bestvideo[height<=1080]+bestaudio/best" "https://youtube.com/watch?v=VIDEO_ID"

# Get JSON metadata + all format URLs
yt-dlp -j "https://youtube.com/watch?v=VIDEO_ID"

# Audio only
yt-dlp -g -f "bestaudio" "https://youtube.com/watch?v=VIDEO_ID"

# Live stream HLS URL
yt-dlp -g -f "best" "https://youtube.com/watch?v=LIVE_ID"
```

**Bundling yt-dlp in a macOS app:**

Option A — Bundle the binary:
- Download `yt-dlp_macos` from [github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)
- Add to app bundle's Resources folder
- Launch via `Process()` in Swift:
```swift
let process = Process()
process.executableURL = Bundle.main.url(forResource: "yt-dlp_macos", withExtension: nil)
process.arguments = ["-g", "-f", "best", videoURL]
let pipe = Pipe()
process.standardOutput = pipe
try process.run()
process.waitUntilExit()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let directURL = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
```

Option B — Download on first launch (recommended by ClipSnag developer):
- Download yt-dlp + ffmpeg on first app launch
- Store in `~/Library/Application Support/YourApp/`
- Avoids bundling license issues (yt-dlp is Unlicense, ffmpeg is LGPL/GPL)
- Remove `com.apple.quarantine` xattr after download to avoid Gatekeeper issues
- Ref: [arkadiuszchmura.com/posts/things-i-learned-while-building-a-yt-dlp-wrapper/](https://arkadiuszchmura.com/posts/things-i-learned-while-building-a-yt-dlp-wrapper/)

**Swift Package (YoutubeDL-iOS):**
- [github.com/kewlbear/YoutubeDL-iOS](https://github.com/kewlbear/YoutubeDL-iOS) — Embeds Python + yt-dlp as a Swift package
- **NOT App Store safe** — Apple rejects apps that download YouTube videos

**Existing macOS GUI wrappers:**
- **MacYTDL**: [github.com/section83/MacYTDL](https://github.com/section83/MacYTDL) — Downloads yt-dlp and ffmpeg, manages updates

**Pros:**
- Full native AVPlayer playback (low CPU, great performance)
- Access to all quality levels including 4K, 8K
- Audio-only extraction for background playback
- Can integrate with MPNowPlayingInfoCenter
- Full control over playback UI
- Works with SponsorBlock (you control the timeline)

**Cons:**
- Violates YouTube ToS
- yt-dlp needs frequent updates as YouTube changes ciphers
- App Store will reject if downloading is the primary feature
- YouTube's anti-bot (PO Token/BotGuard) increasingly blocks automated access
- Direct URLs expire (~6 hours)
- Sandboxed apps cannot easily run external processes

---

### 1C. Invidious API

**What it is:** Open-source alternative YouTube frontend written in Crystal. Provides a REST API that returns video metadata and direct stream URLs without requiring a YouTube API key.

**API Base:** Any public instance, e.g., `https://vid.puffyan.us` (instance list at [api.invidious.io](https://api.invidious.io))

**Key Endpoint — Get Video Streams:**
```
GET /api/v1/videos/{videoId}?local=true
```

Response includes:
```json
{
  "title": "Video Title",
  "videoId": "dQw4w9WgXcQ",
  "lengthSeconds": 212,
  "formatStreams": [
    {
      "url": "https://...",
      "itag": "22",
      "type": "video/mp4; codecs=\"avc1.64001F, mp4a.40.2\"",
      "quality": "hd720",
      "qualityLabel": "720p",
      "container": "mp4",
      "encoding": "h264",
      "resolution": "1280x720"
    }
  ],
  "adaptiveFormats": [
    {
      "url": "https://...",
      "itag": "137",
      "type": "video/mp4; codecs=\"avc1.640028\"",
      "quality": "hd1080",
      "bitrate": "4000000",
      "container": "mp4",
      "encoding": "h264",
      "resolution": "1920x1080"
    },
    {
      "url": "https://...",
      "itag": "140",
      "type": "audio/mp4; codecs=\"mp4a.40.2\"",
      "bitrate": "128000",
      "container": "m4a",
      "encoding": "aac"
    }
  ],
  "captions": [...],
  "recommendedVideos": [...]
}
```

**Key details:**
- `formatStreams` = combined audio+video (360p, 720p), ready to play in AVPlayer
- `adaptiveFormats` = separate audio and video streams (requires merging for high quality, or play video-only + audio-only simultaneously)
- `?local=true` proxies the stream URL through the Invidious instance (avoids CORS/IP issues)
- Streams can contain either `url` (direct) or `signatureCipher` (needs decryption — handled by the instance)

**Other useful endpoints:**
```
GET /api/v1/search?q=query          # Search videos
GET /api/v1/trending                # Trending
GET /api/v1/channels/{channelId}    # Channel info
GET /api/v1/playlists/{playlistId}  # Playlist
```

**Pros:**
- No API key needed
- Returns direct playable URLs
- Privacy-focused (no Google tracking)
- Supports search, trending, channels, playlists
- Can self-host for reliability

**Cons:**
- Public instances are unreliable (frequently go down, rate limited)
- YouTube actively blocks Invidious instances
- Invidious now requires **invidious-companion** (a separate service) for stream decryption since late 2024
- Self-hosting is complex (Crystal lang + PostgreSQL + companion)
- Still violates YouTube ToS

---

### 1D. Piped API

**What it is:** Privacy-friendly YouTube frontend. Returns JSON with stream URLs. Architecture: backend + frontend + proxy (3 separate services).

**API Base:** `https://pipedapi.kavin.rocks` (or any public instance)

**Key Endpoint — Get Streams:**
```
GET /streams/{videoId}
```

Response includes:
```json
{
  "title": "Video Title",
  "uploader": "Channel Name",
  "duration": 212,
  "dashUrl": "https://...",  // Use if not null for OTF streams
  "audioStreams": [
    {
      "url": "https://pipedproxy-bom.kavin.rocks/videoplayback?...",
      "bitrate": 128000,
      "codec": "mp4a.40.5",
      "format": "M4A",
      "quality": "128 kbps",
      "mimeType": "audio/mp4",
      "videoOnly": false
    }
  ],
  "videoStreams": [
    {
      "url": "https://pipedproxy.../videoplayback?...",
      "bitrate": 4000000,
      "codec": "avc1.640028",
      "format": "MPEG_4",
      "quality": "1080p",
      "mimeType": "video/mp4",
      "videoOnly": true
    }
  ],
  "relatedStreams": [...]
}
```

**Other endpoints:**
```
GET /search?q=query&filter=videos    # Search
GET /trending?region=US              # Trending
GET /channel/{channelId}             # Channel
GET /playlists/{playlistId}          # Playlist
GET /sponsors/{videoId}?category=["sponsor"] # SponsorBlock built-in!
```

**Pros:**
- No API key needed, no authentication
- Stream URLs are pre-proxied (no CORS issues)
- Built-in SponsorBlock support
- Clean, well-documented API
- Separate audio and video streams clearly labeled
- DASH manifest URL provided

**Cons:**
- Public instances subject to rate limiting and downtime
- Proxy adds latency
- YouTube increasingly blocks Piped instances
- Self-hosting requires 3 services
- Still violates YouTube ToS

---

### 1E. NewPipe Extractor

**What it is:** Java library used by the NewPipe Android app. Extracts stream data from YouTube (and SoundCloud, PeerTube, Bandcamp, media.ccc.de) by scraping web interfaces.

**Repository:** [github.com/TeamNewPipe/NewPipeExtractor](https://github.com/TeamNewPipe/NewPipeExtractor)

**For macOS/Swift:** Not directly usable. Options:
1. Port extraction logic to Swift (massive effort, constant maintenance)
2. Run via JVM bridge (impractical for a macOS app)
3. Use as reference for understanding YouTube's internal stream extraction

**Key class:** `YoutubeStreamExtractor.java` — handles cipher decryption, stream URL construction, signature handling.

**No Swift equivalent exists.** The closest are:
- alexeichhorn's YouTubeKit (see 1F below)
- b5i's YouTubeKit (see 1G below)

---

### 1F. YouTubeKit by alexeichhorn (Direct URL Extraction in Swift)

**Repository:** [github.com/alexeichhorn/YouTubeKit](https://github.com/alexeichhorn/YouTubeKit)

**What it does:** Pure Swift library that extracts direct video/audio URLs from YouTube. Equivalent to what yt-dlp does, but as a native Swift package.

**Platforms:** iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+, visionOS

**Usage:**
```swift
import YouTubeKit

let youtube = YouTube(videoID: "dQw4w9WgXcQ")

// Get all streams
let streams = try await youtube.streams

// Best video stream
let bestVideo = streams
    .filter { $0.includesVideoTrack }
    .highestResolutionStream()

// Best audio stream
let bestAudio = streams
    .filter { $0.includesAudioTrack && !$0.includesVideoTrack }
    .highestAudioBitrateStream()

// Play in AVPlayer
let player = AVPlayer(url: bestVideo!.url)
```

**Key technical details:**
- Uses the same JavaScript-based cipher solver as yt-dlp for NSIG/SIG decryption
- Includes a **remote fallback** — when local extraction fails, switches to a Cloudflare Worker running youtube-dl (open-source server)
- Handles throttling parameter (n-parameter) decryption
- Test suite covers Cipher, NSIG, Signature, and Playability

**Pros:**
- Pure Swift, no external binary needed
- Direct AVPlayer integration
- Supports audio-only extraction
- Remote fallback for resilience
- Active maintenance

**Cons:**
- Violates YouTube ToS
- YouTube cipher changes require library updates
- App Store rejection risk
- Does not handle PO Token (BotGuard) — may fail for some videos
- Limited to video extraction (no search, channels, playlists)

---

### 1G. YouTubeKit by b5i (YouTube Internal API in Swift)

**Repository:** [github.com/b5i/YouTubeKit](https://github.com/b5i/YouTubeKit)

**What it does:** Interacts with YouTube's internal API (InnerTube) in Swift **without any API key**. Provides search, channel info, playlists, video info, subscriptions, library access.

**Features:**
- Search videos
- Get channel info (videos, shorts, directs, playlists) with continuation
- Get playlist contents with continuation
- Account operations (subscriptions, library, history)
- No API key required

**Pros:**
- No API key, no quota limits
- Comprehensive YouTube data access
- MIT licensed

**Cons:**
- Uses internal InnerTube API (undocumented, can break)
- Unclear if it extracts playable stream URLs
- Smaller community (114 stars)

---

### 1H. Google YouTube Data API v3

**What it is:** Official Google API for YouTube metadata. Does NOT provide stream URLs.

**Quota:** 10,000 units/day (free tier). Search = 100 units. Video details = 1 unit.

**Useful for:**
- Video metadata (title, description, thumbnails, duration, view count)
- Search
- Channel info
- Playlist contents
- Comments

**NOT useful for:** Actual video playback (no stream URLs provided).

**Best combined with:** WKWebView iframe embed (use Data API for metadata, iframe for playback).

---

### 1I. YouTube InnerTube API (Direct)

**What it is:** YouTube's private internal API used by all official clients (web, iOS, Android, TV).

**Key endpoint:**
```
POST https://www.youtube.com/youtubei/v1/player
Content-Type: application/json

{
  "videoId": "VIDEO_ID",
  "context": {
    "client": {
      "clientName": "WEB",
      "clientVersion": "2.20240101.00.00"
    }
  }
}
```

**Returns:** `streamingData` with `formats` and `adaptiveFormats` containing URLs (or `signatureCipher` requiring decryption).

**Libraries:**
- **YouTube.js** (JavaScript): [github.com/LuanRT/YouTube.js](https://github.com/LuanRT/YouTube.js) — Most comprehensive InnerTube client. Handles cipher decryption, generates MPEG-DASH manifests.
- **innertube** (Python): [github.com/tombulled/innertube](https://github.com/tombulled/innertube)
- **Unofficial docs**: [github.com/davidzeng0/innertube](https://github.com/davidzeng0/innertube)

**PO Token requirement (since Aug 2024):**
- YouTube now requires a Proof of Origin token for web client stream access
- Generated by BotGuard (proprietary JS VM)
- Without PO Token: streams return 403
- Tool for generating: [github.com/LuanRT/BgUtils](https://github.com/LuanRT/BgUtils)
- PO Tokens are bound to video ID or visitor session, expire in ~12 hours
- yt-dlp has a plugin system for PO Token providers

**Important:** No native Swift InnerTube client exists. Would need to be built from scratch using YouTube.js as reference.

---

## 2. How Existing Apps Play YouTube

### 2A. IINA (macOS Video Player)

**Repository:** [github.com/iina/iina](https://github.com/iina/iina)

**How it handles YouTube:**
- Built on **mpv** (video player engine)
- mpv has a built-in `ytdl_hook.lua` script
- This script automatically detects YouTube URLs and calls yt-dlp/youtube-dl to resolve them
- youtube-dl/yt-dlp is enabled by default in Preferences > Network
- Users can configure yt-dlp as a drop-in replacement: `ln -s /opt/homebrew/bin/yt-dlp /opt/homebrew/bin/youtube-dl`
- Custom options passed via mpv's `ytdl-raw-options`
- IINA does NOT bundle yt-dlp — it expects it to be installed system-wide

**Architecture:** IINA > mpv > ytdl_hook.lua > yt-dlp > direct URL > mpv playback

---

### 2B. NotchNook

**Website:** [lo.cafe/notchnook](https://lo.cafe/notchnook)

**How it works:**
- Expands from the MacBook notch, showing a "Nook" with widgets
- Media control widget shows album art, playback controls, waveform visualization
- Detects any media playing on the Mac (including YouTube in browser) via macOS Now Playing APIs
- Does NOT embed its own YouTube player — it acts as a remote control for whatever is playing
- Offers quick-launch buttons for Apple Music and YouTube (opens in browser)
- HUD replacement moves volume/brightness controls into notch area
- Heavily customizable: open behavior (click/hover/swipe), padding, transparency

**Key insight for TopNotch:** NotchNook's YouTube "support" is just media remote control, not an embedded player. To differentiate, TopNotch should embed an actual player.

---

### 2C. TheBoringNotch (Open Source)

**Repository:** [github.com/TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch/)

**How it works:**
- Open-source Dynamic Island for MacBook notch
- SwiftUI-based, less than 2% CPU usage
- Features: media controls, battery indicator, calendar, file shelf (AirDrop), HUD replacement
- Music control: album art, playback controls, real-time audio visualizer with dynamic color adaptation
- Uses macOS Now Playing APIs to detect media playback
- Does NOT embed a video player
- Requires macOS Ventura+, optimized for MacBook Pro 14"/16" (2021+)

**Key source code insights:**
- Uses SwiftUI for all UI
- Notch panel uses custom window positioning aligned to screen notch area
- `NSScreen.safeAreaInsets.top != 0` to detect notch presence
- Media playback detected via system APIs, not embedded

---

### 2D. DynamicNotchKit

**Repository:** [github.com/MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)

**What it is:** Swift Package that provides tools to integrate macOS apps with the notch.

**Features:**
- Display SwiftUI content from the macOS notch
- `DynamicNotch` class for custom content
- `DynamicNotchInfo` for general information display
- Expansion animations (stretchy, fluid transitions)
- States: hidden, compact, expanded
- **Supports Macs without a notch** (universal compatibility)
- All UI handled by SwiftUI

**Usage for a video player:** Could be used to host a mini video player view in the notch expansion area.

---

### 2E. Brave Browser Mini-Player

**How it works:**
- Uses the W3C Picture-in-Picture API
- User clicks PiP button in address bar or right-clicks video twice > "Picture in Picture"
- Video docks to a corner in a floating OS-level window
- Window is resizable, movable, stays on top
- Video keeps playing even if browser is minimized
- Uses macOS native PiP (AVPictureInPictureController under the hood via Chromium)

---

### 2F. Yattee (Open Source YouTube Client — Swift)

**Repository:** [github.com/yattee/yattee](https://github.com/yattee/yattee)

**This is the most relevant reference app for TopNotch.**

**Architecture:**
- Written entirely in Swift/SwiftUI
- Two player backends: **AVPlayer** and **mpv** (via MPVKit fork)
- Data sources: **Invidious API** and **Piped API** (user can choose)
- No official YouTube API used
- MPVKit: [github.com/yattee](https://github.com/orgs/yattee/repositories) (forked mpv for Apple platforms)

**How video playback works:**
1. User searches/browses via Invidious or Piped API
2. App gets stream URLs from API response
3. Best stream auto-selected based on quality preferences
4. Plays via mpv (primary) or AVPlayer (fallback for MP4/AVC1)

**Features relevant to TopNotch:**
- SponsorBlock integration (automatic skip)
- Return YouTube Dislike integration
- Background audio playback
- Multiple quality selection
- Picture-in-Picture support
- iCloud sync
- Video downloads
- Multi-source support (mix Invidious for browsing, Piped for playback)

**Version 2.0 rewrite:** Complete rewrite with MPV-based playback engine, redesigned navigation, customizable player controls and gestures.

**License:** AGPL-3.0 (copyleft — derivative works must also be AGPL)

---

### 2G. FreeTube (Electron-based)

**Repository:** [github.com/FreeTubeApp/FreeTube](https://github.com/FreeTubeApp/FreeTube)

**Architecture:**
- Electron app (cross-platform: Windows, Mac, Linux)
- Uses **youtubei.js** (YouTube.js by LuanRT) for "Local API" extraction
- Also supports Invidious API as alternative backend

**How Local API extraction works (relevant technical details):**
1. Uses YouTube's InnerTube API via youtubei.js
2. Generates PO Token (Proof of Origin) for authentication using BotGuard in a sandboxed iframe
3. Custom `eval` implementation extracts n-sig and sig decipher functions from YouTube's player JS
4. Executes cipher functions in sandboxed iframe (security)
5. Falls back through multiple client types:
   - WEB client (default) with PoToken
   - MWEB client (fallback for SABR-only responses)
   - WEB_EMBEDDED client (bypasses age restrictions)

**Key insight:** Even in JavaScript/Electron, handling YouTube's anti-bot is complex. A Swift implementation would be even harder.

---

## 3. Technical Implementation Details

### 3A. YouTube's Anti-Bot System (PO Token / BotGuard)

Since August 2024, YouTube requires PO (Proof of Origin) tokens for web-client stream access.

**How it works:**
1. YouTube serves a BotGuard challenge (obfuscated JavaScript VM)
2. Client must execute the challenge to generate a PO Token
3. Token is sent with `/player` API requests
4. Without valid PO Token: streams return HTTP 403
5. Tokens are bound to: visitor ID/session AND sometimes video ID
6. Tokens expire in ~12 hours

**PO Token generation tools:**
- [github.com/LuanRT/BgUtils](https://github.com/LuanRT/BgUtils) — Node.js utility
- [codeberg.org/ThetaDev/rustypipe-botguard](https://codeberg.org/ThetaDev/rustypipe-botguard) — Rust implementation
- yt-dlp plugin: `bgutil-ytdlp-pot-provider`

**Impact on a Swift app:**
- Cannot easily generate PO Tokens natively in Swift
- Options: (a) run a companion Node.js/Rust process, (b) use WKWebView to execute BotGuard JS, (c) rely on Invidious/Piped which handle this server-side

---

### 3B. NSIG / SIG Cipher Decryption

YouTube obfuscates stream URLs with two cipher parameters:

**Signature (sig):**
- Stream URLs contain `signatureCipher` instead of `url`
- Must extract and apply a decipher function from YouTube's `base.js` player code
- Decipher function changes with each player version

**N-parameter (nsig):**
- Throttling parameter in stream URLs
- Must be decrypted to avoid rate-limiting to ~50KB/s
- More complex than sig decryption
- Changes frequently

**How yt-dlp handles it:**
- Downloads YouTube's `base.js` player code
- Extracts the cipher functions using regex
- Executes them via a JavaScript interpreter (built-in to Python via `subprocess`)
- Caches results per player version

**How alexeichhorn's YouTubeKit handles it:**
- Uses the same battle-tested JavaScript solver approach as yt-dlp
- Includes remote fallback to Cloudflare Worker when local extraction fails

**For a pure Swift implementation:** Would need to:
1. Fetch YouTube's `base.js`
2. Extract cipher function code via regex
3. Execute JavaScript (via `JSContext` from JavaScriptCore framework)
4. Apply deciphered values to stream URLs

This is fragile and requires constant maintenance.

---

### 3C. YouTube Livestream Playback

**How livestreams work:**
- YouTube serves livestreams as HLS (HTTP Live Streaming) `.m3u8` playlists
- Can be extracted via yt-dlp: `yt-dlp -g -f best "https://youtube.com/watch?v=LIVE_ID"`
- Returns an HLS manifest URL
- AVPlayer natively supports HLS playback

**Chrome extension approach:** Intercept network requests to find `.m3u8` URLs loaded by YouTube's player.

**Via Invidious/Piped:** APIs return HLS URLs for live content in the stream response.

---

### 3D. HLS vs DASH for YouTube

**YouTube's approach:**
- **Desktop/Android:** Primarily DASH (MPD manifests) — supports VP9, AV1 codecs
- **iOS/Safari:** HLS (`.m3u8`) — required for Apple ecosystem compatibility
- YouTube dynamically selects protocol based on client

**For macOS AVPlayer:**
- AVPlayer natively supports HLS
- DASH requires custom implementation or mpv
- Piped API provides a `dashUrl` field with DASH manifest
- Invidious `adaptiveFormats` are essentially DASH segments

**Recommendation:** Use HLS when available (simpler with AVPlayer), fall back to individual format URLs from API responses.

---

### 3E. Background Audio Playback from YouTube

**Requirements:**
1. Extract audio-only stream URL (via yt-dlp, Invidious, Piped, or YouTubeKit)
2. Play via AVPlayer (not WKWebView — webview audio stops when window is hidden)
3. Configure AVAudioSession:
```swift
// macOS doesn't use AVAudioSession the same way as iOS
// But MPNowPlayingInfoCenter works on macOS 10.12.1+
```

**macOS-specific note:** macOS does not have the same background audio restrictions as iOS. Audio from AVPlayer continues playing when the app is in the background. However, you MUST update `MPNowPlayingInfoCenter` manually (macOS can't infer state from AVAudioSession like iOS can).

---

### 3F. MPNowPlayingInfoCenter Integration

```swift
import MediaPlayer

// Set now playing info
let nowPlayingInfo: [String: Any] = [
    MPMediaItemPropertyTitle: "Video Title",
    MPMediaItemPropertyArtist: "Channel Name",
    MPMediaItemPropertyPlaybackDuration: 212.0,
    MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
    MPNowPlayingInfoPropertyPlaybackRate: 1.0
]
MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

// Register for remote commands (play/pause/seek from keyboard, Touch Bar, Control Center)
let commandCenter = MPRemoteCommandCenter.shared()

commandCenter.playCommand.addTarget { _ in
    player.play()
    return .success
}

commandCenter.pauseCommand.addTarget { _ in
    player.pause()
    return .success
}

commandCenter.skipForwardCommand.preferredIntervals = [15]
commandCenter.skipForwardCommand.addTarget { event in
    let interval = (event as! MPSkipIntervalCommandEvent).interval
    let newTime = player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1)
    player.seek(to: newTime)
    return .success
}
```

**macOS benefit:** This integrates with keyboard media keys and Touch Bar on supported hardware.

---

### 3G. Age-Restricted Content

**Official approach:** Requires Google account sign-in.

**Workarounds used by third-party apps:**
- FreeTube uses `WEB_EMBEDDED` client type via InnerTube API (bypasses some restrictions)
- Invidious/Piped instances handle age restriction server-side with their own cookies/sessions
- yt-dlp supports `--cookies-from-browser` to use existing browser session

**For TopNotch:** If using WKWebView iframe embed, age-restricted content works if user is signed into Google in the webview. If using direct extraction, need one of the workaround approaches.

---

## 4. Mini-Player / Floating Player Patterns

### 4A. macOS Picture-in-Picture (AVPictureInPictureController)

```swift
import AVKit

// Requires AVPlayerLayer
let playerLayer = AVPlayerLayer(player: avPlayer)

// Check if PiP is supported
if AVPictureInPictureController.isPictureInPictureSupported() {
    let pipController = AVPictureInPictureController(playerLayer: playerLayer)
    pipController?.delegate = self

    // Start PiP (must be triggered by user action for App Store approval)
    pipController?.startPictureInPicture()
}

// Delegate methods
extension ViewController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        // PiP started
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        // PiP stopped — restore inline player
    }
}
```

**Important:** PiP must be initiated by user action (App Review requirement). AVPictureInPictureController only works with AVPlayer content, NOT WKWebView content.

---

### 4B. Floating NSWindow / NSPanel (Always on Top)

```swift
// Option 1: NSWindow level
window.level = .floating  // Stays above normal windows
// Or for even higher priority:
window.level = .popUpMenu
window.level = .screenSaver  // Highest

// Option 2: Make visible on all Spaces
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

// Option 3: Custom NSPanel subclass
class FloatingVideoPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = contentView
        self.hasShadow = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
    }
}
```

**macOS 15+ SwiftUI approach:**
```swift
Window("Video Player", id: "video-player") {
    VideoPlayerView()
}
.windowLevel(.floating)
```

---

### 4C. Resizable Mini-Player with Corner Snapping

```swift
// Snap to screen corners after drag
func windowDidEndDragging() {
    guard let screen = window.screen else { return }
    let screenFrame = screen.visibleFrame
    let windowFrame = window.frame

    let centerX = windowFrame.midX
    let centerY = windowFrame.midY
    let screenCenterX = screenFrame.midX
    let screenCenterY = screenFrame.midY

    var snapOrigin = windowFrame.origin
    let margin: CGFloat = 16

    // Snap to nearest corner
    if centerX < screenCenterX {
        snapOrigin.x = screenFrame.minX + margin
    } else {
        snapOrigin.x = screenFrame.maxX - windowFrame.width - margin
    }

    if centerY < screenCenterY {
        snapOrigin.y = screenFrame.minY + margin
    } else {
        snapOrigin.y = screenFrame.maxY - windowFrame.height - margin
    }

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window.animator().setFrameOrigin(snapOrigin)
    }
}

// Maintain aspect ratio during resize
func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let aspectRatio: CGFloat = 16.0 / 9.0
    let newHeight = frameSize.width / aspectRatio
    return NSSize(width: frameSize.width, height: newHeight)
}
```

---

### 4D. Video Player in Notch Expansion Panel

**How to make a video player work inside a notch expansion:**

1. **Detect notch:** `NSScreen.main?.safeAreaInsets.top != 0`
2. **Position window:** Align custom NSPanel to notch area using screen coordinates
3. **Expand animation:** Use DynamicNotchKit's fluid expansion or custom animation
4. **Embed player:** Place WKWebView (YouTubePlayerKit) or AVPlayerView inside the expanding panel
5. **Pop-out:** Allow user to detach video into a floating window

**Using DynamicNotchKit:**
```swift
import DynamicNotchKit

let notch = DynamicNotch(content: {
    YouTubePlayerView(player)
        .frame(width: 400, height: 225)
})

// Show expanded
notch.show(on: .main)

// Hide
notch.hide()
```

---

## 5. Legal and Policy Considerations

### 5A. YouTube Terms of Service

**Key restrictions:**
- You cannot access YouTube content through any means other than: (a) YouTube website, (b) Embeddable Player, (c) other explicitly authorized means
- You cannot modify, block, or build upon the Embeddable Player (including links back to YouTube)
- Cannot remove or block ads
- Cannot download content without explicit authorization

**API Developer Policies:**
- Services cannot restrict ads from playing
- Embedded players must be minimum 200x200px
- Cannot auto-play until visible
- Overlays on players are prohibited
- Mouse-overs cannot trigger user actions
- Violations: quota reduction, key revocation, account termination

### 5B. App Store Review

**Guideline 5.2.3 (Audio/Video Downloading):**
- Apps should not facilitate illegal file sharing
- Cannot save, convert, or download media from third-party sources (YouTube, SoundCloud, etc.) without explicit authorization

**Common rejection reasons:**
- Including libraries that enable YouTube streaming/downloading
- Providing unauthorized access to third-party streaming services

**How to get approved:**
1. Use the official YouTube iframe embed (WKWebView + YouTubePlayerKit)
2. Do NOT extract direct URLs or enable downloading
3. If using YouTube Data API: complete the YouTube API Services audit
4. Attach documentary evidence in App Review Information proving you have rights/permissions
5. Consider applying for YouTube API Audit and Quota Extension

**Safe approach for App Store:** WKWebView iframe embed is the only fully compliant method.

**Outside App Store (direct distribution):** All methods are technically viable. macOS apps distributed via DMG/website don't need App Store approval, only notarization.

### 5C. Open Source YouTube Player Apps and Their Approach

| App | Distribution | Approach | ToS Compliant? |
|-----|-------------|----------|----------------|
| **IINA** | DMG/Homebrew | mpv + yt-dlp | No |
| **Yattee** | Homebrew/GitHub | Invidious/Piped API | No |
| **FreeTube** | DMG/GitHub | youtubei.js (InnerTube) | No |
| **MacYTDL** | DMG | yt-dlp wrapper | No |
| **NotchNook** | App Store | Media remote only (no player) | Yes |
| **TheBoringNotch** | DMG/GitHub | Media remote only (no player) | Yes |

**Pattern:** All apps that provide actual YouTube playback (not just media remote control) are distributed outside the App Store and violate YouTube ToS. None have been legally challenged by Google to date.

---

## 6. SponsorBlock, Return YouTube Dislike, DeArrow Integration

### 6A. SponsorBlock API

**Base URL:** `https://sponsor.ajay.app`

**Get skip segments:**
```
GET /api/skipSegments?videoID={videoID}&categories=["sponsor","selfpromo","interaction","intro","outro","preview","music_offtopic","poi_highlight","filler"]
```

**Response:**
```json
[
  {
    "UUID": "abc123",
    "segment": [12.5, 45.2],
    "category": "sponsor",
    "actionType": "skip",
    "votes": 15,
    "locked": false
  }
]
```

**Categories:**
| Category | Description |
|----------|-------------|
| `sponsor` | Paid promotion |
| `selfpromo` | Self-promotion / merch |
| `interaction` | Subscribe reminders, like requests |
| `intro` | Intro animation |
| `outro` | Outro / end cards |
| `preview` | Preview of upcoming content |
| `music_offtopic` | Non-music in music videos |
| `poi_highlight` | Highlight / important moment |
| `filler` | Filler / tangent |

**Action types:** `skip` (auto-skip), `mute` (mute audio), `poi` (point of interest), `full` (entire video is category)

**Privacy-preserving query:** Use hash-based lookup:
```
GET /api/skipSegments/{sha256HashPrefix}?categories=[...]
```
Only send first 4 characters of SHA256 hash of video ID. Server returns all matching segments. Client filters locally.

**Integration in player:**
```swift
// Fetch segments
let url = URL(string: "https://sponsor.ajay.app/api/skipSegments?videoID=\(videoID)&categories=[\"sponsor\"]")!
let (data, _) = try await URLSession.shared.data(from: url)
let segments = try JSONDecoder().decode([SponsorSegment].self, from: data)

// During playback, check current time against segments
func checkSponsorSegments(currentTime: Double) {
    for segment in segments where segment.actionType == "skip" {
        if currentTime >= segment.segment[0] && currentTime < segment.segment[1] {
            player.seek(to: CMTime(seconds: segment.segment[1], preferredTimescale: 1))
        }
    }
}
```

**Note:** SponsorBlock only works if you control the playback timeline (AVPlayer with direct URLs). Does NOT work with WKWebView iframe embeds (no access to playback position at the needed granularity, although YouTubePlayerKit does expose current time via JS bridge — could work with polling).

---

### 6B. Return YouTube Dislike API

**Base URL:** `https://returnyoutubedislikeapi.com`

**Get votes:**
```
GET /votes?videoId={videoID}
```

**Response:**
```json
{
  "id": "dQw4w9WgXcQ",
  "dateCreated": "2022-04-09T21:44:20.5103Z",
  "likes": 31885,
  "dislikes": 579721,
  "rating": 1.2085329444119253,
  "viewCount": 3762293,
  "deleted": false
}
```

**Rate limits:** 100 requests/minute, 10,000/day per client.

**Attribution:** Must clearly attribute with link to returnyoutubedislike.com.

**Swagger docs:** `https://returnyoutubedislikeapi.com/swagger/index.html`

**Data source:** Combination of pre-removal scraped data + extrapolation from extension user votes.

---

### 6C. DeArrow API (Better Titles & Thumbnails)

**Base URL:** `https://sponsor.ajay.app` (same infrastructure as SponsorBlock)

**Get branding (titles + thumbnails):**
```
GET /api/branding?videoID={videoID}
```

**Response:**
```json
{
  "titles": [
    {
      "title": "Actual descriptive title",
      "votes": 5,
      "locked": false,
      "UUID": "abc123"
    }
  ],
  "thumbnails": [
    {
      "timestamp": 42.5,
      "votes": 3,
      "locked": false,
      "UUID": "def456"
    }
  ]
}
```

**Get thumbnail image:**
```
GET https://dearrow-thumb.ajay.app/api/v1/getThumbnail?videoID={videoID}&time={timestamp}
```
Returns binary image (200 OK) or 204 No Content if failed/unavailable.

**Trust logic:**
- Use first element in arrays
- But only if `locked == true` OR `votes >= 0`
- If neither: data is "untrusted" — show only in voting UI

**Integration:**
```swift
struct DeArrowData: Codable {
    let titles: [DeArrowTitle]
    let thumbnails: [DeArrowThumbnail]
}

struct DeArrowTitle: Codable {
    let title: String
    let votes: Int
    let locked: Bool
}

struct DeArrowThumbnail: Codable {
    let timestamp: Double
    let votes: Int
    let locked: Bool
}

func fetchDeArrow(videoID: String) async throws -> DeArrowData {
    let url = URL(string: "https://sponsor.ajay.app/api/branding?videoID=\(videoID)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(DeArrowData.self, from: data)
}
```

---

## 7. Recommended Architecture for TopNotch

### Option A: App Store Safe (WKWebView Embed)

```
User pastes YouTube URL
        │
        ▼
YouTubePlayerKit (WKWebView + iframe API)
        │
        ├── Notch expansion panel (compact player)
        ├── Pop-out to floating NSPanel (resizable)
        ├── YouTube controls via JS bridge
        └── Media remote via MPNowPlayingInfoCenter
            (limited — can detect play/pause state)

Metadata: YouTube Data API v3 (search, thumbnails)
Extras: Return YouTube Dislike API (display only)
        DeArrow API (better titles/thumbnails in search)
```

**Pros:** App Store safe, no ToS violations, no maintenance burden
**Cons:** No SponsorBlock, no audio-only background, YouTube UI chrome visible, ads play

### Option B: Direct Distribution (Hybrid — Recommended)

```
User pastes YouTube URL
        │
        ▼
alexeichhorn/YouTubeKit (extract direct URL)
        │ (fallback: Piped API → Invidious API)
        ▼
AVPlayer (native playback)
        │
        ├── Notch expansion panel (compact player with custom UI)
        ├── Pop-out to floating NSPanel (resizable, corner snap)
        ├── Full custom controls (SwiftUI overlay)
        ├── SponsorBlock auto-skip
        ├── Background audio (audio-only stream)
        ├── MPNowPlayingInfoCenter + MPRemoteCommandCenter
        ├── Return YouTube Dislike display
        └── DeArrow titles/thumbnails

Search/Browse: b5i/YouTubeKit (no API key) or Piped API
```

**Pros:** Full control, SponsorBlock, background audio, beautiful custom UI, no ads
**Cons:** YouTube ToS violation, requires maintenance, cannot go on App Store, PO Token challenges

### Option C: Hybrid (Best of Both Worlds)

```
Default mode: WKWebView iframe embed (YouTubePlayerKit)
        │
        └── Toggle "Enhanced Mode" in settings
                │
                ▼
        alexeichhorn/YouTubeKit extraction
                │
                ▼
        AVPlayer with full features
```

Distribute outside App Store via DMG. Default to compliant iframe mode. Let power users opt into enhanced mode.

---

## Key Libraries Summary

| Library | Purpose | URL |
|---------|---------|-----|
| YouTubePlayerKit (SvenTiigi) | WKWebView iframe embed | [github.com/SvenTiigi/YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit) |
| YouTubeKit (alexeichhorn) | Direct URL extraction | [github.com/alexeichhorn/YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) |
| YouTubeKit (b5i) | InnerTube API (search, metadata) | [github.com/b5i/YouTubeKit](https://github.com/b5i/YouTubeKit) |
| XCDYouTubeKit | Legacy URL extraction | [github.com/0xced/XCDYouTubeKit](https://github.com/0xced/XCDYouTubeKit) |
| DynamicNotchKit | Notch UI framework | [github.com/MrKai77/DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) |
| KSPlayer | AVPlayer+FFmpeg player | [github.com/kingslay/KSPlayer](https://github.com/kingslay/KSPlayer) |
| YoutubeDL-iOS | yt-dlp Swift wrapper | [github.com/kewlbear/YoutubeDL-iOS](https://github.com/kewlbear/YoutubeDL-iOS) |
| YouTube.js (JS) | InnerTube client | [github.com/LuanRT/YouTube.js](https://github.com/LuanRT/YouTube.js) |
| BgUtils (JS) | PO Token generation | [github.com/LuanRT/BgUtils](https://github.com/LuanRT/BgUtils) |

---

## Sources

- [YouTubePlayerKit — SvenTiigi](https://github.com/SvenTiigi/YouTubePlayerKit)
- [YouTubeKit — alexeichhorn](https://github.com/alexeichhorn/YouTubeKit)
- [YouTubeKit — b5i](https://github.com/b5i/YouTubeKit)
- [XCDYouTubeKit](https://github.com/0xced/XCDYouTubeKit)
- [YoutubePlayer-in-WKWebView](https://github.com/hmhv/YoutubePlayer-in-WKWebView)
- [Unofficial SwiftUI YouTube Wrapper](https://github.com/CongLeSolutionX/Unofficial-SwiftUI-Wrapper-for-YouTube-IFrame-Player-API)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [MacYTDL](https://github.com/section83/MacYTDL)
- [YoutubeDL-iOS](https://github.com/kewlbear/YoutubeDL-iOS)
- [ClipSnag — yt-dlp wrapper lessons](https://arkadiuszchmura.com/posts/things-i-learned-while-building-a-yt-dlp-wrapper/)
- [Invidious](https://github.com/iv-org/invidious)
- [Invidious API Documentation](https://docs.invidious.io/api/)
- [Piped](https://github.com/TeamPiped/Piped)
- [Piped API Documentation](https://docs.piped.video/docs/api-documentation/)
- [NewPipe Extractor](https://github.com/TeamNewPipe/NewPipeExtractor)
- [YouTube.js — LuanRT](https://github.com/LuanRT/YouTube.js/)
- [BgUtils — PO Token](https://github.com/LuanRT/BgUtils)
- [YouTube PO Token Guide — yt-dlp wiki](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide)
- [innertube docs — davidzeng0](https://github.com/davidzeng0/innertube)
- [IINA](https://github.com/iina/iina)
- [IINA youtube-dl wiki](https://github.com/iina/iina/wiki/Use-youtube-dl-with-IINA)
- [NotchNook](https://lo.cafe/notchnook)
- [TheBoringNotch](https://github.com/TheBoredTeam/boring.notch/)
- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)
- [Yattee](https://github.com/yattee/yattee)
- [FreeTube](https://github.com/FreeTubeApp/FreeTube)
- [FreeTube Local API — DeepWiki](https://deepwiki.com/FreeTubeApp/FreeTube/4.1-local-api-implementation)
- [AVPictureInPictureController — Apple](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller)
- [MPNowPlayingInfoCenter — Apple](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [NSScreen safeAreaInsets — Apple](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [NSPanel — Apple](https://developer.apple.com/documentation/appkit/nspanel)
- [YouTube API Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
- [YouTube API ToS](https://developers.google.com/youtube/terms/api-services-terms-of-service)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Guideline 5.2.3 Analysis](https://endavid.com/index.php?entry=88)
- [SponsorBlock API Docs](https://wiki.sponsor.ajay.app/w/API_Docs)
- [SponsorBlock](https://sponsor.ajay.app/)
- [Return YouTube Dislike API](https://returnyoutubedislike.com/docs)
- [DeArrow](https://dearrow.ajay.app/)
- [DeArrow API Docs](https://wiki.sponsor.ajay.app/w/API_Docs/DeArrow)
- [Floating Panel in SwiftUI — Cindori](https://cindori.com/developer/floating-panel)
- [Floating Window macOS 15 — polpiella.dev](https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15)
- [KSPlayer](https://github.com/kingslay/KSPlayer)
- [Brave PiP](https://brave.com/whats-new/picture-in-picture/)
- [YouTube Data API v3](https://developers.google.com/youtube/v3)
- [YouTube Quota Calculator](https://developers.google.com/youtube/v3/determine_quota_cost)
- [Atoll — Dynamic Island for macOS](https://github.com/Ebullioscopic/Atoll)
