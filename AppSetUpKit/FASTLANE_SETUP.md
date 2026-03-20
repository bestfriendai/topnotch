# Fastlane Setup Guide - What2WatchAI

## Overview

Complete guide for setting up Fastlane for automated App Store deployment, including code signing, metadata management, and TestFlight distribution.

---

## Quick Start

```bash
# Navigate to project
cd /Users/letsmakemillions/Downloads/GitHub/MovieTrailer

# Install Fastlane
sudo gem install fastlane

# Initialize (creates fastlane folder)
fastlane init

# When prompted, select option 4 (Manual setup)
```

---

## Part 1: Directory Structure

Create the following structure:

```
MovieTrailer/
├── fastlane/
│   ├── Appfile
│   ├── Fastfile
│   ├── Deliverfile
│   ├── Matchfile
│   ├── metadata/
│   │   └── en-US/
│   │       ├── name.txt
│   │       ├── subtitle.txt
│   │       ├── description.txt
│   │       ├── keywords.txt
│   │       ├── promotional_text.txt
│   │       ├── privacy_url.txt
│   │       ├── support_url.txt
│   │       ├── marketing_url.txt
│   │       ├── release_notes.txt
│   │       └── primary_category.txt
│   └── screenshots/
│       └── en-US/
│           ├── iPhone 6.9"/
│           ├── iPhone 6.7"/
│           ├── iPhone 6.5"/
│           └── iPad Pro 12.9"/
├── AppSetUpKit/
│   └── appsetupkit.p8 copy   # API Key
└── ...
```

---

## Part 2: Configuration Files

### 2.1 Appfile

Create `fastlane/Appfile`:

```ruby
# App Store Connect App Identifier
app_identifier("com.what2watchai.app")

# Your Apple ID email
apple_id("YOUR_APPLE_ID@email.com")  # Replace this

# Team ID from Apple Developer Portal
team_id("CY89UC5Z6Z")

# App Store Connect Team ID (usually same as team_id)
itc_team_id("CY89UC5Z6Z")

# For specific lanes
for_platform :ios do
  app_identifier("com.what2watchai.app")
end
```

### 2.2 Fastfile

Create `fastlane/Fastfile`:

