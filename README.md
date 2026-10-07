# SoundNoter

Ses kayıtlarını otomatik transkribe eden ve özetleyen iOS uygulaması.
Mezuniyet projesi — MVVM + Services mimarisi.

## Mimari

```
SoundNoter/
├── SoundNoterApp.swift      # Giriş noktası: Firebase + SwiftData kurulumu
├── AppState.swift           # Splash/Onboarding/Auth durumu (@Observable)
├── ContentView.swift        # Yönlendirme merkezi
├── Theme.swift              # Karanlık tema, neon glow, glassmorphism
├── Models/                  # SwiftData tabloları
│   ├── VoiceNote.swift      # Ana model (durum: new→transcribing→summarizing→completed)
│   └── TranscriptionChunk.swift  # Parça modeli (cascade relationship)
├── Services/                # Tek sorumluluklu işçiler
│   ├── AudioRecorderService.swift   # Mikrofon, m4a kayıt, waveform ölçümü
│   ├── AudioPlayerService.swift     # Oynatma/duraklat/sarma + karaoke callback
│   ├── AudioFileManager.swift       # Documents/Recordings yönetimi
│   ├── AudioChunkingService.swift   # AVAssetExportSession ile 5dk parçalama
│   ├── AIService.swift              # Gemini: transkripsiyon + özet (structured JSON)
│   ├── SpeechTimestampService.swift # SFSpeechRecognizer: kelime timestamp'leri
│   └── AuthService.swift            # Firebase Auth (e-posta + Google)
├── ViewModels/
│   └── VoiceNoteViewModel.swift     # İşlem hattı: kayıt→chunk→transkribe→özet
└── Views/
    ├── SplashView.swift       # Neon logo açılışı
    ├── OnboardingView.swift   # 3 sayfalık tanıtım
    ├── LoginOptionsView.swift # E-posta / Google giriş
    ├── EmailAuthView.swift    # Firebase e-posta giriş/kayıt
    ├── MainListView.swift     # @Query liste + glassmorphism dock
    ├── RecordingView.swift    # Canlı waveform + timer
    └── NoteDetailView.swift   # Karaoke transkripsiyon + çalar + özet
```

## Kurulum

1. `SoundNoter.xcodeproj` dosyasını Xcode'da açın.
2. **Gemini API anahtarı:** [Google AI Studio](https://aistudio.google.com/)'dan anahtar alın,
   `SoundNoter/Info.plist` → `GEMINI_API_KEY` alanına yapıştırın.
3. **Firebase:** [Firebase Console](https://console.firebase.google.com/)'da proje oluşturun,
   indirdiğiniz `GoogleService-Info.plist` dosyasını `SoundNoter/` klasörüne ekleyin
   (eski dosya `~/Downloads/GoogleService-Info.plist` konumunda duruyorsa onu kullanabilirsiniz).
   Authentication → Sign-in method bölümünde **Email/Password**'ü etkinleştirin.
4. Cmd+R ile derleyip çalıştırın (iOS 17+ simülatör/cihaz).

## Notlar

- Google ile giriş için ayrıca `GoogleSignIn` SPM paketi ve
  `GIDClientID` (Info.plist) + URL Scheme yapılandırması gerekir;
  `LoginOptionsView.GoogleSignInBridge` üzerinden entegre edilir.
- GoogleSignIn kurulumu yapılmadan uygulama e-posta girişiyle tam çalışır.
- Ses dosyaları ve transkripsiyonlar cihazda (SwiftData + Documents) saklanır;
  Firebase yalnızca kimlik doğrulama için kullanılır.
