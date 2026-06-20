# Architecture

Milyonus Mimarisi:
- app/: Swift/SwiftUI native macOS uygulaması. ScreenCaptureKit ile sistem sesi,
  AVAudioEngine ile mikrofon yakalar. Deepgram'a WebSocket ile streaming gönderir.
  Floating panel UI, Cmd+Enter ile backend'e istek atar.
- backend/: Next.js, Vercel'de deploy edilir. /api/assist endpoint'i GPT-4o çağrısını
  yapar (API key SADECE backend'de tutulur, asla client'a gömülmez). /api/sessions
  toplantı kayıtlarını yönetir. Supabase JWT ile auth doğrulanır.
- supabase/: Postgres şeması, RLS politikaları, Auth konfigürasyonu.
- shared/: Backend ve (gerekirse) app arasında paylaşılan TypeScript tip tanımları
  ve API sözleşmeleri (request/response şekilleri).

Kritik kural: OpenAI API key'i ve Deepgram API key'i asla Swift app'e gömülmez.
Deepgram bağlantısı bile mümkünse backend üzerinden kısa ömürlü token ile yapılmalı
(Deepgram'ın "temporary API key" / scoped key özelliği varsa onu kullan; yoksa bu
riski docs/architecture.md içinde bir "TODO/risk" notu olarak belirt).

TODO/risk: Deepgram temporary/scoped token strategy must be confirmed before the app streams audio directly. If Deepgram cannot issue suitably short-lived scoped credentials, route token issuance or streaming through the backend and document the latency/security tradeoff.

