# Milyonus

Milyonus is a native macOS AI nottaker and live meeting assistant. It listens locally to system audio and microphone input during meetings such as Zoom, Teams, and Google Meet, produces real-time transcripts, and provides on-demand GPT-4o guidance with a keyboard shortcut.

## Monorepo Structure

- `app/`: Swift/SwiftUI macOS desktop app. This will contain the menu bar app, permission flows, audio capture, Deepgram streaming integration, and floating panel UI.
- `backend/`: Next.js backend for Vercel. This will expose authenticated API routes for assist requests, session management, usage tracking, and server-side OpenAI calls.
- `supabase/`: Supabase schema, migrations, Row Level Security policies, and Auth-related setup.
- `shared/`: Shared TypeScript types and API contracts used by backend code and, where useful, generated or mirrored for the app.
- `docs/`: Architecture notes, ADRs, and implementation references.

## Development Setup

1. Install Xcode for macOS app development.
2. Install Node.js and pnpm for the backend.
3. Configure Supabase with `supabase/SETUP.md`.
4. Configure backend environment variables from `backend/.env.example`.
5. Start the backend:

   ```bash
   cd backend
   pnpm install
   pnpm dev
   ```

6. Configure the macOS app:

   ```bash
   cp app/Milyonus/Secrets.xcconfig.example app/Milyonus/Secrets.xcconfig
   open app/Milyonus.xcodeproj
   ```

7. Run the `Milyonus` scheme from Xcode on a real Mac and grant Screen Recording and Microphone permissions.

## Stack

- Desktop app: Swift, SwiftUI, and AppKit.
- Backend: Next.js deployed on Vercel.
- Auth and database: Supabase Auth and Postgres with RLS.
- Speech-to-text: Deepgram streaming STT.
- LLM: OpenAI GPT-4o through the backend only.

## Security Notes

- `OPENAI_API_KEY`, `DEEPGRAM_API_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are server-only secrets.
- The Swift app currently has a development-only Deepgram key fallback for local testing. Production must use short-lived backend-issued Deepgram credentials before shipping.
- macOS 15+ cannot guarantee that a floating panel is hidden from every screen sharing implementation. Milyonus uses `sharingType = .none` plus Cmd+\ flash-hide, and tells the user this limitation plainly.

## Branch Protection Recommendation

Protect `main` with pull requests required, at least one approving review, and required passing CI checks before merge.
