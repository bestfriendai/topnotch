# Create Top Notch in App Store Connect

## Status

- Bundle ID: `com.topnotch.appstore` (registered in Developer Portal)
- Team ID: `Y4NZ65U5X7`
- Platform: macOS
- All metadata files created and ASO-optimized
- Fastlane configured with API key

---

## Step 1: Register Bundle ID (Automated)

```bash
cd /Users/iamabillionaire/Downloads/topnotch
fastlane setup
```

This registers `com.topnotch.appstore` in the Apple Developer Portal.

---

## Step 2: Create App in App Store Connect (Manual)

The API key cannot CREATE apps, only read/update. Create manually:

1. Go to: https://appstoreconnect.apple.com
2. Click the blue **+** button > **New App**
3. Fill in:

| Field | Value |
|-------|-------|
| Platforms | macOS |
| Name | Top Notch |
| Primary Language | English (U.S.) |
| Bundle ID | com.topnotch.appstore |
| SKU | topnotch.mac.2026 |
| User Access | Full Access |

4. Click **Create**

---

## Step 3: Upload Metadata (Automated)

```bash
cd /Users/iamabillionaire/Downloads/topnotch
fastlane metadata
```

This uploads:
- App name: "Top Notch"
- Subtitle: "Supercharge Your MacBook Notch" (29 chars)
- Description (ASO-optimized, 2800+ chars)
- Keywords (100 chars, zero waste)
- Promotional text (142 chars)
- Release notes (v1.0)
- Privacy URL, Support URL, Marketing URL
- App review notes with testing instructions
- Categories: Utilities (primary), Productivity (secondary)

---

## Step 4: Set App Store Information (Manual in ASC)

After creating the app, set these in App Store Connect:

### Pricing
- Price: Free (or set your price tier)

### Age Rating
- Select: 4+ (no objectionable content)

### App Privacy
Top Notch collects NO user data. Select:
- Data Types: **None**
- Tracking: **No**

### Copyright
```
Copyright 2026 Top Notch. All rights reserved.
```

---

## Step 5: Build and Upload

### For TestFlight testing:
```bash
fastlane beta
```

### For App Store submission:
```bash
fastlane release
```

### Manual Xcode build:
```bash
xcodebuild -project MyDynamicIsland.xcodeproj \
  -scheme "TopNotchStore" \
  -configuration Release \
  -archivePath ./build/TopNotch.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath ./build/TopNotch.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build/AppStoreRelease
```

---

## What's Already Done

- [x] Bundle ID: com.topnotch.appstore
- [x] Fastlane Appfile configured
- [x] Fastlane Fastfile with setup/metadata/build/beta/release lanes
- [x] Deliverfile configured for macOS
- [x] API key (auth_key.p8) copied to fastlane/
- [x] App name: "Top Notch"
- [x] Subtitle: "Supercharge Your MacBook Notch" (29/30 chars)
- [x] Keywords: 100 chars, ASO-optimized, no word repetition
- [x] Description: ~2800 chars, front-loaded, feature-rich
- [x] Promotional text: 142/170 chars
- [x] Release notes: v1.0 with full feature list
- [x] Review notes: detailed testing guide for reviewers
- [x] Privacy/Support/Marketing URLs set
- [x] Categories: Utilities + Productivity
- [x] App icon: 1024x1024 + all macOS sizes generated
- [x] In-app logo asset (TopNotchLogo.imageset)
- [x] Menu bar icon asset (TopNotchIcon.imageset)
- [x] Entitlements: Sandbox (TopNotchStore.entitlements) for App Store

## Still Needed Before Submission

- [ ] Create app in App Store Connect (Step 2 above)
- [ ] Screenshots (macOS: 1280x800, 1440x900, 2560x1600, 2880x1800)
- [ ] Privacy policy page live at topnotchapp.com/privacy
- [ ] Support page live at topnotchapp.com/support
- [ ] Marketing website live at topnotchapp.com
- [ ] Test build on clean Mac to verify sandbox entitlements work
- [ ] Set pricing in App Store Connect
- [ ] Complete App Privacy questionnaire in ASC

---

## ASO Keyword Strategy

### Keywords (100 chars, comma-separated, no spaces):
```
notch,dynamic island,widget,music,weather,clipboard,pomodoro,battery,youtube,shortcut,menu bar,utility,timer,calendar,lyrics
```

### Strategy:
| Keyword | Intent | Competition |
|---------|--------|-------------|
| notch | Direct product search | Low (niche) |
| dynamic island | Feature association | Medium |
| widget | Functional search | High |
| music | Media control users | High |
| weather | Weather widget seekers | High |
| clipboard | Productivity tool search | Medium |
| pomodoro | Focus/productivity | Medium |
| battery | System monitor search | Medium |
| youtube | Video player search | High |
| shortcut | Automation users | Medium |
| menu bar | macOS utility search | Low |
| utility | Category browser | High |
| timer | Productivity search | High |
| calendar | Calendar widget search | High |
| lyrics | Music feature search | Medium |

### Words NOT in keywords (already in name/subtitle):
- "top" (in name)
- "supercharge" (in subtitle)
- "macbook" (in subtitle)
- "mac" (Apple indexes this from platform)

### Seasonal promotional_text updates:
- **Spring**: "Spring cleaning your workflow? 12 widgets in your MacBook notch..."
- **Back to School**: "Study smarter with Pomodoro timer, clipboard history, and weather..."
- **Holiday**: "New MacBook Pro? Make the notch useful from day one..."

---

Document Created: March 2026