```ruby
# Fastfile for What2WatchAI
# Run 'fastlane lanes' to see all available lanes

default_platform(:ios)

# App Store Connect API Key Configuration
def api_key
  app_store_connect_api_key(
    key_id: "PRKWBSZ4FZ",
    issuer_id: "d379ef5a-740b-4b80-bc48-8e1526fc03d3",
    key_filepath: "./AppSetUpKit/appsetupkit.p8 copy",
    duration: 1200,
    in_house: false
  )
end

platform :ios do

  # ============================================
  # SETUP & REGISTRATION
  # ============================================

  desc "Register app with App Store Connect"
  lane :register_app do
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      app_name: "What2WatchAI",
      language: "English",
      app_version: "1.0.0",
      sku: "com.what2watchai.app.sku"
    )
    
    UI.success("App registered successfully!")
  end

  desc "Register widget extension"
  lane :register_widget do
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app.widgets",
      app_name: "What2WatchAI Widgets",
      language: "English",
      sku: "com.what2watchai.app.widgets.sku",
      skip_itc: true  # Widget doesn't need iTunes Connect entry
    )
    
    UI.success("Widget registered successfully!")
  end

  desc "Enable app capabilities"
  lane :enable_capabilities do
    # Enable for main app
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      enable_services: {
        push_notification: "on",
        sign_in_with_apple: "on",
        app_group: "on"
      }
    )
    
    # Enable for widget
    produce(
      api_key: api_key,
      app_identifier: "com.what2watchai.app.widgets",
      enable_services: {
        app_group: "on"
      },
      skip_itc: true
    )
    
    UI.success("Capabilities enabled!")
  end

  desc "Complete initial setup"
  lane :setup do
    register_app
    register_widget
    enable_capabilities
    
    UI.success("Setup complete! Next: run 'fastlane match' to setup certificates")
  end

  # ============================================
  # CODE SIGNING (Match)
  # ============================================

  desc "Sync certificates and profiles (read-only)"
  lane :certs do
    match(
      api_key: api_key,
      type: "appstore",
      app_identifier: [
        "com.what2watchai.app",
        "com.what2watchai.app.widgets"
      ],
      readonly: true
    )
  end

  desc "Create new certificates and profiles"
  lane :certs_new do
    match(
      api_key: api_key,
      type: "appstore",
      app_identifier: [
        "com.what2watchai.app",
        "com.what2watchai.app.widgets"
      ],
      force: true
    )
  end

  desc "Sync development certificates"
  lane :certs_dev do
    match(
      api_key: api_key,
      type: "development",
      app_identifier: [
        "com.what2watchai.app",
        "com.what2watchai.app.widgets"
      ],
      readonly: true
    )
  end

  # ============================================
  # METADATA
  # ============================================

  desc "Upload metadata to App Store Connect"
  lane :metadata do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_screenshots: true,
      metadata_path: "./fastlane/metadata",
      force: true,
      submit_for_review: false,
      automatic_release: false
    )
    
    UI.success("Metadata uploaded!")
  end

  desc "Upload screenshots"
  lane :screenshots do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_metadata: true,
      screenshots_path: "./fastlane/screenshots",
      overwrite_screenshots: true,
      force: true
    )
    
    UI.success("Screenshots uploaded!")
  end

  desc "Download existing metadata from App Store Connect"
  lane :download_metadata do
    deliver(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: false,
      force: false
    )
    
    UI.success("Metadata downloaded to ./fastlane/metadata")
  end

  desc "Upload metadata and screenshots"
  lane :upload_all_metadata do
    metadata
    screenshots
    
    UI.success("All metadata and screenshots uploaded!")
  end

  # ============================================
  # BUILD
  # ============================================

  desc "Generate Xcode project"
  lane :generate do
    sh("cd .. && xcodegen generate")
    UI.success("Xcode project generated!")
  end

  desc "Build app for App Store"
  lane :build do
    # Sync certificates first
    certs
    
    # Generate project
    generate
    
    # Clean build folder
    sh("cd .. && rm -rf build")
    
    # Build
    build_app(
      scheme: "What2WatchAI",
      workspace: nil,
      project: "../What2WatchAI.xcodeproj",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "./build",
      output_name: "What2WatchAI.ipa",
      clean: true,
      include_bitcode: false,
      export_options: {
        provisioningProfiles: {
          "com.what2watchai.app" => "match AppStore com.what2watchai.app",
          "com.what2watchai.app.widgets" => "match AppStore com.what2watchai.app.widgets"
        }
      }
    )
    
    UI.success("Build complete! IPA at ./fastlane/build/What2WatchAI.ipa")
  end

  # ============================================
  # DISTRIBUTION
  # ============================================

  desc "Upload to TestFlight"
  lane :beta do
    build
    
    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: false,
      distribute_external: false,
      notify_external_testers: false,
      changelog: "Bug fixes and improvements"
    )
    
    UI.success("Build uploaded to TestFlight!")
  end

  desc "Upload to TestFlight and distribute to testers"
  lane :beta_distribute do
    build
    
    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: false,
      distribute_external: true,
      notify_external_testers: true,
      groups: ["Beta Testers"],
      changelog: read_changelog
    )
    
    UI.success("Build distributed to beta testers!")
  end

  desc "Submit to App Store Review"
  lane :release do
    build
    
    deliver(
      api_key: api_key,
      ipa: "./build/What2WatchAI.ipa",
      submit_for_review: true,
      automatic_release: false,
      force: true,
      precheck_include_in_app_purchases: false,
      submission_information: {
        add_id_info_uses_idfa: false,
        content_rights_has_rights: true,
        content_rights_contains_third_party_content: true,
        export_compliance_uses_encryption: false
      }
    )
    
    UI.success("App submitted for review!")
  end

  # ============================================
  # UTILITIES
  # ============================================

  desc "Increment build number"
  lane :bump do
    increment_build_number(
      build_number: latest_testflight_build_number(api_key: api_key) + 1
    )
    
    build_num = get_build_number
    UI.success("Build number: #{build_num}")
  end

  desc "Increment version number"
  lane :bump_version do |options|
    type = options[:type] || "patch"  # major, minor, patch
    
    increment_version_number(
      bump_type: type
    )
    
    version = get_version_number
    UI.success("Version: #{version}")
  end

  desc "Check app status"
  lane :status do
    app_status = app_store_build_number(
      api_key: api_key,
      app_identifier: "com.what2watchai.app",
      live: false
    )
    
    UI.message("Latest TestFlight build: #{app_status}")
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  def read_changelog
    changelog_path = "../CHANGELOG.md"
    if File.exist?(changelog_path)
      File.read(changelog_path).split("\n\n").first
    else
      "Bug fixes and improvements"
    end
  end

end
```

