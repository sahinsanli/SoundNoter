import Foundation
import AVFoundation
import Observation

/// Kaydedilen sesi oynatır, duraklatır, durdurur ve ileri/geri sarar.
/// Apple Music tarzı çalar arayüzünün servis tarafı.
/// @Observable: VoiceNoteViewModel (@Observable) üzerinden izlenirken
/// değişiklikler SwiftUI view'lara ulaşır (@Published + ObservableObject karışımı değil).
@Observable
final class AudioPlayerService {

    private var player: AVAudioPlayer?
    @ObservationIgnored private var timeTimer: Timer?
    @ObservationIgnored private var playerDelegate: PlayerDelegate?

    /// Oynatılan dosyanın adı.
    private(set) var currentFileName: String?

    /// Oynatma aktif mi (duraklatılmamış).
    private(set) var isPlaying: Bool = false

    /// Geçen süre (saniye).
    private(set) var currentTime: TimeInterval = 0

    /// Toplam süre (saniye).
    private(set) var duration: TimeInterval = 0

    /// Karaoke takibi: oynatma süresi değiştikçe çağrılır (NoteDetailView dinler).
    var currentTimeHandler: ((TimeInterval) -> Void)?

    // MARK: - Oynatma

    /// Verilen kayıt dosyasını yükler ve oynatmaya başlar.
    func play(fileName: String) {
        let url = AudioFileManager.url(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            let delegate = PlayerDelegate(owner: self)
            player.delegate = delegate
            playerDelegate = delegate
            player.play()

            self.player = player
            currentFileName = fileName
            isPlaying = true
            duration = player.duration
            currentTime = 0
            startTimeTimer()
        } catch {
            print("⚠️ Oynatma hatası: \(error.localizedDescription)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimeTimer()
    }

    func resume() {
        player?.play()
        isPlaying = true
        startTimeTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        currentFileName = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimeTimer()
    }

    /// Belirli bir saniyeye sarar (ileri/geri).
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Oynatma bitti — PlayerDelegate köprüsünden çağrılır.
    func handlePlaybackFinished() {
        isPlaying = false
        currentTime = 0
        stopTimeTimer()
    }

    // MARK: - Süre takibi

    private func startTimeTimer() {
        timeTimer?.invalidate()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
            self.currentTimeHandler?(player.currentTime) // karaoke takibi
        }
    }

    private func stopTimeTimer() {
        timeTimer?.invalidate()
        timeTimer = nil
    }
}

/// @Observable class AVAudioPlayerDelegate olamayacağı için bitiş
/// sinyalini service'e ileten küçük köprü.
private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: AudioPlayerService?

    init(owner: AudioPlayerService) {
        self.owner = owner
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            owner?.handlePlaybackFinished()
        }
    }
}
