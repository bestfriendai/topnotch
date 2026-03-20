# Pre-Submission Checklist - What2WatchAI

Complete this checklist before submitting to the App Store.

---

## App Configuration

### Bundle Identifiers

| Item | Value | Status |
|------|-------|--------|
| Main App Bundle ID | com.what2watchai.app | [ ] Registered |
| Widget Bundle ID | com.what2watchai.app.widgets | [ ] Registered |
| App Group | group.com.what2watchai.app | [ ] Created |

### Team and Signing

| Item | Value | Status |
|------|-------|--------|
| Team ID | CY89UC5Z6Z | [ ] Verified |
| API Key ID | PRKWBSZ4FZ | [ ] Active |
| Issuer ID | d379ef5a-740b-4b80-bc48-8e1526fc03d3 | [ ] Verified |
| .p8 Key File | appsetupkit.p8 | [ ] Present |

---

## Capabilities Setup

### Apple Developer Portal

| Capability | Main App | Widget | Status |
|------------|----------|--------|--------|
| Sign in with Apple | Required | No | [ ] Enabled |
| Push Notifications | Required | No | [ ] Enabled |
| App Groups | Required | Required | [ ] Enabled |

### Xcode Entitlements

| File | Contains | Status |
|------|----------|--------|
| MovieTrailer.entitlements | com.apple.developer.applesignin | [ ] Verified |

---

## App Store Connect

### App Registration

| Task | Status |
|------|--------|
| App created in App Store Connect | [ ] Complete |
| Bundle ID registered | [ ] Complete |
| SKU assigned | [ ] Complete |
| Primary category set (Entertainment) | [ ] Complete |
| Secondary category set (Lifestyle) | [ ] Complete |
| Age rating completed | [ ] Complete |

### Pricing

| Task | Status |
|------|--------|
| Price tier selected (Free) | [ ] Complete |
| Availability countries selected | [ ] Complete |

---

## Metadata

### Text Content

| Field | Max Length | Status |
|-------|------------|--------|
| App Name | 30 chars | [ ] Complete |
| Subtitle | 30 chars | [ ] Complete |
| Keywords | 100 chars | [ ] Complete |
| Description | 4000 chars | [ ] Complete |
| Promotional Text | 170 chars | [ ] Complete |
| Release Notes | 4000 chars | [ ] Complete |

### URLs

| URL Type | Status |
|----------|--------|
| Privacy Policy URL | [ ] Live and accessible |
| Support URL | [ ] Live and accessible |
| Marketing URL | [ ] Live and accessible |

### Quality Checks

| Check | Status |
|-------|--------|
| No emojis in metadata | [ ] Verified |
| No markdown formatting | [ ] Verified |
| No repeated keywords | [ ] Verified |
| No trademarked terms | [ ] Verified |
| Grammar and spelling reviewed | [ ] Verified |

---

## Screenshots

### Required Sizes

| Device | Resolution | Count | Status |
|--------|------------|-------|--------|
| iPhone 6.9 inch | 1320 x 2868 | 3-10 | [ ] Uploaded |
| iPhone 6.7 inch | 1290 x 2796 | 3-10 | [ ] Uploaded |
| iPhone 6.5 inch | 1284 x 2778 | 3-10 | [ ] Uploaded |
| iPad Pro 12.9 inch | 2048 x 2732 | 3-10 | [ ] If applicable |

### Screenshot Content

| Screen | Content | Status |
|--------|---------|--------|
| Screenshot 1 | Discover/Home | [ ] Created |
| Screenshot 2 | Swipe Interface | [ ] Created |
| Screenshot 3 | Tonight Feature | [ ] Created |
| Screenshot 4 | Watchlist | [ ] Created |
| Screenshot 5 | Movie Details | [ ] Created |
| Screenshot 6 | Live Activity | [ ] Created |

### Screenshot Quality

| Check | Status |
|-------|--------|
| No placeholder text | [ ] Verified |
| No beta labels | [ ] Verified |
| Actual app content shown | [ ] Verified |
| Text readable at small size | [ ] Verified |
| Consistent visual style | [ ] Verified |

---

## App Icon

### Requirements

