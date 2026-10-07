import Foundation
import SwiftData

/// Uzun ses kayıtlarını yapay zekaya parça parça göndermek için kullanılan model.
/// Sesin hangi saniyeleri arasını içerdiğini ve o parçanın metnini tutar.
@Model
final class TranscriptionChunk {
    @Attribute(.unique) var id: UUID
    var index: Int              // Kaçıncı parça (0, 1, 2...)
    var startTime: TimeInterval // Parçanın başlangıç saniyesi
    var endTime: TimeInterval   // Parçanın bitiş saniyesi
    var text: String            // Bu parçadan çıkarılan metin
    var createdAt: Date

    var voiceNote: VoiceNote?

    init(
        id: UUID = UUID(),
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.createdAt = createdAt
    }
}
