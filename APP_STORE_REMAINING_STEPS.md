# Top Notch — Remaining App Store Connect Steps

These items CANNOT be set via API. Complete them in the web UI.

---

## 1. APP PRIVACY (Required — 2 minutes)

Open: https://appstoreconnect.apple.com → Top Notch → App Privacy

### Click "Get Started" then answer:

**Do you or your third-party partners collect data from this app?**
→ Select: **No, we do not collect data from this app**

That's it. Top Notch runs 100% locally:
- No accounts or sign-in
- No analytics or crash reporting
- No cloud sync
- No third-party SDKs that collect data
- Clipboard data stays on-device
- Location is used only for weather (WeatherKit/API) and not stored

Click **Publish** to save.

---

## 2. EXPORT COMPLIANCE (When uploading first build)

When you upload a build (via `fastlane beta` or Xcode), you'll be asked:

**Does your app use encryption?**
→ **Yes** (HTTPS/TLS for weather API and YouTube)

**Does your app qualify for any of the exemptions?**
→ **Yes** — select exemption (b)(1): "Standard HTTPS/TLS"

**Is your app available outside the US or Canada?**
→ **Yes**

This only needs to be answered once.

---

## 3. SCREENSHOTS (Required before submission)

Upload in: App Store Connect → Top Notch → macOS App → 1.0 → Media

### Required sizes for macOS:
- **1280 x 800** (MacBook Air 13")
- **1440 x 900** (MacBook Air 13" Retina)
- **2560 x 1600** (MacBook Pro 13")
- **2880 x 1800** (MacBook Pro 15"/16")

You need 1-10 screenshots per size. Minimum 1 size required.

### Suggested screenshots:
1. Hero — notch expanded showing all widgets
2. Now Playing — music controls with album art + lyrics
3. YouTube — inline video playing in the notch
4. Weather — animated weather forecast
5. Clipboard — clipboard history with items
6. Settings — customization options

---

## 4. BUILD UPLOAD

```bash
cd /Users/iamabillionaire/Downloads/topnotch

# Build for App Store
fastlane build

# Upload to TestFlight
fastlane beta

# Or full submission
fastlane release
```

---

## Everything Already Done (via API)

- [x] Bundle ID registered: com.topnotch.appstore
- [x] App created in App Store Connect
- [x] Name: Top Notch - Enhance Your Notch
- [x] Subtitle: Widgets, Music, YouTube & More (30/30)
- [x] Description: 3,727 chars, ASO-optimized
- [x] Keywords: 11 terms, 100/100 chars
- [x] Promotional text: 130 chars
- [x] Categories: Utilities + Productivity
- [x] Price: $9.99 one-time purchase
- [x] Age rating: All NONE, unrestricted web access
- [x] Copyright: 2026 Top Notch
- [x] Content rights: No third-party content
- [x] Made for Kids: No
- [x] Privacy URL: topnotchapp.com/privacy
- [x] Support URL: topnotchapp.com/support
- [x] Marketing URL: topnotchapp.com
- [x] Review notes: 1,121 chars with testing guide
- [x] Review contact: Patrick Francis, support@topnotchapp.com
- [x] Demo account: Not required
- [x] Availability: 175 territories (worldwide)
- [x] App icon: All macOS sizes generated
- [x] In-app logo: TopNotchLogo.imageset
- [x] Menu bar icon: TopNotchIcon.imageset
- [x] Fastlane: Appfile, Fastfile, Deliverfile, API key

---

Document updated: March 2026
