# Create App in App Store Connect - Manual Steps Required

## Status

Bundle ID `com.what2watchai.movieapp` has been registered in Developer Portal.

The API key cannot CREATE apps (only read/update), so you must create the app manually.

## Quick Steps (5 minutes)

### Step 1: Open App Store Connect

Go to: https://appstoreconnect.apple.com

### Step 2: Create New App

1. Click the blue **+** button in the top left
2. Select **New App**

### Step 3: Fill In App Details

| Field | Value |
|-------|-------|
| Platforms | iOS |
| Name | What2WatchAI |
| Primary Language | English (U.S.) |
| Bundle ID | com.what2watchai.movieapp |
| SKU | what2watchai.app.sku.2026 |
| User Access | Full Access |

3. Click **Create**

### Step 4: Upload Metadata via Fastlane

Once the app is created, run:

```bash
cd /Users/letsmakemillions/Downloads/GitHub/MovieTrailer
/opt/homebrew/bin/fastlane metadata
```

This will upload:
- App name and subtitle
- Description (SEO optimized)
- Keywords (97 characters, optimized)
- Privacy URL, Support URL, Marketing URL
- Release notes
- App review notes
- Category settings

### Step 5: Update Xcode Project

Update `project.yml` to use the new bundle ID:

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.what2watchai.movieapp
```

## What's Already Done

- Bundle ID registered: com.what2watchai.movieapp
- Fastlane configured with correct bundle ID
- All metadata files created and optimized
- Keywords SEO optimized (no emojis, max 97 chars)
- Description clean and formatted

## Still Needed

- Screenshots (all required sizes)
- App Icon (1024x1024)
- Privacy Policy website live
- Support website live

## After App is Created

```bash
# Upload metadata
/opt/homebrew/bin/fastlane metadata

# When ready with screenshots
/opt/homebrew/bin/fastlane screenshots

# Build and upload to TestFlight
/opt/homebrew/bin/fastlane beta
```

---

Document Created: January 2026
