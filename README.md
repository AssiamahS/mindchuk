# MindChuk

Text yourself anything. Find it instantly.

A local-first iPhone notes app built around one habit: sending yourself a text. Every message becomes a card. `#tags` and trigger words file it, "remind me at 9am to ..." schedules a local notification, and the feed is searchable by text or tag. Board (tags as columns), Calendar (what landed or is due on a day), and Swipe (triage the deck) are three more views of the same notes.

No account, no server, nothing leaves the phone. Export CSV from Settings.

## Layout

- `ios/` — SwiftUI + SwiftData app. `project.yml` is the source of truth (XcodeGen); the `.xcodeproj` is generated in CI.
- `web/` — landing page + privacy policy, published to GitHub Pages at https://assiamahs.github.io/mindchuk
- `tools/` — App Store Connect API helpers
  - `asc_metadata.py` fills name, subtitle, categories, description, keywords, URLs, age rating, review contact, free price, availability
  - `asc_screenshots.py` replaces the iPhone screenshot set (CI calls it with simulator captures)
  - `asc_submit.py` attaches the newest processed build; `--submit` sends it to review

## CI

`.github/workflows/ios.yml` on every push to `main`:

1. unsigned compile check
2. simulator screenshots with demo data (`MINDCHUK_DEMO=1`, `-tab <feed|board|calendar|swipe>`), uploaded as an artifact and pushed to App Store Connect
3. archive with cloud-managed signing and upload to TestFlight (`CFBundleVersion` = run number)

Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (base64 of the .p8).

## Run locally

```sh
cd ios && xcodegen generate && open MindChuk.xcodeproj
```
