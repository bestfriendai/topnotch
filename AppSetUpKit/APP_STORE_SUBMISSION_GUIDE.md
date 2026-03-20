# App Store Submission Guide - What2WatchAI

## Quick Reference

| Field | Value |
|-------|-------|
| App Name | What2WatchAI |
| Bundle ID | `com.what2watchai.app` |
| Widget Bundle ID | `com.what2watchai.app.widgets` |
| Team ID | `CY89UC5Z6Z` |
| API Key ID | `PRKWBSZ4FZ` |
| Issuer ID | `d379ef5a-740b-4b80-bc48-8e1526fc03d3` |
| Firebase Project | `movietrailer-1767069717` |

---

## Phase 1: Prerequisites Checklist

### 1.1 Tools Required
```bash
# Install Fastlane
sudo gem install fastlane

# Install XcodeGen (if not installed)
brew install xcodegen

# Verify installations
fastlane --version
xcodegen --version
```

### 1.2 Files Required
- [x] `.p8` API Key file (in AppSetUpKit folder)
- [ ] App Icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] Privacy Policy URL
- [ ] Support URL

---

## Phase 2: App Store Connect Setup

### 2.1 Create App in App Store Connect

**Option A: Using Fastlane (Recommended)**

Navigate to your project root and run:

```bash
cd /Users/letsmakemillions/Downloads/GitHub/MovieTrailer

# Initialize Fastlane
fastlane init

# Create the app
fastlane produce create \
  --app_identifier "com.what2watchai.app" \
  --app_name "What2WatchAI" \
  --language "English" \
  --app_version "1.0.0" \
  --sku "com.what2watchai.app.sku"
```

**Option B: Manual via App Store Connect**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "+" > "New App"
3. Fill in:
   - Platform: iOS
   - Name: What2WatchAI
   - Primary Language: English
   - Bundle ID: com.what2watchai.app
   - SKU: com.what2watchai.app.sku

### 2.2 Register Bundle IDs

If bundle IDs don't exist yet:

```bash
# Main app bundle ID
fastlane produce enable_services \
  --app_identifier "com.what2watchai.app"

# Widget extension bundle ID  
fastlane produce create \
  --app_identifier "com.what2watchai.app.widgets" \
  --app_name "What2WatchAI Widgets" \
  --sku "com.what2watchai.app.widgets.sku"
```

---

## Phase 3: Capabilities Setup

### 3.1 Sign in with Apple

**In Apple Developer Portal:**
1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Select `com.what2watchai.app`
3. Enable "Sign in with Apple"
4. Configure as "Enable as a primary App ID"

**Create Services ID (for web/OAuth):**
1. Create new identifier > Services IDs
2. Identifier: `com.what2watchai.app.signin`
3. Enable "Sign in with Apple"
4. Configure domains and return URLs

**Via Fastlane:**
```ruby
# In Fastlane/Fastfile
lane :enable_capabilities do
  produce(
    app_identifier: "com.what2watchai.app",
    enable_services: {
      sign_in_with_apple: "on",
      push_notification: "on"
    }
  )
end
```

### 3.2 Push Notifications

1. Enable Push Notifications capability
2. The .p8 key is already available for APNs

**APNs Key Configuration:**
```
Key ID: PRKWBSZ4FZ
Team ID: CY89UC5Z6Z
Key File: appsetupkit.p8
```

### 3.3 App Groups (for Widget)

Create App Group: `group.com.what2watchai.app`

Enable for both:
- `com.what2watchai.app`
- `com.what2watchai.app.widgets`

---

## Phase 4: Fastlane Configuration

### 4.1 Create Fastlane Directory Structure

```bash
mkdir -p fastlane/metadata/en-US
mkdir -p fastlane/screenshots/en-US
```

### 4.2 Create Appfile

Create `fastlane/Appfile`:
```ruby
app_identifier("com.what2watchai.app")
apple_id("YOUR_APPLE_ID@email.com")  # Replace with your Apple ID
team_id("CY89UC5Z6Z")

# For App Store Connect API
for_lane :release do
  app_identifier("com.what2watchai.app")
end
```

### 4.3 Create Fastfile

