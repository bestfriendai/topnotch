#!/bin/bash

# AppSetupKit - Swift/iOS Native Setup
# Updated: February 2026
#
# Targets: Xcode 26.2 / Swift 6.2 / iOS 18+ / SPM only
# CocoaPods is sunsetting (read-only Dec 2, 2026) - this script uses SPM exclusively
#
# Requirements:
# - macOS with Xcode 26+
# - Fastlane 2.232+
# - Swift Package Manager (built into Xcode)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok() { echo -e "${GREEN}  [ok]${NC} $1"; }
fail() { echo -e "${RED}  [!!]${NC} $1"; }
info() { echo -e "${BLUE}  [..]${NC} $1"; }
warn() { echo -e "${YELLOW}  [!!]${NC} $1"; }

echo -e "\n${BOLD}${MAGENTA}  AppSetupKit - Swift/iOS Setup (Feb 2026)${NC}\n"

# Prerequisites
echo -e "${BOLD}Checking prerequisites...${NC}"

if ! command -v xcodebuild &> /dev/null; then
    fail "Xcode not installed. Get it from the App Store."
    exit 1
fi

XCODE_VER=$(xcodebuild -version | head -1 | awk '{print $2}')
ok "Xcode $XCODE_VER"

XCODE_MAJOR=$(echo "$XCODE_VER" | cut -d. -f1)
if [ "$XCODE_MAJOR" -lt 26 ] 2>/dev/null; then
    warn "Xcode $XCODE_VER detected. Xcode 26+ recommended (required by April 28, 2026)."
fi

if ! command -v fastlane &> /dev/null; then
    warn "Fastlane not installed."
    read -p "  Install now? (y/n): " INSTALL_FL
    if [ "$INSTALL_FL" = "y" ]; then
        gem install fastlane
    else
        fail "Fastlane required. Install with: gem install fastlane"
        exit 1
    fi
fi
ok "Fastlane $(fastlane --version 2>/dev/null | tail -1 || echo 'installed')"

HAS_XCODEGEN=false
if command -v xcodegen &> /dev/null; then
    ok "XcodeGen $(xcodegen --version 2>/dev/null || echo 'installed')"
    HAS_XCODEGEN=true
else
    info "XcodeGen not found (optional). Install: brew install xcodegen"
fi

# Gather info
echo ""
echo -e "${BOLD}Project Configuration${NC}"
echo ""

read -p "  App Name: " APP_NAME
read -p "  Bundle ID (e.g. com.company.app): " BUNDLE_ID
read -p "  Apple ID Email: " APPLE_ID
read -p "  Apple Team ID: " TEAM_ID
read -p "  Organization Name: " ORG_NAME

PROJECT_NAME="${APP_NAME// /}"
PROJECT_DIR="${PROJECT_NAME}"

echo ""
read -p "  Enable Sign in with Apple? (y/n): " ENABLE_APPLE
read -p "  Enable Google Sign-In? (y/n): " ENABLE_GOOGLE
read -p "  Enable Push Notifications? (y/n): " ENABLE_PUSH

# Deployment target
echo ""
echo -e "${DIM}  Common targets: 17.0 (89% coverage), 18.0 (75%), 26.0 (bleeding edge)${NC}"
read -p "  Minimum iOS deployment target [18.0]: " IOS_TARGET
IOS_TARGET=${IOS_TARGET:-18.0}

# Create project
echo ""
echo -e "${BOLD}Step 1: Creating project structure${NC}"

if [ -d "$PROJECT_DIR" ]; then
    warn "Directory $PROJECT_DIR exists."
    read -p "  Continue? (y/n): " CONT
    [ "$CONT" != "y" ] && exit 0
else
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# XcodeGen project.yml
if [ "$HAS_XCODEGEN" = true ]; then
    cat > project.yml <<EOF
name: $PROJECT_NAME
options:
  bundleIdPrefix: ${BUNDLE_ID%.*}
  deploymentTarget:
    iOS: "$IOS_TARGET"
  xcodeVersion: "26.2"
settings:
  base:
    DEVELOPMENT_TEAM: $TEAM_ID
    SWIFT_VERSION: "6.2"
    IPHONEOS_DEPLOYMENT_TARGET: "$IOS_TARGET"
targets:
  $PROJECT_NAME:
    type: application
    platform: iOS
    sources:
      - $PROJECT_NAME
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID
      INFOPLIST_FILE: $PROJECT_NAME/Info.plist
    dependencies: []
EOF
    ok "project.yml created (XcodeGen)"
fi

