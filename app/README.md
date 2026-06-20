# Milyonus macOS App

Native menu bar app for Milyonus.

## Run Locally

1. Open `Milyonus.xcodeproj` in Xcode.
2. Copy `Milyonus/Secrets.xcconfig.example` to `Milyonus/Secrets.xcconfig`.
3. Set `API_BASE_URL` to the backend URL.
4. For development only, set `MOCK_SUPABASE_JWT` and `DEEPGRAM_API_KEY` if you want to test backend assist and Deepgram streaming before production token issuance exists.
5. Build and run the `Milyonus` scheme.

`DEEPGRAM_API_KEY` in the app is a development-only fallback. Production must use a backend-issued short-lived token.

## Manual Test Checklist

- Menu bar icon appears and Dock icon does not.
- Settings opens from the menu.
- Screen Recording and Microphone permission prompts are reachable.
- Start Session begins system and microphone capture on a real Mac with permissions granted.
- Transcript logs appear after Deepgram credentials are configured.
- Cmd+\ hides and shows the floating panel immediately.
- Cmd+Enter opens the panel and streams `/api/assist` output when backend auth is configured.

## Known Limits

- `xcodebuild` requires full Xcode, not only Command Line Tools.
- Google Meet browser-tab detection is deferred; MVP detects native Zoom and Teams apps.
- Global key monitoring may require Accessibility/Input Monitoring permissions depending on macOS settings.

