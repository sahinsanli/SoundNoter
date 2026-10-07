import Foundation
import Speech

/// Apple SFSpeechRecognizer ile kelimelerin söylenme zamanlarını (timestamp) çıkarır.
/// Karaoke tarzı metin takibinin veri kaynağı: ses çalarken currentTime ile
/// karşılaştırılıp doğru kelime parlatılır.
final class SpeechTimestampService {

    /// Kelime + zaman bilgisi (JSON'a kodlanıp VoiceNote'ta saklanır).
    struct TimestampedWord: Codable, Identifiable {
        let id: UUID
        let word: String
        let startTime: TimeInterval
        let endTime: TimeInterval

        init(word: String, startTime: TimeInterval, endTime: TimeInterval) {
            self.id = UUID()
            self.word = word
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    /// Konuşma tanıma izni ister.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Ses dosyasındaki her kelimenin başlangıç/bitiş saniyelerini çıkarır.
    func extractTimestamps(fileURL: URL, locale: Locale = Locale(identifier: "tr-TR")) async throws -> [TimestampedWord] {
        let granted = await requestAuthorization()
        guard granted else {
            throw NSError(
                domain: "SpeechTimestampService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Konuşma tanıma izni verilmedi"]
            )
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw NSError(
                domain: "SpeechTimestampService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Bu dil için tanıyıcı yok (\(locale.identifier))"]
            )
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.contextualStrings = [] // isim/terim ipuçları eklenebilir

        return try await withCheckedThrowingContinuation { continuation in
            var cancelled = false
            var resultHandler: ((SFSpeechRecognitionResult?, Error?) -> Void)!
            resultHandler = { result, error in
                if cancelled { return }
                if let error {
                    cancelled = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }

                cancelled = true
                let words = Self.extractWords(from: result)
                continuation.resume(returning: words)
            }
            recognizer.recognitionTask(with: request, resultHandler: resultHandler)
        }
    }

    /// Tanıma sonucundan kelime + zaman listesi üretir.
    private static func extractWords(from result: SFSpeechRecognitionResult) -> [TimestampedWord] {
        var words: [TimestampedWord] = []

        for transcription in result.transcriptions {
            for segment in transcription.segments {
                let word = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty else { continue }
                words.append(TimestampedWord(
                    word: word,
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration
                ))
            }
            // En iyi (best) transkripsiyonu kullan, alternatiflerle devam etme.
            if !words.isEmpty { break }
        }

        return words
    }

    // MARK: - JSON kodlama (VoiceNote'ta saklamak için)

    static func encode(_ words: [TimestampedWord]) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(words) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from json: String?) -> [TimestampedWord] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TimestampedWord].self, from: data)) ?? []
    }
}
