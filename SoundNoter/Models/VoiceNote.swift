import Foundation
import SwiftData

/// Bir ses kaydının işlem durumunu belirler.
/// String + Codable: veritabanına metin olarak kaydedilebilir.
enum ProcessingStatus: String, Codable {
    case new            // Yeni oluşturulmuş
    case recording      // Kayıt alınıyor
    case transcribing   // Metne çevriliyor
    case summarizing    // Özetleniyor
    case completed      // Tamamlandı
    case failed         // Hata oluştu
}

/// Uygulamanın ana veri modeli: bir ses kaydı notu.
/// SwiftData @Model — veritabanı tablosu.
@Model
final class VoiceNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var audioFileName: String
    var duration: TimeInterval
    var fullTranscription: String?
    var summary: String?
    var keyPoints: [String]
    var statusRawValue: String

    /// Karaoke takibi için kelimelerin zaman damgaları (JSON saklanır).
    var timestampedWordsJSON: String?

    /// Bir notun birden fazla chunk'ı olabilir; not silinince chunk'lar da silinir (cascade).
    @Relationship(deleteRule: .cascade, inverse: \TranscriptionChunk.voiceNote)
    var chunks: [TranscriptionChunk]

    var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: statusRawValue) ?? .new }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        audioFileName: String,
        duration: TimeInterval,
        fullTranscription: String? = nil,
        summary: String? = nil,
        keyPoints: [String] = [],
        status: ProcessingStatus = .new,
        timestampedWordsJSON: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.audioFileName = audioFileName
        self.duration = duration
        self.fullTranscription = fullTranscription
        self.summary = summary
        self.keyPoints = keyPoints
        self.statusRawValue = status.rawValue
        self.timestampedWordsJSON = timestampedWordsJSON
        self.chunks = []
    }
}
