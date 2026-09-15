# MindChuk

Text yourself anything. Find it instantly.

A local-first iPhone notes app built around one habit: sending yourself a text. Every message becomes a card. `#tags` and trigger words file it, "remind me at 9am to ..." schedules a local notification, and the feed is searchable by text or tag. Board (tags as columns), Calendar (what landed or is due on a day), and Swipe (triage the deck) are three more views of the same notes.

No account, no server, nothing leaves the phone. Export CSV from Settings.

## Lock screen + texting it (v1.1)

- **Widgets**: lock screen (rectangular / inline / circular) and Home Screen (small / medium) show today's reminders and latest notes. The app hands the extension a small snapshot through a team-prefixed keychain access group, so no App Group has to exist in the developer portal (App Groups can't be created by the CI's API-key session).
- **Today card**: a Live Activity on the lock screen / Dynamic Island, refreshed on every note. iOS ends it after 8h; opening the app or the Siri phrase brings it back.
- **"Text MindChuk"** App Intent: Siri ("Hey Siri, text MindChuk"), Shortcuts, Action button, Back Tap, and a Messages automation (when I get a message from *me* → Text MindChuk with Shortcut Input) so texting yourself in iMessage files the note. It is a `LiveActivityIntent`, so it runs in the background and still updates the lock screen.

Setup steps are in the app under Settings → Lock screen & texting.

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
