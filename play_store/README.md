# Play Store listing — BigDogg

This folder contains the text content for the Google Play Console listing.
Everything else (screenshots, graphics, account-level config) is manual.

## Text files

| File | Limit | Purpose |
|---|---|---|
| `short_description_nl.txt` | 80 chars | Korte beschrijving (NL) |
| `short_description_en.txt` | 80 chars | Short description (EN) |
| `description_nl.txt` | 4000 chars | Volledige beschrijving (NL) |
| `description_en.txt` | 4000 chars | Full description (EN) |
| `whats_new_nl.txt` | 500 chars | Wat is er nieuw (NL) — versie 1.0.0 |
| `whats_new_en.txt` | 500 chars | What's new (EN) — version 1.0.0 |

Default Play Console language: Dutch (NL). Add English as additional language.

## Build artifact

Signed AAB (after running `flutter build appbundle --release --split-debug-info=build/symbols`):

```
build/app/outputs/bundle/release/app-release.aab
```

- Signed with `android/app/bigdogg-release.jks` (alias `bigdogg`)
- Signing cert SHA-256: `DC:40:AA:71:97:6B:85:DE:04:82:42:D4:F2:74:38:D0:62:9E:CA:08:34:B9:70:B9:DE:91:86:1E:80:74:D7:A6`
- applicationId: `nl.bigdogg.app`
- versionCode: 1, versionName: 1.0.0
- compileSdk 36, targetSdk 36, minSdk per Flutter default
- Size: ~47 MB

## Manual checklist before publishing

### Required for any release (internal/closed/open testing & production)

- [ ] **Create a Play Console account** (one-time $25 registration)
- [ ] **Create the app entry** in Play Console with package `nl.bigdogg.app`
- [ ] **App category**: Finance / Productivity
- [ ] **Content rating questionnaire** (likely PEGI 3 / Everyone)
- [ ] **Target audience and content** — set age range
- [ ] **Data safety form** — declare what you collect (email, business data, payment info via Stripe), how (encrypted in transit & at rest), data location (EU/Frankfurt), deletion request flow
- [ ] **Privacy policy URL** — must be publicly hosted. Suggested: `https://bigdogg.nl/privacy` (currently does not exist — create page or generate at https://app-privacy-policy-generator.firebaseapp.com/ and host on Cloudflare Pages)
- [ ] **App access** — describe how reviewer can sign in (provide a test login or note that 30-day free trial is open)
- [ ] **Ads** — declare "No, my app does not contain ads"
- [ ] **Government app** — No

### Required graphical assets

- [ ] **App icon (512×512 PNG, 32-bit, no alpha needed but allowed)** — currently default Flutter "F" icon. Replace before publishing. Suggest `flutter_launcher_icons` package or manually replace `android/app/src/main/res/mipmap-*/ic_launcher.png` (mdpi 48×48, hdpi 72×72, xhdpi 96×96, xxhdpi 144×144, xxxhdpi 192×192).
- [ ] **Feature graphic (1024×500 PNG/JPG)** — required for store listing
- [ ] **Phone screenshots (2–8 images, 16:9 or 9:16, min 320 px, max 3840 px)** — capture the dashboard, invoice creation, AI assist, BTW overview, profile
- [ ] **(Optional) 7-inch tablet, 10-inch tablet screenshots** — only if you want tablet listing

### Pricing & countries

- [ ] **Free app** (subscription is in-app via Stripe, not Play Billing — confirm Play policy compliance for "service" model)
- [ ] **Countries** — Netherlands first, then EU. Avoid US/UK initially.

### Recommended for first internal test

1. Upload `app-release.aab` to **Internal testing** track.
2. Add yourself as a tester (email).
3. Click **Review release** → **Start rollout to Internal testing**.
4. Wait ~10 min, then visit the opt-in URL Play gives you and install on a real Android device.
5. Verify: launcher icon, sign up, create invoice, take photo of receipt, view BTW overview.

### Known limitations of the v1.0.0 Android build

- **PDF historical import** — works on web only for now. On Android, the import section in Profile is silently no-op for PDFs. Native PDF picker via `file_picker` package is on the roadmap.
- **Native crash reports** — not symbolicated yet (Flutter NDK pin pending). Crashes will show in Play Console but with stripped stack traces. Planned fix for v1.1.0.
- **Logo upload on Android** — currently web-only. Mobile users should use the web app to upload their company logo.

### Next iterations

- Replace launcher icon with BigDogg logo
- Add `file_picker` package for native PDF import on Android
- Pin Flutter-blessed NDK version to enable native crash deobfuscation
- iOS build (planned for next week on a Mac)