# Source files
mkdir -p "$PROJECT_NAME"

cat > "${PROJECT_NAME}/${PROJECT_NAME}App.swift" <<EOF
import SwiftUI

@main
struct ${PROJECT_NAME}App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

cat > "${PROJECT_NAME}/ContentView.swift" <<EOF
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, $APP_NAME!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
EOF

cat > "${PROJECT_NAME}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
EOF

ok "Swift source files created."

# AppConfig
cat > "${PROJECT_NAME}/AppConfig.swift" <<EOF
import Foundation

struct AppConfig {
    static let appName = "$APP_NAME"
    static let bundleId = "$BUNDLE_ID"

    struct Supabase {
        static let url = "YOUR_SUPABASE_URL"
        static let anonKey = "YOUR_SUPABASE_ANON_KEY"
    }

    struct Firebase {
        static let projectId = "YOUR_FIREBASE_PROJECT_ID"
    }

    struct RevenueCat {
        static let apiKey = "YOUR_REVENUECAT_API_KEY"
    }
}
EOF

ok "AppConfig.swift created."

# Auth helpers
if [ "$ENABLE_APPLE" = "y" ]; then
    cat > "${PROJECT_NAME}/AppleSignInHelper.swift" <<'SWIFTEOF'
import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @Environment(\.colorScheme) var colorScheme

    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: onCompletion
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
    }
}
SWIFTEOF
    ok "AppleSignInHelper.swift created."
fi

if [ "$ENABLE_GOOGLE" = "y" ]; then
    cat > "${PROJECT_NAME}/GoogleSignInHelper.swift" <<'SWIFTEOF'
import Foundation
import GoogleSignIn

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()

    func signIn(presenting viewController: UIViewController) async throws -> GIDGoogleUser {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        return result.user
    }
}
SWIFTEOF
    ok "GoogleSignInHelper.swift (async/await)."
fi

# Generate Xcode project
if [ "$HAS_XCODEGEN" = true ]; then
    echo ""
    echo -e "${BOLD}Generating Xcode project...${NC}"
    xcodegen generate
    ok "Xcode project generated."
fi

# Fastlane
echo ""
echo -e "${BOLD}Step 2: App Store Connect (Fastlane)${NC}"

mkdir -p fastlane

if [ -f "../appsetupkit.p8" ]; then
    cp ../appsetupkit.p8 fastlane/auth_key.p8
    ok "API key copied."
fi

# Read key_id and issuer_id from appsetupkit.json if available
KEY_ID="PRKWBSZ4FZ"
ISSUER_ID="d379ef5a-740b-4b80-bc48-8e1526fc03d3"
if [ -f "../appsetupkit.json" ] && command -v jq &> /dev/null; then
    KEY_ID=$(jq -r '.key_id // "PRKWBSZ4FZ"' ../appsetupkit.json)
    ISSUER_ID=$(jq -r '.issuer_id // "d379ef5a-740b-4b80-bc48-8e1526fc03d3"' ../appsetupkit.json)
fi

cat > fastlane/Fastfile <<EOF
api_key = app_store_connect_api_key(
  key_id: "$KEY_ID",
  issuer_id: "$ISSUER_ID",
  key_filepath: "./fastlane/auth_key.p8",
  duration: 1200
)

default_platform(:ios)

platform :ios do

  desc "Register app and enable capabilities"
  lane :setup do
    produce(
      app_identifier: "$BUNDLE_ID",
      app_name: "$APP_NAME",
      language: "English",
      app_version: "1.0.0",
      sku: "${BUNDLE_ID}.sku",
      api_key: api_key
    )
EOF

[ "$ENABLE_APPLE" = "y" ] && cat >> fastlane/Fastfile <<EOF

    enable_app_capability(
      app_identifier: "$BUNDLE_ID",
      capability: "sign_in_with_apple",
      api_key: api_key
    )
EOF

[ "$ENABLE_PUSH" = "y" ] && cat >> fastlane/Fastfile <<EOF

    enable_app_capability(
      app_identifier: "$BUNDLE_ID",
      capability: "push_notifications",
      api_key: api_key
    )
EOF

cat >> fastlane/Fastfile <<EOF

    UI.success("App registered!")
  end

  desc "Upload metadata"
  lane :metadata do
    deliver(
      api_key: api_key,
      app_identifier: "$BUNDLE_ID",
      skip_binary_upload: true,
      skip_screenshots: false,
      force: true,
      metadata_path: "./fastlane/metadata"
    )
  end

  desc "Build for App Store"
  lane :build do
    build_app(
      scheme: "$PROJECT_NAME",
      export_method: "app-store",
      output_directory: "./build"
    )
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    build
    upload_to_testflight(api_key: api_key)
  end

  desc "Submit for review"
  lane :release do
    build
    deliver(
      api_key: api_key,
      submit_for_review: true,
      automatic_release: false
    )
  end

