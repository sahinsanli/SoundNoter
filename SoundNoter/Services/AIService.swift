import Foundation

/// Yapay zeka servisi: ses parçalarını metne çevirir (transkripsiyon),
/// ardından tüm metni özetleyip anahtar noktaları çıkarır.
/// Google Gemini REST API ile iletişim kurar.
final class AIService {

    /// Gemini API anahtarı Info.plist'ten okunur (GEMINI_API_KEY).
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var isConfigured: Bool { !apiKey.isEmpty }

    // MARK: - Transkripsiyon

    /// Ses parçasını base64 ile Gemini'a gönderir, metni geri alır.
    func transcribeAudio(fileURL: URL) async throws -> String {
        guard isConfigured else {
            throw AIServiceError.notConfigured
        }

        let audioData = try Data(contentsOf: fileURL)

        struct InlineData: Codable {
            let mimeType: String
            let data: String
        }
        struct Part: Codable {
            let inlineData: InlineData
        }
        struct Content: Codable {
            let parts: [Part]
        }
        struct Request: Codable {
            let contents: [Content]
        }

        let request = Request(contents: [
            Content(parts: [
                Part(inlineData: InlineData(
                    mimeType: "audio/m4a",
                    data: audioData.base64EncodedString()
                ))
            ])
        ])

        let text = try await post(
            model: "gemini-2.0-flash",
            request: request,
            prompt: nil
        )
        return text
    }

    // MARK: - Özetleme

    /// Tam transkripsiyon metnini özetler; özet ve anahtar noktaları döner.
    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String]) {
        guard isConfigured else {
            throw AIServiceError.notConfigured
        }

        struct TextPart: Codable {
            let text: String
        }
        struct Content: Codable {
            let parts: [TextPart]
        }
        struct Request: Codable {
            let contents: [Content]
            let generationConfig: GenerationConfig?
        }
        struct GenerationConfig: Codable {
            let responseMimeType: String
            let responseSchema: [Schema]
        }
        struct Schema: Codable {
            let type: String
            let properties: [String: SchemaProperty]?
            let items: SchemaItems?
        }
        struct SchemaProperty: Codable {
            let type: String
        }
        struct SchemaItems: Codable {
            let type: String
        }

        let prompt = """
        Aşağıdaki ses kaydı transkripsiyonunu analiz et.

        1. Kaydın kısa ve öz bir özetini yaz (Türkçe).
        2. Kayıtta geçen en önemli 3-6 anahtar noktayı madde madde çıkar.

        Transkripsiyon:
        \(transcript)
        """

        let request = Request(
            contents: [Content(parts: [TextPart(text: prompt)])],
            generationConfig: GenerationConfig(
                responseMimeType: "application/json",
                responseSchema: [
                    Schema(type: "object", properties: [
                        "summary": SchemaProperty(type: "string"),
                        "key_points": SchemaProperty(type: "array")
                    ], items: nil),
                    Schema(type: "array", properties: nil, items: SchemaItems(type: "string"))
                ]
            )
        )

        let raw = try await postJSON(model: "gemini-2.0-flash", request: request)

        // Yanıt: { "summary": "...", "key_points": ["...", "..."] }
        struct SummaryResponse: Codable {
            let summary: String
            let keyPoints: [String]

            enum CodingKeys: String, CodingKey {
                case summary
                case keyPoints = "key_points"
            }
        }

        // Gemini JSON'u bazen markdown çiti içine sarar — temizle.
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SummaryResponse.self, from: data) {
            return (decoded.summary, decoded.keyPoints)
        }

        // Şema çözümlemesi başarısızsa ham metni özet olarak kullan.
        return (cleaned, [])
    }

    // MARK: - Ağ katmanı

    private func post(model: String, request: some Encodable, prompt: String?) async throws -> String {
        try await postJSON(model: model, request: request)
    }

    private func postJSON(model: String, request: some Encodable) async throws -> String {
        var urlComponents = URLComponents(string: "\(baseURL)/\(model):generateContent")!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = urlComponents.url else {
            throw AIServiceError.badURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 120

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIServiceError.httpError(status: code, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return text
    }
}

/// Gemini generateContent yanıt zarfı.
private struct GeminiAPIResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Hatalar

enum AIServiceError: LocalizedError {
    case notConfigured
    case badURL
    case httpError(status: Int, body: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Gemini API anahtarı eksik (Info.plist → GEMINI_API_KEY)"
        case .badURL:
            "Geçersiz istek adresi"
        case .httpError(let status, let body):
            "API hatası (\(status)): \(body.prefix(200))"
        case .emptyResponse:
            "Yapay zeka boş yanıt döndürdü"
        }
    }
}
