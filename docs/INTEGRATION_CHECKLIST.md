# Entegrasyon Kontrol Listesi

- [ ] Xcode projesi hatasız derleniyor (xcodebuild build başarılı)
  - Bu ortamda doğrulanamadı: `xcodebuild` tam Xcode istiyor, aktif developer directory `/Library/Developer/CommandLineTools`.
- [x] Secrets.xcconfig doğru okunuyor, Config.swift değerleri Info.plist'ten alıyor
  - `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` xcconfig -> Info.plist -> `AppConfig` hattına bağlandı.
- [ ] Email magic link gönderme gerçek Supabase'e istek atıyor
  - `SupabaseAuthService.signInWithMagicLink(email:)` gerçek `signInWithOTP` çağrısına bağlandı; gerçek Supabase URL/anon key girildikten sonra cihazda test edilmeli.
- [ ] Google OAuth akışı sistem tarayıcısını açıyor, callback ile geri dönüyor
  - `SupabaseAuthService.signInWithGoogle()` gerçek OAuth akışına bağlandı ve `milyonus://auth-callback` URL scheme'i Info.plist'e eklendi; cihazda test edilmeli.
- [ ] Login sonrası session Keychain'de persist ediliyor
  - Supabase Swift SDK'nin `KeychainLocalStorage` kullanımı yapılandırıldı; gerçek login sonrası doğrulanmalı.
- [ ] "Test Backend Connection" butonu /api/usage'a istek atıp 401 (login yoksa)
      veya 200 (login varsa) dönüyor
  - Buton eklendi; gerçek app çalıştırılıp test edilmeli.
- [ ] Login olduktan sonra /api/usage 200 ve gerçek kullanım verisi dönüyor
  - Gerçek Supabase session sonrası test edilmeli.
- [ ] Microphone ve Screen Recording izin akışları çalışıyor
  - Gerçek Mac uygulama çalıştırmasında test edilmeli.
- [ ] Start Session sonrası audio capture başlıyor (konsol logları doğrulanıyor)
  - Gerçek Mac uygulama çalıştırmasında test edilmeli.
- [ ] Deepgram bağlantısı kuruluyor (veya hâlâ TODO ise bu açıkça not ediliyor)
  - Swift app `/api/deepgram-token` üzerinden kısa ömürlü token alıyor; gerçek login ve Vercel `DEEPGRAM_API_KEY` ile cihazda test edilmeli.
- [ ] Cmd+Enter, panel'i öne getirip backend'e istek atıyor
  - Gerçek login/session ve app çalıştırmasıyla test edilmeli.
- [ ] Cmd+\ paneli anında gizleyip gösteriyor
  - Gerçek Mac uygulama çalıştırmasında test edilmeli.
