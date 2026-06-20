# Backend TODOs

- Configure `DEEPGRAM_API_KEY` in the production backend environment before Swift Faz 9 consumes `POST /api/deepgram-token`. The key must have Member or higher Deepgram permissions.
- Replace the simple Supabase-backed AI/token grant counters with Redis or another distributed limiter if request volume grows beyond MVP needs.
- Add persistent transcript retry queues if native clients must survive long offline periods.
