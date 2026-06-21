# Milyonus macOS App

Native menu bar app for Milyonus.

## Run Locally

1. Open `Milyonus.xcodeproj` in Xcode.
2. Copy `Milyonus/Secrets.xcconfig.example` to `Milyonus/Secrets.xcconfig`.
3. Set `API_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY`.
4. Do not put a Deepgram key in the app; the app fetches short-lived Deepgram tokens from the backend.
5. Build and run the `Milyonus` scheme.

Deepgram production streaming requires a logged-in Supabase session and a backend `DEEPGRAM_API_KEY` configured in Vercel.

## Manual Test Checklist

- Menu bar icon appears and Dock icon does not.
- Settings opens from the menu.
- Screen Recording and Microphone permission prompts are reachable.
- Start Session begins system and microphone capture on a real Mac with permissions granted.
- Transcript logs appear after login and Deepgram backend token issuance are configured.
- Cmd+\ hides and shows the floating panel immediately.
- Cmd+Enter opens the panel and streams `/api/assist` output when backend auth is configured.

## Known Limits

- `xcodebuild` requires full Xcode, not only Command Line Tools.
- Google Meet browser-tab detection is deferred; MVP detects native Zoom and Teams apps.
- Global key monitoring may require Accessibility/Input Monitoring permissions depending on macOS settings.
