# Backend TODOs

- Confirm `DEEPGRAM_API_KEY` in the production backend environment before shipping Swift Deepgram streaming broadly. The key must have Member or higher Deepgram permissions.
- Replace the simple Supabase-backed AI/token grant counters with Redis or another distributed limiter if request volume grows beyond MVP needs.
- Add persistent transcript retry queues if native clients must survive long offline periods.
- Extend `/api/assist` to accept conversation history (`messages`) so the native multi-turn chat can send prior user/assistant turns, not only the latest question plus transcript context.

## Production Checklist

- [ ] Vercel Environment Variables içinde `DEEPGRAM_API_KEY` girildi mi?
      vercel.com -> Proje -> Settings -> Environment Variables
      Key: `DEEPGRAM_API_KEY`
      Value: Deepgram console'dan aldigin key (`dg_` ile baslar, Member/Admin rolu olmali)
- [ ] Deepgram Console'da API key'in rolu Member veya ustu mu?
      console.deepgram.com -> API Keys -> Key role
