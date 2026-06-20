# Backend TODOs

- Add a production-safe Deepgram temporary token endpoint before shipping the Swift app. The app intentionally does not accept a Deepgram key in `Secrets.xcconfig`; streaming STT remains blocked until backend token issuance exists.
- Replace the simple Supabase-backed AI call counter with Redis or another distributed limiter if request volume grows beyond MVP needs.
- Add persistent transcript retry queues if native clients must survive long offline periods.