### 2.3 Deliverfile

Create `fastlane/Deliverfile`:

```ruby
# Deliverfile for What2WatchAI

# App identifier
app_identifier("com.what2watchai.app")

# Metadata path
metadata_path("./fastlane/metadata")

# Screenshots path
screenshots_path("./fastlane/screenshots")

# Skip binary upload when just updating metadata
# skip_binary_upload(true)

# Skip screenshots when just updating metadata
# skip_screenshots(true)

# Force overwrite
force(true)

# Don't submit for review automatically
submit_for_review(false)

# Don't release automatically after approval
automatic_release(false)

# Precheck settings
precheck_include_in_app_purchases(false)

# Platform
platform("ios")

# Primary language
primary_language("en-US")

# Price tier (0 = free)
price_tier(0)

# Primary category
primary_category("Entertainment")

# Secondary category (optional)
# secondary_category("Photo & Video")

# App review information
app_review_information(
  first_name: "Your",
  last_name: "Name",
  phone_number: "+1 555 555 5555",
  email_address: "review@what2watchai.com",
  demo_user: "",
  demo_password: "",
  notes: "No login required. All features available without account."
)

# Submission information
submission_information({
  add_id_info_uses_idfa: false,
  content_rights_has_rights: true,
  content_rights_contains_third_party_content: true,
  export_compliance_uses_encryption: false
})
```

### 2.4 Matchfile (For Code Signing)

Create `fastlane/Matchfile`:

```ruby
# Matchfile for What2WatchAI

# Git repo for storing certificates (create a private repo)
git_url("https://github.com/YOUR_USERNAME/certificates.git")

# Storage mode
storage_mode("git")

# App identifiers
app_identifier([
  "com.what2watchai.app",
  "com.what2watchai.app.widgets"
])

# Apple ID
username("YOUR_APPLE_ID@email.com")

# Team ID
team_id("CY89UC5Z6Z")

# Type (appstore, adhoc, development)
type("appstore")

# Don't clone the repo each time
shallow_clone(true)

# Force to update existing certificates
# force(true)

# Read-only mode (safe for CI)
readonly(true)
```

---

## Part 3: Metadata Files

### 3.1 Create Metadata Directory

```bash
mkdir -p fastlane/metadata/en-US
```

### 3.2 Create Metadata Files

**name.txt:**
```
What2WatchAI
```

**subtitle.txt:**
```
AI Movie Discovery & Watchlist
```

**description.txt:**
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

**keywords.txt:** (max 100 characters)
```
movies,watchlist,recommendations,AI,trailers,discover,cinema,film,watch,tonight
```

**promotional_text.txt:** (max 170 characters)
```
Discover your next favorite movie with AI-powered recommendations and a beautiful, intuitive interface.
```

