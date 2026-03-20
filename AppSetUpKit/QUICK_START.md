# AppSetupKit - Quick Start Guide

**Updated: February 2026**

Launch a new Swift or Expo app from zero to App Store.

---

## Prerequisites

```bash
# Node.js 20+ (22 LTS recommended - Node 20 EOL April 2026)
node -v

# Fastlane 2.232+
gem install fastlane

# XcodeGen (optional, for Swift projects)
brew install xcodegen

# Verify Xcode 26+ (required for iOS 26 SDK by April 28, 2026)
xcodebuild -version

# Check everything
cd appsetupkit && bash check-prerequisites.sh
```

---

## Option A: Interactive Setup (Recommended)

Supports both Swift and Expo projects:

```bash
cd appsetupkit
node setup.js
```

This walks you through:
1. Project type selection (Swift or Expo)
2. Project scaffolding
3. App Store Connect registration (Fastlane)
4. Supabase project + auth providers
5. Firebase project + config files
6. Dependencies (SPM for Swift, npx expo install for Expo)
7. MCP server config for AI-assisted development

---

## Option B: Swift Only (Bash)

```bash
cd appsetupkit
bash swift-setup.sh
```

Creates: Xcode project (via XcodeGen), Fastlane config, AppConfig.swift, MCP config, Git repo.

---

## Option C: Manual Steps

### 1. App Store Connect

```bash
# Create Fastlane directory in your project
mkdir -p fastlane/metadata/en-US

# Create Appfile
cat > fastlane/Appfile << 'EOF'
app_identifier("com.yourcompany.app")
apple_id("you@email.com")
team_id("YOUR_TEAM_ID")
EOF

# Copy API key
cp appsetupkit/appsetupkit.p8 fastlane/auth_key.p8

# Register app
fastlane setup

# Upload metadata
fastlane metadata
```

### 2. Create Metadata

```bash
cd appsetupkit
bash scripts/fastlane-metadata-setup.sh
```

### 3. Configure Auth

```bash
cd appsetupkit
bash scripts/supabase-auth-setup.sh
```

---

## Current Versions (Feb 2026)

| Tool | Version | Notes |
|------|---------|-------|
| Xcode | 26.2 | Swift 6.2, iOS 26 SDK |
| Fastlane | 2.232+ | App Store Connect API 4.2 |
| XcodeGen | 2.44+ | Tuist is an alternative |
| Node.js | 20+ (22 LTS recommended) | v20 EOL April 2026 |
| Expo SDK | 54 (stable) | New Arch default, Legacy still supported |
| React Native | 0.81 | React 19.1, Expo Router v6 |
| Firebase iOS | 12.x | Breaking changes from 11.x |
| RevenueCat iOS | 5.59+ | SPM: 5.0.0 ..< 6.0.0 |
| RevenueCat RN | 9.7+ | react-native-purchases |
| Supabase CLI | 2.76+ | PKCE auth default |
| CocoaPods | Sunsetting | Read-only Dec 2, 2026 |

---

## Key Dates

- **April 28, 2026** - Apps must be built with iOS 26 SDK (Xcode 26+)
- **April 30, 2026** - Node.js 20 end of life
- **December 2, 2026** - CocoaPods Trunk becomes permanently read-only

---

## Project Structure After Setup

```
your-app/
  project.yml              # XcodeGen config (Swift)
  YourApp/
    YourAppApp.swift
    ContentView.swift
    AppConfig.swift         # API keys and config
    Info.plist
  fastlane/
    Appfile
    Fastfile
    auth_key.p8
    metadata/en-US/         # App Store metadata
    screenshots/en-US/      # App Store screenshots
  mcp-config.json           # MCP servers for Claude Code
  GoogleService-Info.plist  # Firebase iOS config
```

---

## Expo Go vs Dev Client

**Try Expo Go first** (`npx expo start` and scan QR code). Most features work without a custom build.

You need a **development client** (`eas build --profile development`) only when using:
- `react-native-purchases` / `react-native-purchases-ui` (RevenueCat)
- Custom native modules not in Expo Go
- Apple targets (widgets, app clips)

Dev client via TestFlight (recommended for team testing):
```bash
eas build -p ios --profile development --submit
```

Local dev client:
```bash
eas build -p ios --profile development --local
```

---

## Fastlane Commands

```bash
fastlane setup      # Register app + enable capabilities
fastlane metadata   # Upload metadata to App Store Connect
fastlane build      # Build for App Store
fastlane beta       # Build + upload to TestFlight
fastlane release    # Build + submit for review
```

---

## MCP Servers

The setup creates `mcp-config.json` with these servers:
- **Firebase** - Project management
- **Supabase** - Database and auth
- **RevenueCat** - Subscriptions and paywalls
- **App Store Connect** - App management
- **Xcode** - Build integration (Swift)
- **Expo** - Project management (Expo)
- **Apple Docs** - Documentation search (Swift)

Copy to your Claude Code config or `.claude/settings.json`.

---

## Reference

- `check-prerequisites.sh` - Verify all tools are installed
- `scripts/fastlane-metadata-setup.sh` - Create App Store metadata
- `scripts/supabase-auth-setup.sh` - Configure Supabase auth
- `APP_STORE_SUBMISSION_GUIDE.md` - Full submission guide
- `ASO_METADATA_GUIDE.md` - Keywords and SEO
- `SIGN_IN_WITH_APPLE_GUIDE.md` - Apple auth setup
- `PRE_SUBMISSION_CHECKLIST.md` - Final checklist
