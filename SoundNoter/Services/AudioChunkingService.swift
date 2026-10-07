import Foundation
import AVFoundation

/// Uzun ses dosyalarını küçük parçalara böler.
/// Yapay zeka API'lerinin dosya/süre limitlerine takılmamak için
/// AVAssetExportSession ile sesi hafızayı yormadan parçalara ayırır.
enum AudioChunkingService {

    /// Varsayılan parça uzunluğu: 5 dakika (API limiti).
    static let chunkDuration: TimeInterval = 300

    /// Ses dosyasını belirtilen uzunlukta m4a parçalarına böler.
    /// - Returns: (dosya URL'i, başlangıç saniyesi, bitiş saniyesi) üçlüleri.
    static func chunkAudio(
        fileURL: URL,
        chunkLength: TimeInterval = chunkDuration
    ) async throws -> [(url: URL, start: TimeInterval, end: TimeInterval)] {

        let asset = AVURLAsset(url: fileURL)
        let totalDuration = try await loadDuration(of: asset)

        guard totalDuration > chunkLength else {
            // Dosya zaten kısa — tek parça olarak döndür.
            return [(fileURL, 0, totalDuration)]
        }

        var chunks: [(url: URL, start: TimeInterval, end: TimeInterval)] = []
        let chunkCount = Int(ceil(totalDuration / chunkLength))

        for index in 0..<chunkCount {
            let start = TimeInterval(index) * chunkLength
            let end = min(start + chunkLength, totalDuration)

            let exportURL = AudioFileManager.recordingsDirectory
                .appendingPathComponent("chunk-\(index)-\(UUID().uuidString).m4a")

            try await exportAsset(
                asset,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: start, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600)
                ),
                to: exportURL
            )

            chunks.append((exportURL, start, end))
        }

        return chunks
    }

    /// Geçici chunk dosyalarını temizler.
    static func cleanupChunks(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Yardımcılar

    private static func loadDuration(of asset: AVURLAsset) async throws -> TimeInterval {
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    private static func exportAsset(
        _ asset: AVURLAsset,
        timeRange: CMTimeRange,
        to outputURL: URL
    ) async throws {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(
                domain: "AudioChunkingService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Export oturumu oluşturulamadı"]
            )
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exportSession.status == .completed else {
            throw NSError(
                domain: "AudioChunkingService",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Parça dışa aktarılamadı: \(exportSession.error?.localizedDescription ?? "bilinmeyen")"
                ]
            )
        }
    }
}
