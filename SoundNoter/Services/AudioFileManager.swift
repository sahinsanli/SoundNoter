import Foundation

/// Ses dosyalarını cihazın Documents dizininde kaydeder, bulur ve siler.
enum AudioFileManager {

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var recordingsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Kayıt dosyasının tam URL'sini üretir (dosya henüz var olmayabilir).
    static func url(for fileName: String) -> URL {
        recordingsDirectory.appendingPathComponent(fileName)
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Toplam kayıt boyutunu bayt cinsinden döner (hata durumunda 0).
    static var totalSizeInBytes: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(Int64(0)) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }
}