Create `fastlane/Fastfile`:
```ruby
default_platform(:ios)

# App Store Connect API Key
api_key = app_store_connect_api_key(
  key_id: "PRKWBSZ4FZ",
  issuer_id: "d379ef5a-740b-4b80-bc48-8e1526fc03d3",
  key_filepath: "./AppSetUpKit/appsetupkit.p8 copy",
  duration: 1200
)

platform :ios do

  # ==========================================
  # SETUP LANES
  # ==========================================
  
  desc "Create app in App Store Connect"
  lane :create_app do
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      app_name: "What2WatchAI",
      language: "English",
      app_version: "1.0.0",
      sku: "com.what2watchai.app.sku",
      enable_services: {
        push_notification: "on"
      }
    )
  end

  desc "Enable all capabilities"
  lane :setup_capabilities do
    # Sign in with Apple
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      enable_services: {
        sign_in_with_apple: "on",
        push_notification: "on"
      }
    )
  end

  # ==========================================
  # METADATA LANES
  # ==========================================

  desc "Upload metadata to App Store Connect"
  lane :upload_metadata do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_screenshots: true,
      force: true,
      metadata_path: "./fastlane/metadata",
      submit_for_review: false
    )
  end

  desc "Upload screenshots"
  lane :upload_screenshots do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_metadata: true,
      screenshots_path: "./fastlane/screenshots",
      force: true
    )
  end

  desc "Download existing metadata"
  lane :download_metadata do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_screenshots: true
    )
  end

  # ==========================================
  # BUILD LANES
  # ==========================================

  desc "Build for App Store"
  lane :build do
    # Generate Xcode project
    sh("cd .. && xcodegen generate")
    
    build_app(
      scheme: "What2WatchAI",
      export_method: "app-store",
      output_directory: "./build",
      output_name: "What2WatchAI.ipa"
    )
  end

  desc "Upload to TestFlight"
  lane :beta do
    build
    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: true
    )
  end

  desc "Submit to App Store"
  lane :release do
    build
    deliver(
      api_key: api_key,
      submit_for_review: true,
      automatic_release: false,
      force: true,
      precheck_include_in_app_purchases: false
    )
  end

  # ==========================================
  # CERTIFICATES & PROVISIONING
  # ==========================================

  desc "Sync certificates and provisioning profiles"
  lane :sync_certs do
    match(
      type: "appstore",
      app_identifier: ["com.what2watchai.app", "com.what2watchai.app.widgets"],
      readonly: true,
      api_key: api_key
    )
  end

  desc "Create new certificates"
  lane :create_certs do
    match(
      type: "appstore",
      app_identifier: ["com.what2watchai.app", "com.what2watchai.app.widgets"],
      force: true,
      api_key: api_key
    )
  end

end
```

---

## Phase 5: Metadata Files

See ASO_METADATA_GUIDE.md for complete SEO-optimized metadata.

### 5.1 Required Metadata Files

Create these files in fastlane/metadata/en-US/:

name.txt
```
What2WatchAI
```

subtitle.txt (max 30 characters)
```
Discover Movies and TV Shows
```

description.txt
```
Find your next favorite movie in seconds. What2WatchAI uses smart recommendations to match films and TV shows to your personal taste, helping you decide what to watch tonight.

Your Personal Movie Discovery Assistant

What2WatchAI analyzes your preferences to suggest films you will actually enjoy. No more endless scrolling through streaming catalogs. Get personalized picks based on your mood, available time, and viewing history.

Key Features

Smart Recommendations
The app learns what you like and suggests movies that match your taste. Swipe right to save, left to skip. Your feedback improves future suggestions.

Tonight Mode
Cannot decide what to watch? Tap Tonight and get an instant recommendation based on trending titles and your personal preferences. Perfect for movie nights.

Watchlist Manager
Save movies you want to watch later. Organize by genre, priority, or streaming service. Share your list with friends and family.

Live Activity Support
Track your watchlist progress from your lock screen and Dynamic Island. See countdowns to movie nights and release dates.

Beautiful Interface
Clean, modern design that makes browsing movies enjoyable. Full dark mode support and accessibility features included.

Data Sources

Movie information provided by The Movie Database (TMDB). Streaming availability updated regularly.

Privacy First

Your data stays on your device. Optional cloud sync with Sign in with Apple keeps your watchlist secure across devices.

No subscription required. Download What2WatchAI and start discovering great movies today.
```

keywords.txt (max 100 characters, no spaces after commas)
```
film,recommendation,streaming,picker,tonight,tracker,list,cinema,new,release,popular,trend,suggest
```

promotional_text.txt (max 170 characters)
```
New AI recommendation engine now live. Get personalized movie suggestions based on your taste. Perfect for planning your next movie night.
```

privacy_url.txt
```
https://what2watchai.com/privacy
```

support_url.txt
```
https://what2watchai.com/support
```

marketing_url.txt
```
https://what2watchai.com
```

release_notes.txt
```
Version 1.0

What2WatchAI is now available.

This release includes:
- AI-powered movie recommendations
- Swipe discovery interface
- Tonight instant pick feature
- Watchlist with sharing
- Live Activity and Dynamic Island support
- Dark mode
- Sign in with Apple sync

We would love your feedback. Rate the app or contact support with suggestions.
```
What2WatchAI
```

**subtitle.txt** (max 30 characters)
```
AI Movie Discovery & Watchlist
```

**description.txt**
```
What2WatchAI - Your Personal Movie Discovery Assistant

Powered by AI, What2WatchAI helps you discover your next favorite movie with personalized recommendations, smart watchlist management, and real-time movie information.

KEY FEATURES:

SMART RECOMMENDATIONS
Let our AI analyze your preferences and suggest movies you'll love. Swipe through recommendations like you're browsing a dating app for movies!

