# App Store Readiness Report: Top Notch

This document outlines the required changes, technical adjustments, and design refinements necessary to ensure "Top Notch" complies with the **App Store Review Guidelines** (as of March 2026).

---

## 1. Safety & Software Requirements (Guideline 2.5)

### 1.1 Sandbox Compliance (Guideline 2.4.5)
**Requirement**: All Mac App Store apps must be sandboxed.
- **Current Issue**: The app relies on `CGEvent.tapCreate()` for media key interception and system-wide volume/brightness HUD replacement.
- **Required Change**: These features **must be removed** or disabled in the App Store build. Sandboxed apps cannot intercept system-wide events.
- **Mitigation**: Use `MPNowPlayingInfoCenter` for public playback control and let macOS handle volume/brightness keys natively.

### 1.2 Private API Usage (Guideline 2.5.1)
**Requirement**: Apps may only use public APIs.
- **Current Issue**: Usage of `SkyLight.framework` (for lock screen window levels), `MediaRemote.framework` (for now playing info), and `DisplayServices.framework` (for brightness control).
- **Required Change**: These frameworks must be completely removed from the App Store target.
- **Implementation**: The existing `APP_STORE_BUILD` compiler flag must be rigorously applied to ensure no private symbols are even referenced in the final binary.

---

## 2. Design & User Interface (Guideline 4)

### 2.1 Minimum Functionality (Guideline 4.2)
**Requirement**: Apps should provide a high-quality, unique utility that justifies its place on the App Store.
- **Current Status**: With private APIs removed, the "Top Notch" feature set is reduced. 
- **Required Improvement**: Ensure the "Hub" cards (Weather, Calendar, Pomodoro) provide enough value on their own. Add a unique feature like "Notch-integrated Task Timer" or "Custom Widget Builder" to differentiate from system widgets.

### 2.2 Human Interface Guidelines (HIG) (Guideline 4.1)
**Requirement**: Apps must follow Apple's design patterns.
- **Improvement**: The newly implemented "Dynamic Island" aesthetic is excellent. Ensure that:
    - **Hover states** are clear and use standard system cursors.
    - **Typography** uses system fonts (`SF Pro`) with proper weight hierarchy.
    - **App Icon** follows the "Liquid Glass" macOS 15+ style (rounded tiles with realistic textures and shadows).

### 2.3 Copycats & Spam (Guideline 4.1 & 4.3)
**Requirement**: Apps should not be "copycats" of Apple features or existing apps.
- **Risk**: Apple recently introduced native "iPhone-like" notch behavior in macOS. If "Top Notch" looks *too* much like a system feature without adding unique functionality, it might be rejected as "cluttering the system".
- **Required Change**: Pivot marketing and UI to focus on "Productivity Hub" and "Customization" rather than just "macOS Dynamic Island".

---

## 3. Privacy & Data Collection (Guideline 5.1)

### 3.1 Clipboard Manager (Guideline 5.1.1)
**Requirement**: Apps that monitor the clipboard must justify the need and ensure user privacy.
- **Current Issue**: The app polls the general pasteboard every second.
- **Required Change**:
    - Include a clear explanation in the `Info.plist` using `NSAppleEventsUsageDescription` or a custom popup when the feature is first enabled.
    - **Privacy Policy**: Must explicitly state that clipboard data is processed locally and never uploaded.
    - **User Consent**: The clipboard history feature should be **OFF by default** in the App Store version, requiring an explicit user opt-in.

---

## 4. Legal & Intellectual Property (Guideline 5.2)

### 4.1 YouTube Integration (Guideline 5.2.3)
**Requirement**: Apps must not download or convert media from third-party sources without authorization.
- **Current Status**: The YouTube player uses `WKWebView`.
- **Required Change**: 
    - Ensure **NO** "Download" button exists.
    - Ensure **NO** "Background Audio Only" mode exists (which is a premium YouTube feature).
    - Use the official YouTube IFrame Embed API to comply with Terms of Service.

---

## 5. Technical Submission Checklist

| Category | Item | Status |
|----------|------|--------|
| **Signing** | Developer ID Application + Hardened Runtime | ⚠️ Pending |
| **Sandbox** | `com.apple.security.app-sandbox` = true | ✅ Implemented |
| **Entitlements** | Network Client (for YouTube/Weather) | ✅ Implemented |
| **Entitlements** | User Selected Files (if needed for File Tray) | ⚠️ Pending |
| **Info.plist** | `LSApplicationCategoryType` = `public.app-category.utilities` | ✅ Implemented |
| **Info.plist** | `ITSAppUsesNonExemptEncryption` = `false` | ✅ Implemented |
| **Assets** | Full app icon set (1024x1024 down to 16x16) | ⚠️ Pending |
| **Assets** | 1280x800 minimum Retina screenshots | ⚠️ Pending |

---

## 6. Recommendation Summary

To pass review, we must ship a **"Lite" version** to the App Store while keeping the **"Pro" version** for direct distribution.

1.  **Disable** all private API paths using `#if APP_STORE_BUILD`.
2.  **Focus** the App Store marketing on the "Utility Hub" (Weather, Calendar, Clipboard history).
3.  **Ensure** the YouTube player is a standard, non-invasive `WKWebView`.
4.  **Polish** the App Icon to match the premium macOS 15+ aesthetic.
