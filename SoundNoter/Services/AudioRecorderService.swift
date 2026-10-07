import Foundation
import AVFoundation

/// Mikrofon iznini alır, sesi dinler, dalga formları (waveform) için
/// ses seviyelerini ölçer ve m4a olarak kaydeder.
final class AudioRecorderService: NSObject, ObservableObject {

    private(set) var audioFileURL: URL?
    private var audioRecorder: AVAudioRecorder?

    /// Kayıt süresi (saniye).
    private(set) var recordingTime: TimeInterval = 0

    /// Waveform için anlık ses seviyesi (0.0 – 1.0 arası, dB'den normalize).
    private(set) var averagePower: Float = 0

    private var levelTimer: Timer?
    private var startTime: Date?

    /// Kayıt aktif mi?
    private(set) var isRecording: Bool = false

    // MARK: - İzin

    func requestPermission() async -> Bool {
        // iOS 17+: AVAudioApplication (eski requestRecordPermission deprecated).
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Kayıt

    /// Mikrofonu açar ve Recordings dizininde yeni bir m4a dosyasına kaydetmeye başlar.
    /// Zaten kayıt aktifse yeniden başlatmaz (çift kayıt koruması).
    func startRecording() throws {
        guard !isRecording else {
            throw NSError(
                domain: "AudioRecorderService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Kayıt zaten aktif"]
            )
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        // Doğrudan kalıcı konuma kaydet — ViewModel'de taşıma gerekmez.
        let fileName = "recording-\(UUID().uuidString).m4a"
        let url = AudioFileManager.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true // waveform için seviye ölçümü

        guard recorder.record() else {
            throw NSError(
                domain: "AudioRecorderService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Kayıt başlatılamadı"]
            )
        }

        audioRecorder = recorder
        audioFileURL = url
        recordingTime = 0
        startTime = Date()
        isRecording = true

        startLevelTimer()
    }

    /// Kaydı durdurur ve dosya URL'sini döner.
    @discardableResult
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        isRecording = false
        stopLevelTimer()

        if let start = startTime {
            recordingTime = Date().timeIntervalSince(start)
        }

        try? AVAudioSession.sharedInstance().setActive(false)

        let url = audioFileURL
        audioRecorder = nil
        return url
    }

    // MARK: - Seviye ölçümü (waveform)

    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
        averagePower = 0
    }

    private func updateMeters() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0) // dB cinsinden (-160...0)
        // dB'yi 0–1 aralığına normalize et (-60 dB ve altı sessiz sayılır)
        let normalized = max(0, min(1, (power + 60) / 60))
        averagePower = normalized
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("⚠️ Kayıt beklenmedik şekilde sonlandı")
        }
    }
}
