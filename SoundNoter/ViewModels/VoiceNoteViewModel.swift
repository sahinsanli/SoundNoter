import Foundation
import SwiftData
import Observation

/// Uygulamanın kalbi. View'lar sadece buradaki fonksiyonları çağırır.
/// Kayıt akışı: durdur → VoiceNote oluştur → chunking → transkripsiyon → özet → kaydet.
@Observable
final class VoiceNoteViewModel {

    // MARK: - Durum (View'ların izlediği)

    /// Kayıt şu an aktif mi?
    private(set) var isRecording: Bool = false

    /// AI işleme pipeline'ı çalışıyor mu?
    private(set) var isProcessing: Bool = false

    /// Kullanıcıya gösterilecek durum mesajı ("Transkribe ediliyor...", "Tamamlandı" vs.).
    var statusMessage: String = ""

    /// Waveform için anlık ses seviyesi (0–1).
    private(set) var audioLevel: Float = 0

    /// Kayıt süresi (saniye).
    private(set) var elapsedRecordingTime: TimeInterval = 0

    // MARK: - Bağımlılıklar (Dependency Injection)

    let recorder: AudioRecorderService
    let player: AudioPlayerService
    let aiService: AIService
    let timestampService: SpeechTimestampService

    private var levelTimer: Timer?

    init(
        recorder: AudioRecorderService = AudioRecorderService(),
        player: AudioPlayerService = AudioPlayerService(),
        aiService: AIService = AIService(),
        timestampService: SpeechTimestampService = SpeechTimestampService()
    ) {
        self.recorder = recorder
        self.player = player
        self.aiService = aiService
        self.timestampService = timestampService
    }

    // MARK: - Kayıt

    /// Mikrofon izni ister ve kaydı başlatır.
    func startRecording() async -> Bool {
        guard await recorder.requestPermission() else {
            statusMessage = "Mikrofon izni gerekli"
            return false
        }

        do {
            try recorder.startRecording()
            isRecording = true
            elapsedRecordingTime = 0
            statusMessage = "Kaydediliyor..."
            startObservingRecorder()
            return true
        } catch {
            statusMessage = "Kayıt başlatılamadı: \(error.localizedDescription)"
            return false
        }
    }

    /// Kaydı durdurur ve tam işlem hattını çalıştırır:
    /// 1. Servise "dur" de
    /// 2. Yeni VoiceNote oluştur ve veritabanına kaydet
    /// 3. Chunking → Transkripsiyon → Timestamp → Özetleme
    @discardableResult
    func stopRecordingAndProcess(modelContext: ModelContext) async -> VoiceNote? {
        guard isRecording else { return nil }
        isRecording = false
        stopObservingRecorder()

        guard let fileURL = recorder.stopRecording() else {
            statusMessage = "Kayıt bulunamadı"
            return nil
        }

        // Kayıt dosyasını kalıcı konumuna taşı.
        let fileName = fileURL.lastPathComponent
        let destination = AudioFileManager.url(for: fileName)
        if fileURL.standardizedFileURL != destination.standardizedFileURL {
            try? FileManager.default.moveItem(at: fileURL, to: destination)
        }

        let duration = recorder.recordingTime

        // Yeni VoiceNote oluştur (Model) ve hemen kaydet — kullanıcı kaydı anında listede görsün.
        let voiceNote = VoiceNote(
            title: Self.defaultTitle(for: Date()),
            audioFileName: fileName,
            duration: duration,
            status: .new
        )
        modelContext.insert(voiceNote)
        try? modelContext.save()

        // AI işleme başlat.
        await processVoiceNote(voiceNote, modelContext: modelContext)

        return voiceNote
    }

    // MARK: - AI İşleme Hattı

