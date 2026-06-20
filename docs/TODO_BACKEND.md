# Backend TODOs

- Add a production-safe Deepgram temporary token endpoint before shipping the Swift app. The app currently supports a local-development fallback key via `Secrets.xcconfig`, which is explicitly unsafe for production.
- Replace the simple Supabase-backed AI call counter with Redis or another distributed limiter if request volume grows beyond MVP needs.
- Add persistent transcript retry queues if native clients must survive long offline periods.