end
EOF

cat > fastlane/Appfile <<EOF
app_identifier("$BUNDLE_ID")
apple_id("$APPLE_ID")
team_id("$TEAM_ID")
EOF

ok "Fastlane configured."

# MCP config
echo ""
echo -e "${BOLD}Step 3: MCP Server Configuration${NC}"

cat > mcp-config.json <<EOF
{
  "mcpServers": {
    "firebase": {
      "command": "npx",
      "args": ["-y", "firebase-tools@latest", "mcp"]
    },
    "supabase": {
      "transport": "http",
      "url": "https://mcp.supabase.com/mcp"
    },
    "revenuecat": {
      "transport": "http",
      "url": "https://mcp.revenuecat.ai/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_REVENUECAT_SECRET_KEY"
      }
    },
    "app-store-connect": {
      "command": "npx",
      "args": ["@joshuarileydev/app-store-connect-mcp-server"]
    },
    "xcode": {
      "command": "npx",
      "args": ["xcodebuildmcp@latest"]
    },
    "apple-docs": {
      "command": "npx",
      "args": ["apple-doc-mcp-server@latest"]
    }
  }
}
EOF

ok "MCP config created."

# Git
echo ""
echo -e "${BOLD}Step 4: Git Repository${NC}"

if [ ! -d ".git" ]; then
    git init

    cat > .gitignore <<'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcworkspace/contents.xcworkspacedata
*.xcuserstate
xcuserdata/
DerivedData/
.build/

# SPM
.swiftpm/
Package.resolved

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots
fastlane/test_output
fastlane/*.ipa
fastlane/auth_key.p8

# Signing
*.mobileprovision
*.cer
*.p12

# Other
.DS_Store
*.swp
*~
setup-state.json
swift-setup-state.json
EOF

    git add .
    git commit -m "Initial commit: $APP_NAME iOS app"
    ok "Git repository initialized."
fi

# SPM dependencies
echo ""
echo -e "${BOLD}Step 5: Swift Package Manager Dependencies${NC}"
echo ""
echo -e "  Add these packages in Xcode (File > Add Package Dependencies):"
echo ""
echo -e "  ${CYAN}https://github.com/firebase/firebase-ios-sdk${NC}          ${DIM}(12.x - Auth, Messaging)${NC}"
echo -e "  ${CYAN}https://github.com/google/GoogleSignIn-iOS${NC}            ${DIM}(latest)${NC}"
echo -e "  ${CYAN}https://github.com/supabase/supabase-swift${NC}            ${DIM}(latest)${NC}"
echo -e "  ${CYAN}https://github.com/RevenueCat/purchases-ios${NC}           ${DIM}(5.x)${NC}"
echo -e "  ${CYAN}https://github.com/onevcat/Kingfisher${NC}                 ${DIM}(latest)${NC}"

# Summary
echo ""
echo -e "${BOLD}${GREEN}Setup Complete!${NC}"
echo ""
echo -e "  Project: ${BOLD}$APP_NAME${NC}"
echo -e "  Bundle:  $BUNDLE_ID"
echo -e "  Target:  iOS $IOS_TARGET"
echo -e "  Swift:   6.2 (Xcode 26)"
echo -e "  Location: $(pwd)"
echo ""
echo -e "${BOLD}Next:${NC}"
if [ "$HAS_XCODEGEN" = true ]; then
    echo -e "  open ${PROJECT_NAME}.xcodeproj"
else
    echo -e "  xcodegen generate && open ${PROJECT_NAME}.xcodeproj"
fi
echo -e "  Add SPM dependencies (see above)"
echo -e "  Add GoogleService-Info.plist"
echo -e "  Configure signing in Xcode"
echo ""
echo -e "${BOLD}Fastlane:${NC}"
echo -e "  fastlane setup      # Register in App Store Connect"
echo -e "  fastlane beta       # Build + TestFlight"
echo -e "  fastlane release    # Submit for review"
echo ""
echo -e "${BOLD}Key dates:${NC}"
echo -e "  ${YELLOW}Apr 28, 2026${NC} - Apps must use iOS 26 SDK (Xcode 26+)"
echo -e "  ${YELLOW}Dec 2, 2026${NC}  - CocoaPods Trunk goes read-only"
echo ""
