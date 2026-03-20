#!/bin/bash

# AppSetupKit - Prerequisites Checker
# Updated: February 2026

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${BOLD}${BLUE}AppSetupKit - Prerequisites Check (Feb 2026)${NC}\n"

MISSING=0

check() {
    local name="$1"
    local cmd="$2"
    local install="$3"
    local required="$4"

    if command -v "$cmd" &> /dev/null; then
        local ver
        ver=$($cmd --version 2>/dev/null | head -1 || echo "installed")
        echo -e "${GREEN}  [ok]${NC} $name ($ver)"
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}  [missing]${NC} $name - ${YELLOW}$install${NC}"
            MISSING=$((MISSING + 1))
        else
            echo -e "${YELLOW}  [optional]${NC} $name - $install"
        fi
    fi
}

echo -e "${BOLD}System:${NC}"
check "Node.js (>=20)" "node" "Install from https://nodejs.org (v22 LTS recommended, v20 EOL Apr 2026)" "required"
check "Git" "git" "xcode-select --install" "required"

NODE_VER=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -n "$NODE_VER" ] && [ "$NODE_VER" -lt 20 ]; then
    echo -e "${YELLOW}    WARNING: Node.js $NODE_VER detected. Minimum v20 required.${NC}"
    echo -e "${YELLOW}    Recommended: Node.js 22 LTS. Install via: brew install node@22${NC}"
elif [ -n "$NODE_VER" ] && [ "$NODE_VER" -eq 20 ]; then
    echo -e "${YELLOW}    Node.js 20 works but EOL April 2026. Consider upgrading to v22 LTS.${NC}"
fi

echo ""
echo -e "${BOLD}iOS Development:${NC}"
check "Xcode (26+)" "xcodebuild" "Install from App Store (Xcode 26.2 is current)" "required"
check "Fastlane (2.232+)" "fastlane" "gem install fastlane" "required"
check "XcodeGen" "xcodegen" "brew install xcodegen (v2.44+)" "optional"

XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}' || echo "0")
if [ "$XCODE_VER" != "0" ]; then
    XCODE_MAJOR=$(echo "$XCODE_VER" | cut -d. -f1)
    if [ "$XCODE_MAJOR" -lt 26 ] 2>/dev/null; then
        echo -e "${YELLOW}    WARNING: Xcode $XCODE_VER detected. Xcode 26+ required (iOS 26 SDK).${NC}"
        echo -e "${YELLOW}    Apps must be built with iOS 26 SDK by April 28, 2026.${NC}"
    fi
fi

echo ""
echo -e "${BOLD}React Native / Expo:${NC}"
check "EAS CLI" "eas" "npm install -g eas-cli" "optional"

echo ""
echo -e "${BOLD}Backend Services:${NC}"
check "Firebase CLI" "firebase" "npm install -g firebase-tools" "optional"
check "Supabase CLI" "supabase" "brew install supabase/tap/supabase (v2.76+)" "optional"
check "Google Cloud SDK" "gcloud" "brew install google-cloud-sdk" "optional"

echo ""
echo -e "${BOLD}Credentials:${NC}"
if [ -f "appsetupkit.p8" ]; then
    echo -e "${GREEN}  [ok]${NC} App Store Connect API key (appsetupkit.p8)"
else
    echo -e "${YELLOW}  [missing]${NC} appsetupkit.p8 - Create at https://appstoreconnect.apple.com/access/integrations/api"
fi

if [ -f "appsetupkit.json" ]; then
    echo -e "${GREEN}  [ok]${NC} API credentials config (appsetupkit.json)"
else
    echo -e "${YELLOW}  [missing]${NC} appsetupkit.json"
fi

echo ""
echo -e "${BOLD}Important Notes for 2026:${NC}"
echo -e "  ${CYAN}*${NC} CocoaPods goes read-only Dec 2, 2026 - use Swift Package Manager"
echo -e "  ${CYAN}*${NC} Node.js 20 EOL: April 30, 2026 - upgrade to v22 or v24 LTS"
echo -e "  ${CYAN}*${NC} Apps must use iOS 26 SDK (Xcode 26+) by April 28, 2026"
echo -e "  ${CYAN}*${NC} Expo SDK 54 (stable): RN 0.81, React 19.1, Expo Router v6"
echo -e "  ${CYAN}*${NC} SDK 54 is the last SDK supporting Legacy Architecture (newArchEnabled flag)"
echo -e "  ${CYAN}*${NC} react-native-purchases requires a dev client build (not Expo Go)"
echo -e "  ${CYAN}*${NC} Firebase iOS SDK 12.x has breaking changes from 11.x"

echo ""
if [ "$MISSING" -gt 0 ]; then
    echo -e "${RED}$MISSING required tool(s) missing. Install them before continuing.${NC}"
    exit 1
else
    echo -e "${GREEN}All required tools installed. Run 'npm start' to begin setup.${NC}"
fi