TONIGHT'S PICK
Can't decide what to watch? Let What2WatchAI pick the perfect movie for your mood, combining trending titles with your personal taste.

WATCHLIST MANAGEMENT
Build and organize your watchlist with ease. Share your favorites with friends and never forget a movie recommendation again.

LIVE ACTIVITIES
Stay updated with Dynamic Island integration showing your watchlist progress and movie night countdowns.

BEAUTIFUL DESIGN
Experience a stunning glassmorphism interface that makes browsing movies a visual delight.

DATA & PRIVACY:
- Powered by The Movie Database (TMDB)
- Your data stays on your device
- Optional cloud sync with Sign in with Apple

Download What2WatchAI today and transform how you discover movies!
```

**keywords.txt** (max 100 characters, comma-separated)
```
movies,watchlist,recommendations,AI,trailers,discover,cinema,film,watch,tonight
```

**promotional_text.txt** (max 170 characters)
```
Discover your next favorite movie with AI-powered recommendations, smart watchlist management, and a beautiful interface.
```

**privacy_url.txt**
```
https://what2watchai.com/privacy
```

**support_url.txt**
```
https://what2watchai.com/support
```

**marketing_url.txt**
```
https://what2watchai.com
```

**release_notes.txt**
```
What's New in What2WatchAI 1.0:

- AI-powered movie recommendations
- Swipe-based discovery experience
- "Tonight's Pick" feature for instant suggestions
- Smart watchlist with sharing capabilities
- Live Activities and Dynamic Island support
- Beautiful glassmorphism design
- Sign in with Apple for secure sync
- Full Dark Mode support

Thank you for choosing What2WatchAI!
```

---

## Phase 6: Screenshots Requirements

### 6.1 Required Sizes

| Device | Size (Portrait) | Required |
|--------|-----------------|----------|
| iPhone 6.9" | 1320 x 2868 | Required |
| iPhone 6.7" | 1290 x 2796 | Required |
| iPhone 6.5" | 1284 x 2778 | Required |
| iPhone 5.5" | 1242 x 2208 | Optional |
| iPad Pro 12.9" | 2048 x 2732 | If supporting iPad |

### 6.2 Screenshot Content Recommendations

1. **Home/Discover Screen** - Show movie cards and browsing
2. **Swipe Discovery** - Show the swipe interface
3. **Tonight's Pick** - AI recommendation feature
4. **Watchlist** - Organized movie collection
5. **Movie Details** - Rich movie information
6. **Live Activity** - Dynamic Island integration

---

## Phase 7: App Review Information

### 7.1 Demo Account
If your app requires login for review:
```
Email: demo@what2watchai.com
Password: TestDemo2024!
```

### 7.2 Review Notes
```
Thank you for reviewing What2WatchAI.

Key features to test:
1. Browse movies on the Discover tab
2. Swipe right to add movies to watchlist
3. Tap Tonight for instant recommendations
4. View movie details and watch trailers
5. Manage and share watchlist

No account required for core features. Sign in with Apple available for optional cloud sync.

Movie data provided by The Movie Database (TMDB) under their API terms of service.

Contact: support@what2watchai.com
```

---

## Phase 8: Submission Commands

### 8.1 Complete Workflow

```bash
# 1. Navigate to project
cd /Users/letsmakemillions/Downloads/GitHub/MovieTrailer

# 2. Create app (first time only)
fastlane create_app

# 3. Setup capabilities
fastlane setup_capabilities

# 4. Upload metadata
fastlane upload_metadata

# 5. Upload screenshots (after adding them)
fastlane upload_screenshots

# 6. Build and upload to TestFlight
fastlane beta

# 7. Submit for review (when ready)
fastlane release
```

### 8.2 Quick Commands Reference

| Command | Description |
|---------|-------------|
| `fastlane create_app` | Create app in App Store Connect |
| `fastlane setup_capabilities` | Enable Sign in with Apple, Push |
| `fastlane upload_metadata` | Upload app description, keywords |
| `fastlane upload_screenshots` | Upload screenshots |
| `fastlane beta` | Build and upload to TestFlight |
| `fastlane release` | Submit to App Store review |
| `fastlane download_metadata` | Download existing metadata |

---

## Troubleshooting

### Common Issues

**"Bundle ID not found"**
```bash
fastlane produce create --app_identifier "com.what2watchai.app" --skip_itc
```

**"Invalid API Key"**
- Verify key file path in Fastfile
- Check key hasn't expired
- Ensure key has App Manager role

**"Missing provisioning profile"**
```bash
fastlane match appstore --app_identifier "com.what2watchai.app"
```

**"Screenshots rejected"**
- Ensure no placeholder content
- Remove any "beta" or "test" labels
- Check all required sizes are present

---

## Next Steps After Approval

1. Monitor crash reports in App Store Connect
2. Respond to user reviews
3. Plan version 1.1 updates
4. Set up App Store promotional activities
5. Configure App Analytics

---

Document Version: 1.0
Last Updated: January 2026
For: What2WatchAI iOS App