**privacy_url.txt:**
```
https://what2watchai.com/privacy
```

**support_url.txt:**
```
https://what2watchai.com/support
```

**marketing_url.txt:**
```
https://what2watchai.com
```

**release_notes.txt:**
```
What's New in Version 1.0:

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

**primary_category.txt:**
```
Entertainment
```

---

## Part 4: Screenshots Setup

### 4.1 Required Sizes

```bash
mkdir -p "fastlane/screenshots/en-US/iPhone 6.9-inch"
mkdir -p "fastlane/screenshots/en-US/iPhone 6.7-inch"
mkdir -p "fastlane/screenshots/en-US/iPhone 6.5-inch"
mkdir -p "fastlane/screenshots/en-US/iPad Pro 12.9-inch"
```

### 4.2 Screenshot Specifications

| Device | Resolution | Required |
|--------|------------|----------|
| iPhone 6.9" | 1320 x 2868 | Yes |
| iPhone 6.7" | 1290 x 2796 | Yes |
| iPhone 6.5" | 1284 x 2778 | Yes |
| iPad Pro 12.9" | 2048 x 2732 | If iPad |

### 4.3 Naming Convention

```
fastlane/screenshots/en-US/iPhone 6.9-inch/
├── 01_discover.png
├── 02_swipe.png
├── 03_tonight.png
├── 04_watchlist.png
├── 05_details.png
└── 06_live_activity.png
```

---

## Part 5: Common Commands

### Setup Commands

```bash
# Initial setup (creates app in App Store Connect)
fastlane setup

# Register app only
fastlane register_app

# Enable capabilities
fastlane enable_capabilities
```

### Code Signing

```bash
# Sync existing certificates
fastlane certs

# Create new certificates
fastlane certs_new

# Development certificates
fastlane certs_dev
```

### Metadata

```bash
# Upload metadata
fastlane metadata

# Upload screenshots
fastlane screenshots

# Upload everything
fastlane upload_all_metadata

# Download existing metadata
fastlane download_metadata
```

### Build & Deploy

```bash
# Generate Xcode project
fastlane generate

# Build IPA
fastlane build

# Upload to TestFlight
fastlane beta

# Submit to App Store
fastlane release
```

### Version Management

```bash
# Increment build number
fastlane bump

# Increment version (patch: 1.0.0 -> 1.0.1)
fastlane bump_version type:patch

# Increment version (minor: 1.0.0 -> 1.1.0)
fastlane bump_version type:minor

# Increment version (major: 1.0.0 -> 2.0.0)
fastlane bump_version type:major
```

---

## Part 6: Troubleshooting

### Common Errors

**"No valid signing identity"**
```bash
fastlane certs_new
```

**"App identifier does not exist"**
```bash
fastlane register_app
```

**"Invalid API key"**
- Check key file path
- Verify key hasn't expired
- Ensure key has correct permissions

**"Screenshots rejected"**
- No placeholder text ("Lorem ipsum")
- No "beta" or "test" labels
- Must show actual app content

**"Metadata too long"**
- Description: max 4000 characters
- Keywords: max 100 characters
- Subtitle: max 30 characters
- Promotional text: max 170 characters

### Debug Commands

```bash
# Verbose output
fastlane beta --verbose

# List all lanes
fastlane lanes

# Check environment
fastlane env
```

---

## Part 7: CI/CD Integration

### GitHub Actions Example

```yaml
name: iOS Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-14
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.2'
        bundler-cache: true
    
    - name: Install Fastlane
      run: gem install fastlane
    
    - name: Setup API Key
      run: |
        echo "${{ secrets.APP_STORE_CONNECT_KEY }}" > AppSetUpKit/auth_key.p8
    
    - name: Build and Upload
      run: fastlane beta
      env:
        MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
```

---

Document Version: 1.0
Last Updated: January 2026