| Requirement | Status |
|-------------|--------|
| 1024 x 1024 PNG | [ ] Created |
| No transparency | [ ] Verified |
| No rounded corners (system applies) | [ ] Verified |
| Looks good at small sizes | [ ] Verified |

---

## App Preview Video (Optional)

| Requirement | Status |
|-------------|--------|
| 15-30 seconds duration | [ ] If applicable |
| Captures app usage only | [ ] If applicable |
| No hands or external devices | [ ] If applicable |
| Audio is optional | [ ] If applicable |

---

## Build Requirements

### Technical

| Requirement | Status |
|-------------|--------|
| Builds without errors | [ ] Verified |
| Builds without warnings | [ ] Verified |
| No private API usage | [ ] Verified |
| 64-bit architecture | [ ] Verified |
| Minimum iOS version set correctly | [ ] Verified |

### Testing

| Test | Status |
|------|--------|
| App launches on device | [ ] Passed |
| All core features functional | [ ] Passed |
| No crashes during normal use | [ ] Passed |
| Network errors handled gracefully | [ ] Passed |
| Offline behavior acceptable | [ ] Passed |

### Performance

| Check | Status |
|-------|--------|
| Reasonable launch time | [ ] Verified |
| Smooth scrolling | [ ] Verified |
| Images load efficiently | [ ] Verified |
| Battery usage acceptable | [ ] Verified |
| Memory usage acceptable | [ ] Verified |

---

## Privacy and Legal

### Privacy

| Requirement | Status |
|-------------|--------|
| Privacy Policy URL valid | [ ] Verified |
| PrivacyInfo.xcprivacy included | [ ] Verified |
| Data collection disclosed accurately | [ ] Verified |
| Third-party SDKs disclosed | [ ] Verified |

### App Tracking Transparency

| Question | Answer |
|----------|--------|
| Does app track users? | No |
| ATT prompt required? | No |
| IDFA used? | No |

### Legal

| Check | Status |
|-------|--------|
| TMDB API terms followed | [ ] Verified |
| No copyrighted content misused | [ ] Verified |
| Third-party licenses included | [ ] Verified |

---

## Third-Party Services

### Firebase

| Item | Value | Status |
|------|-------|--------|
| Project ID | movietrailer-1767069717 | [ ] Configured |
| GoogleService-Info.plist | Present | [ ] Included |
| Auth enabled | Yes | [ ] Configured |

### Sign in with Apple

| Item | Status |
|------|--------|
| Primary App ID configured | [ ] Complete |
| Services ID created | [ ] Complete |
| .p8 key registered | [ ] Complete |

---

## App Review Information

### Contact Information

| Field | Value | Status |
|-------|-------|--------|
| First Name | [Your Name] | [ ] Entered |
| Last Name | [Your Name] | [ ] Entered |
| Phone | [Your Phone] | [ ] Entered |
| Email | support@what2watchai.com | [ ] Entered |

### Demo Account

| Field | Value |
|-------|-------|
| Username | Not required |
| Password | Not required |
| Notes | App works without login |

### Review Notes

| Item | Status |
|------|--------|
| Clear testing instructions | [ ] Written |
| Special configuration noted | [ ] If applicable |
| Known limitations disclosed | [ ] If applicable |

---

## Final Submission Steps

### Fastlane Commands

```bash
# 1. Sync certificates
fastlane certs

# 2. Build app
fastlane build

# 3. Upload to TestFlight for final testing
fastlane beta

# 4. After TestFlight approval, submit for review
fastlane release
```

### Manual Steps

1. [ ] Archive build in Xcode
2. [ ] Upload to App Store Connect
3. [ ] Wait for processing
4. [ ] Select build for submission
5. [ ] Complete export compliance
6. [ ] Submit for review

---

## Post-Submission

### Monitoring

| Task | Status |
|------|--------|
| Monitor App Store Connect for status | [ ] Ongoing |
| Prepare responses to potential questions | [ ] Ready |
| Have team available for quick fixes | [ ] Available |

### If Rejected

1. Read rejection reason carefully
2. Address specific issues mentioned
3. Respond via Resolution Center
4. Resubmit with fixes

---

## Version History

| Version | Date | Submitted By | Status |
|---------|------|--------------|--------|
| 1.0.0 | | | Pending |

---

Document Version: 1.0
Last Updated: January 2026
