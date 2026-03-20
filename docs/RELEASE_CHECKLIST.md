# Top Notch — Release Checklist

Use this checklist before cutting any release candidate, direct distribution or App Store.

---

## Pre-Release: Code & Build

- [ ] `MACOSX_DEPLOYMENT_TARGET = 14.0` confirmed in **all 4** build configurations (Debug, Release, AppStoreDebug, AppStoreRelease)
- [ ] Both build variants compile cleanly with zero errors
- [ ] `APP_STORE_BUILD` preprocessor flag present in AppStoreDebug and AppStoreRelease build settings
- [ ] Bundle IDs match entitlements: `com.topnotch.app` ↔ `TopNotch.entitlements`, `com.topnotch.appstore` ↔ `TopNotchStore.entitlements`
- [ ] Version number (`CFBundleShortVersionString`) bumped in Info.plist
- [ ] Build number (`CFBundleVersion`) incremented

---

## Direct Distribution Build

### Archive & Notarize
```bash
# 1. Archive
xcodebuild archive \
  -scheme "TopNotch" \
  -configuration Release \
  -archivePath ./build/TopNotch-$(date +%Y%m%d).xcarchive

# 2. Export as Developer ID signed app
xcodebuild -exportArchive \
  -archivePath ./build/TopNotch-$(date +%Y%m%d).xcarchive \
  -exportOptionsPlist ExportOptions-Direct.plist \
  -exportPath ./build/export-direct/

# 3. Notarize
xcrun notarytool submit ./build/export-direct/TopNotch.zip \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD" \
  --wait

# 4. Staple
xcrun stapler staple ./build/export-direct/TopNotch.app

# 5. Verify notarization
spctl -a -vv ./build/export-direct/TopNotch.app
```

### Post-Archive Verification
- [ ] App launches on a clean macOS 14+ machine
- [ ] Gatekeeper passes (`spctl -a -vv TopNotch.app`)
- [ ] Notarization ticket stapled
- [ ] `codesign -dvvv TopNotch.app` shows valid Developer ID

---

## App Store Build

### Archive & Submit
```bash
# Archive with App Store config
xcodebuild archive \
  -scheme "TopNotchStore" \
  -configuration AppStoreRelease \
  -archivePath ./build/TopNotchStore-$(date +%Y%m%d).xcarchive

# Upload via Transporter or:
xcrun altool --upload-package ./build/TopNotchStore.ipa \
  --type osx \
  --apple-id "YOUR_APP_ID" \
  --asc-provider "YOUR_TEAM_ID"
```

### App Store Compliance
- [ ] No private API usage in `APP_STORE_BUILD` path
- [ ] No SkyLight / MediaRemote / DisplayServices in store build
- [ ] Clipboard monitoring defaults to OFF in App Store build
- [ ] All permission-denied states show user-friendly UI (not silent failures)
- [ ] App Sandbox entitlement present and correct
- [ ] No `canBecomeVisibleWithoutLogin` in store build (guarded by `#if !APP_STORE_BUILD`)

---

## Manual QA Matrix

Run through this matrix on both Direct and App Store builds.

### Permissions
- [ ] Launch with **no** permissions granted → app explains requirements gracefully
- [ ] Grant Accessibility → media keys work in Direct build
- [ ] Deny Accessibility → alert explains impact, app still usable
- [ ] Deny Location → weather card shows "Permission Denied" state
- [ ] First clipboard paste with YouTube URL → consent shown (if not asked before)

### Core Notch Flows
- [ ] Hover over notch → expands with animation
- [ ] Hover exit → collapses after delay
- [ ] Click notch → dashboard opens
- [ ] Double hover/click rapid sequence → no stuck expanded state

### Battery & Lock
- [ ] Plug in power → charging animation plays
- [ ] Unplug power → unplug animation plays
- [ ] Lock screen → lock indicator shows (Direct build only)
- [ ] Unlock → unlock animation plays with sound (Direct build only)

### Media
- [ ] Play Spotify/Music → music presence shows in notch
- [ ] Open media focused card → album art, controls visible
- [ ] ⌥Space → play/pause (Direct build)
- [ ] ⌥→ / ⌥← → next/previous track (Direct build)
- [ ] ⌥↑ / ⌥↓ → volume HUD (Direct build)

### YouTube
- [ ] Paste YouTube URL → prompt appears in notch within 2s
- [ ] Click prompt → YouTube deck opens
- [ ] Play embed video → inline player works
- [ ] Pop out to floating panel → video moves to floating window
- [ ] Pop back to notch → restores to inline
- [ ] Invalid/embed-blocked video → error state shown with fallback button
- [ ] ⌘⇧Y → YouTube deck opens

### Settings
- [ ] Open settings from context menu → window opens
- [ ] Toggle "Launch at Login" → persists across relaunch
- [ ] Toggle clipboard detection → takes effect immediately
- [ ] Settings persist after app quit and relaunch
- [ ] App Store build: private-API features show "not available" state

### Edge Cases
- [ ] Rapid charge/uncharge within 1s → no duplicate animations
- [ ] Rapid YouTube open/close → no orphaned player state
- [ ] Network offline → weather shows offline state
- [ ] Network offline → YouTube shows offline/error state

---

## Post-Release

- [ ] Tag release in git: `git tag v2.x.x && git push --tags`
- [ ] Update `README.md` version badge
- [ ] Update `docs/PRODUCTION_AUDIT.md` with resolved items
- [ ] Announce via chosen channel (website, GitHub Releases, etc.)