    /// Ses dosyası → chunking → transkripsiyon → timestamp → özet → SwiftData'ya yaz.
    func processVoiceNote(_ voiceNote: VoiceNote, modelContext: ModelContext) async {
        isProcessing = true
        defer { isProcessing = false }

        let fileURL = AudioFileManager.url(for: voiceNote.audioFileName)
        guard AudioFileManager.exists(voiceNote.audioFileName) else {
            voiceNote.status = .failed
            statusMessage = "Ses dosyası bulunamadı"
            try? modelContext.save()
            return
        }

        do {
            // ADIM 1: Chunking — API limiti için parçalara böl.
            statusMessage = "Ses hazırlanıyor..."
            voiceNote.status = .transcribing
            try? modelContext.save()

            let chunks = try await AudioChunkingService.chunkAudio(fileURL: fileURL)
            defer { AudioChunkingService.cleanupChunks(chunks.map(\.url)) }

            var fullText = ""
            var chunkModels: [TranscriptionChunk] = []

            // ADIM 2: Her parçayı AI'a gönder → metin al.
            for (index, chunk) in chunks.enumerated() {
                statusMessage = "Transkribe ediliyor... (\(index + 1)/\(chunks.count))"
                let text = try await aiService.transcribeAudio(fileURL: chunk.url)

                let chunkModel = TranscriptionChunk(
                    index: index,
                    startTime: chunk.start,
                    endTime: chunk.end,
                    text: text
                )
                modelContext.insert(chunkModel)
                chunkModels.append(chunkModel)
                fullText += text + " "
                try? modelContext.save()
            }

            voiceNote.chunks = chunkModels
            let transcript = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            voiceNote.fullTranscription = transcript
            try? modelContext.save()

            // ADIM 2.5: Timestamp — Apple SFSpeech ile kelime zamanları (karaoke takibi).
            // AI transkripsiyonuyla zamanlar örtüşmeyebilir; izin verilmişse çıkar, hata kritik değil.
            if let words = try? await timestampService.extractTimestamps(fileURL: fileURL), !words.isEmpty {
                voiceNote.timestampedWordsJSON = SpeechTimestampService.encode(words)
            }

            // ADIM 3: Özetleme — tüm metni AI'a gönder → özet + anahtar noktalar.
            statusMessage = "Özetleniyor..."
            voiceNote.status = .summarizing
            try? modelContext.save()

            let (summary, keyPoints) = try await aiService.summarize(transcript: transcript)
            voiceNote.summary = summary
            voiceNote.keyPoints = keyPoints
            voiceNote.status = .completed
            statusMessage = "Tamamlandı"

        } catch {
            voiceNote.status = .failed
            statusMessage = "İşlem başarısız: \(error.localizedDescription)"
        }

        try? modelContext.save()
    }

    /// Başarısız olmuş bir notu yeniden işlemeye alır.
    func retryProcessing(_ voiceNote: VoiceNote, modelContext: ModelContext) async {
        await processVoiceNote(voiceNote, modelContext: modelContext)
    }

    // MARK: - Not yönetimi

    func deleteNote(_ voiceNote: VoiceNote, modelContext: ModelContext) {
        AudioFileManager.delete(voiceNote.audioFileName)
        modelContext.delete(voiceNote)
        try? modelContext.save()
    }

    func updateTitle(_ voiceNote: VoiceNote, to title: String, modelContext: ModelContext) {
        voiceNote.title = title
        try? modelContext.save()
    }

    /// Kayıt ekranından iptal: kaydı durdurur ve geçici dosyayı siler.
    func stopObservingForCancel() {
        if isRecording {
            if let url = recorder.stopRecording() {
                try? FileManager.default.removeItem(at: url)
            }
            isRecording = false
        }
        stopObservingRecorder()
    }

    // MARK: - Kayıt gözlemi (waveform + süre)

    private func startObservingRecorder() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.audioLevel = self.recorder.averagePower
            if self.isRecording {
                self.elapsedRecordingTime += 0.05
            }
        }
    }

    private func stopObservingRecorder() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    // MARK: - Yardımcılar

    /// Yeni kayıt için varsayılan başlık: "Kayıt — 7 Ekim 19:24".
    private static func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return "Kayıt — \(formatter.string(from: date))"
    }
}
