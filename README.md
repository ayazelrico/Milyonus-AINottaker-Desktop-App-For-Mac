# Milyonus

Milyonus is a native macOS AI nottaker and live meeting assistant. It listens locally to system audio and microphone input during meetings such as Zoom, Teams, and Google Meet, produces real-time transcripts, and provides on-demand GPT-4o guidance with a keyboard shortcut.

## Monorepo Structure

- `app/`: Swift/SwiftUI macOS desktop app. This will contain the menu bar app, permission flows, audio capture, Deepgram streaming integration, and floating panel UI.
- `backend/`: Next.js backend for Vercel. This will expose authenticated API routes for assist requests, session management, usage tracking, and server-side OpenAI calls.
- `supabase/`: Supabase schema, migrations, Row Level Security policies, and Auth-related setup.
- `shared/`: Shared TypeScript types and API contracts used by backend code and, where useful, generated or mirrored for the app.
- `docs/`: Architecture notes, ADRs, and implementation references.

## Development Setup

Detailed setup steps will be filled in during later phases.

Placeholder flow:

1. Install Xcode for macOS app development.
2. Install Node.js for the backend.
3. Configure Supabase project credentials.
4. Configure Vercel project environment variables.
5. Run backend and app targets from their respective folders once they are added.

## Stack

- Desktop app: Swift, SwiftUI, and AppKit.
- Backend: Next.js deployed on Vercel.
- Auth and database: Supabase Auth and Postgres with RLS.
- Speech-to-text: Deepgram streaming STT.
- LLM: OpenAI GPT-4o through the backend only.

## Branch Protection Recommendation

Protect `main` with pull requests required, at least one approving review, and required passing CI checks before merge.

