#!/bin/bash

# Fastlane Metadata Setup - February 2026
# Creates App Store metadata files for fastlane deliver
# Screenshot sizes updated for iPhone 16 Pro Max and current devices

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

echo -e "\n${BLUE}  Fastlane Metadata Setup (Feb 2026)${NC}\n"

if ! command -v fastlane &> /dev/null; then
    echo -e "${RED}  Fastlane not installed. Install: gem install fastlane${NC}"
    exit 1
fi

read -p "  App bundle ID: " BUNDLE_ID
read -p "  App name: " APP_NAME
read -p "  Subtitle (max 30 chars): " SUBTITLE
read -p "  Primary category (e.g. ENTERTAINMENT, PRODUCTIVITY): " PRIMARY_CATEGORY

METADATA_DIR="./fastlane/metadata/en-US"
mkdir -p "$METADATA_DIR"

echo ""

# Name
echo "$APP_NAME" > "$METADATA_DIR/name.txt"
echo -e "${GREEN}  [ok]${NC} name.txt"

# Subtitle
echo "$SUBTITLE" > "$METADATA_DIR/subtitle.txt"
echo -e "${GREEN}  [ok]${NC} subtitle.txt"

# Description
echo -e "\n  Enter description (or 'file' to provide a file path):"
read -p "  > " DESC_INPUT
if [ "$DESC_INPUT" = "file" ]; then
    read -p "  Path to description file: " DESC_FILE
    cp "$DESC_FILE" "$METADATA_DIR/description.txt"
else
    cat > "$METADATA_DIR/description.txt" <<EOF
$APP_NAME

$DESC_INPUT

KEY FEATURES:
- Feature 1
- Feature 2
- Feature 3

Download $APP_NAME today!
EOF
fi
echo -e "${GREEN}  [ok]${NC} description.txt"

# Keywords
echo -e "\n${DIM}  Keywords: comma-separated, max 100 chars total, no spaces after commas${NC}"
echo -e "${DIM}  Tip: Use singular forms, don't repeat words from app name or subtitle${NC}"
read -p "  Keywords: " KEYWORDS
echo "$KEYWORDS" > "$METADATA_DIR/keywords.txt"
echo -e "${GREEN}  [ok]${NC} keywords.txt"

# Promotional text
read -p "  Promotional text (max 170 chars): " PROMO
echo "$PROMO" > "$METADATA_DIR/promotional_text.txt"
echo -e "${GREEN}  [ok]${NC} promotional_text.txt"

# URLs
read -p "  Marketing URL: " MARKETING_URL
echo "$MARKETING_URL" > "$METADATA_DIR/marketing_url.txt"

read -p "  Privacy Policy URL: " PRIVACY_URL
echo "$PRIVACY_URL" > "$METADATA_DIR/privacy_url.txt"

read -p "  Support URL: " SUPPORT_URL
echo "$SUPPORT_URL" > "$METADATA_DIR/support_url.txt"

echo -e "${GREEN}  [ok]${NC} URL files"

# Release notes
cat > "$METADATA_DIR/release_notes.txt" <<EOF
Initial Release

- Launch version
- Core functionality

Thank you for downloading $APP_NAME!
EOF
echo -e "${GREEN}  [ok]${NC} release_notes.txt"

# Category
echo "$PRIMARY_CATEGORY" > "$METADATA_DIR/../primary_category.txt"
echo -e "${GREEN}  [ok]${NC} primary_category.txt"

# Deliverfile
cat > "./fastlane/Deliverfile" <<EOF
app_identifier("$BUNDLE_ID")
skip_binary_upload(true)
skip_screenshots(false)
metadata_path("./fastlane/metadata")
force(true)
submit_for_review(false)
automatic_release(false)
precheck_include_in_app_purchases(false)
platform("ios")
languages(["en-US"])
price_tier(0)
EOF
echo -e "${GREEN}  [ok]${NC} Deliverfile"

# Screenshots directory
mkdir -p "./fastlane/screenshots/en-US"

echo -e "\n${GREEN}  Metadata setup complete!${NC}\n"
echo "  Screenshot sizes required (2026):"
echo ""
echo "    iPhone 6.9\" (1320x2868) - iPhone 16 Pro Max"
echo "    iPhone 6.7\" (1290x2796) - iPhone 15 Pro Max"
echo "    iPhone 6.5\" (1284x2778) - iPhone 14 Pro Max"
echo "    iPad Pro 13\" (2064x2752)"
echo "    iPad Pro 12.9\" (2048x2732)"
echo ""
echo "  Upload metadata:"
echo "    fastlane deliver"
echo ""
echo "  Download existing metadata first:"
echo "    fastlane deliver download_metadata"
echo ""
