#!/bin/bash

# Supabase Auth Setup - February 2026
# Configures auth providers via Management API
# Default auth flow is now PKCE (Proof Key for Code Exchange)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

echo -e "\n${BLUE}  Supabase Auth Setup (Feb 2026)${NC}\n"

read -p "  Supabase project reference: " PROJECT_REF
echo -e "${DIM}  Get token from: https://supabase.com/dashboard/account/tokens${NC}"
read -p "  Supabase access token: " ACCESS_TOKEN

API_URL="https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth"

patch() {
    curl -s -X PATCH "$API_URL" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$1"
}

echo ""

# Auth providers
read -p "  Enable Sign in with Apple? (y/n): " ENABLE_APPLE
read -p "  Enable Google Sign-In? (y/n): " ENABLE_GOOGLE

# Apple
if [ "$ENABLE_APPLE" = "y" ]; then
    echo -e "\n${BLUE}  Configuring Apple Sign-In...${NC}"

    read -p "  Apple Services ID: " APPLE_CLIENT_ID
    read -p "  Path to .p8 key: " APPLE_KEY_PATH

    if [ ! -f "$APPLE_KEY_PATH" ]; then
        echo -e "${RED}  File not found: $APPLE_KEY_PATH${NC}"
        exit 1
    fi

    APPLE_SECRET=$(cat "$APPLE_KEY_PATH")

    APPLE_CONFIG=$(cat <<EOF
{
  "EXTERNAL_APPLE_ENABLED": true,
  "EXTERNAL_APPLE_CLIENT_ID": "$APPLE_CLIENT_ID",
  "EXTERNAL_APPLE_SECRET": $(echo "$APPLE_SECRET" | jq -Rs .),
  "EXTERNAL_APPLE_REDIRECT_URI": "https://${PROJECT_REF}.supabase.co/auth/v1/callback"
}
EOF
)

    RESPONSE=$(patch "$APPLE_CONFIG")

    if echo "$RESPONSE" | grep -q "error"; then
        echo -e "${RED}  Error:${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        echo -e "${GREEN}  [ok] Apple Sign-In configured${NC}"
        echo ""
        echo "  Add redirect URL in Apple Developer Portal:"
        echo "  https://${PROJECT_REF}.supabase.co/auth/v1/callback"
    fi
fi

# Google
if [ "$ENABLE_GOOGLE" = "y" ]; then
    echo -e "\n${BLUE}  Configuring Google Sign-In...${NC}"

    read -p "  Google OAuth Client ID: " GOOGLE_CLIENT_ID
    read -p "  Google OAuth Client Secret: " GOOGLE_CLIENT_SECRET

    GOOGLE_CONFIG=$(cat <<EOF
{
  "EXTERNAL_GOOGLE_ENABLED": true,
  "EXTERNAL_GOOGLE_CLIENT_ID": "$GOOGLE_CLIENT_ID",
  "EXTERNAL_GOOGLE_SECRET": "$GOOGLE_CLIENT_SECRET",
  "EXTERNAL_GOOGLE_REDIRECT_URI": "https://${PROJECT_REF}.supabase.co/auth/v1/callback"
}
EOF
)

    RESPONSE=$(patch "$GOOGLE_CONFIG")

    if echo "$RESPONSE" | grep -q "error"; then
        echo -e "${RED}  Error:${NC}"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        echo -e "${GREEN}  [ok] Google Sign-In configured${NC}"
        echo ""
        echo "  Add redirect URL in Google Cloud Console:"
        echo "  https://${PROJECT_REF}.supabase.co/auth/v1/callback"
    fi
fi

# General auth settings (PKCE is now default)
echo -e "\n${BLUE}  Configuring auth settings...${NC}"

read -p "  Site URL (e.g. https://yourapp.com): " SITE_URL
read -p "  Enable email confirmations? (y/n): " EMAIL_CONFIRM

MAILER_AUTOCONFIRM="true"
[ "$EMAIL_CONFIRM" = "y" ] && MAILER_AUTOCONFIRM="false"

AUTH_SETTINGS=$(cat <<EOF
{
  "SITE_URL": "$SITE_URL",
  "MAILER_AUTOCONFIRM": $MAILER_AUTOCONFIRM,
  "EXTERNAL_EMAIL_ENABLED": true,
  "JWT_EXP": 3600,
  "REFRESH_TOKEN_ROTATION_ENABLED": true,
  "SECURITY_REFRESH_TOKEN_REUSE_INTERVAL": 10
}
EOF
)

RESPONSE=$(patch "$AUTH_SETTINGS")

if echo "$RESPONSE" | grep -q "error"; then
    echo -e "${YELLOW}  Some settings may not have applied.${NC}"
else
    echo -e "${GREEN}  [ok] Auth settings configured (PKCE default)${NC}"
fi

# Database schema
echo -e "\n${BLUE}  Creating database schema...${NC}"

cat > supabase_auth_schema.sql <<'EOF'
-- Profiles table with RLS
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Updated at trigger
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.profiles;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
EOF

echo -e "${GREEN}  [ok] supabase_auth_schema.sql${NC}"

# Summary
echo -e "\n${GREEN}  Auth setup complete!${NC}\n"
echo "  Project: https://supabase.com/dashboard/project/${PROJECT_REF}"
echo "  Callback: https://${PROJECT_REF}.supabase.co/auth/v1/callback"
echo ""
echo "  Apply schema:"
echo "    supabase db push"
echo "    Or run in SQL Editor at the Supabase dashboard"
echo ""
echo "  Get API keys:"
echo "    supabase projects api-keys --project-ref ${PROJECT_REF}"
echo ""
echo "  Note: PKCE is the default auth flow in 2026."
echo "  Supabase also supports OAuth 2.1 server capabilities."
echo "  Docs: https://supabase.com/docs/guides/auth"
echo ""
