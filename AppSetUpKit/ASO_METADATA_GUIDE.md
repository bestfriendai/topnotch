# App Store Optimization Metadata Guide - What2WatchAI

## ASO Best Practices Applied (2026)

This document contains SEO-optimized metadata following current App Store Optimization best practices:

- Keywords field uses all 100 characters
- No word repetition between name, subtitle, and keywords
- Singular forms used (Apple indexes plural automatically)
- Commas only as separators in keywords
- No emojis or special characters
- Front-loaded description with key features visible before fold
- Localized focus on high-intent search terms

---

## App Information

App Name: What2WatchAI
Bundle ID: com.what2watchai.app
Primary Category: Entertainment
Secondary Category: Lifestyle
Age Rating: 12+

---

## Metadata Files for fastlane/metadata/en-US/

### name.txt

```
What2WatchAI
```

### subtitle.txt

Maximum 30 characters. Does not repeat words from app name.

```
Discover Movies and TV Shows
```

### keywords.txt

Maximum 100 characters. No spaces after commas. No words from name or subtitle.

```
film,recommendation,streaming,picker,tonight,tracker,list,cinema,new,release,popular,trend,suggest
```

Character count: 97

Keyword strategy:
- "film" covers movie searches
- "recommendation" high intent term
- "streaming" captures cord-cutters
- "picker" common search for decision apps
- "tonight" captures planning searches
- "tracker" watchlist functionality
- "list" common modifier
- "cinema" international term
- "new,release,popular,trend" discovery intent
- "suggest" recommendation synonym

### description.txt

First 167 characters appear before Read More. Front-load value proposition.

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

### promotional_text.txt

Maximum 170 characters. Updated frequently for seasonality.

```
New AI recommendation engine now live. Get personalized movie suggestions based on your taste. Perfect for planning your next movie night.
```

### privacy_url.txt

```
https://what2watchai.com/privacy
```

### support_url.txt

```
https://what2watchai.com/support
```

### marketing_url.txt

```
https://what2watchai.com
```

### release_notes.txt

Version 1.0 initial release notes.

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

### primary_category.txt

```
Entertainment
```

### secondary_category.txt

```
Lifestyle
```

---

## App Review Information

### review_notes.txt

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

### demo_user.txt

```
```

### demo_password.txt

```
```

Note: Leave demo credentials empty since app works without login.

---

## Screenshot Text Overlay Suggestions

Keep text minimal. Focus on benefit, not feature.

Screen 1 - Discover
Headline: Find movies you will love

Screen 2 - Swipe
Headline: Swipe to build your list

Screen 3 - Tonight
Headline: Instant recommendations

Screen 4 - Watchlist
Headline: Never forget a film

Screen 5 - Details
Headline: All the info you need

Screen 6 - Live Activity
Headline: Track from lock screen

---

## Keyword Research Notes

### High Volume Terms (Entertainment Category)

Primary targets:
- movie recommendation app
- what to watch
- movie picker
- film tracker
- watchlist app
- movie tonight
- streaming guide

### Competitor Keywords

Apps in similar space:
- Letterboxd (social, logging)
- TV Time (tracking)
- JustWatch (streaming search)
- Reelgood (catalog)

Differentiation keywords:
- AI recommendation
- swipe movies
- tonight pick
- movie decision

### Seasonal Opportunities

Update promotional_text for:
- Award season (January-March): Oscar nominees, award winners
- Summer (May-August): summer blockbusters, new releases
- Holiday (November-December): holiday movies, family films
- Streaming drops: new on Netflix, streaming releases

---

## Localization Priority

Based on App Store revenue by market:

1. English (US) - Primary
2. English (UK) - Adjust spelling
3. German - Large iOS market
4. Japanese - High ARPU
5. French - Significant market
6. Spanish - Growing market
7. Portuguese (Brazil) - Emerging market

---

## Metadata Update Schedule

Recommended update frequency:

Weekly: promotional_text (seasonality, trends)
Monthly: keywords (based on ranking data)
Per Release: description, release_notes
Quarterly: Full metadata audit

---

## File Creation Commands

Run from project root to create all metadata files:

```bash
mkdir -p fastlane/metadata/en-US

cat > fastlane/metadata/en-US/name.txt << 'EOF'
What2WatchAI
EOF

cat > fastlane/metadata/en-US/subtitle.txt << 'EOF'
Discover Movies and TV Shows
EOF

cat > fastlane/metadata/en-US/keywords.txt << 'EOF'
film,recommendation,streaming,picker,tonight,tracker,list,cinema,new,release,popular,trend,suggest
EOF

cat > fastlane/metadata/en-US/description.txt << 'EOF'
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
EOF

cat > fastlane/metadata/en-US/promotional_text.txt << 'EOF'
New AI recommendation engine now live. Get personalized movie suggestions based on your taste. Perfect for planning your next movie night.
EOF

cat > fastlane/metadata/en-US/privacy_url.txt << 'EOF'
https://what2watchai.com/privacy
EOF

cat > fastlane/metadata/en-US/support_url.txt << 'EOF'
https://what2watchai.com/support
EOF

cat > fastlane/metadata/en-US/marketing_url.txt << 'EOF'
https://what2watchai.com
EOF

cat > fastlane/metadata/en-US/release_notes.txt << 'EOF'
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
EOF

cat > fastlane/metadata/en-US/primary_category.txt << 'EOF'
Entertainment
EOF

echo "Metadata files created successfully"
```

---

## Validation Checklist

Before submission, verify:

- [ ] Name is 30 characters or less
- [ ] Subtitle is 30 characters or less
- [ ] Keywords are 100 characters or less
- [ ] No repeated words across name, subtitle, keywords
- [ ] Description is 4000 characters or less
- [ ] Promotional text is 170 characters or less
- [ ] No emojis in any text field
- [ ] No trademarked terms without permission
- [ ] URLs are valid and accessible
- [ ] Privacy policy URL is live

---

Document Version: 1.0
Last Updated: January 2026
