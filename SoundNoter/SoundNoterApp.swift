import SwiftUI
import SwiftData
import FirebaseCore

/// Uygulamanın giriş noktası:
/// Firebase başlatılır (AppDelegate), SwiftData veritabanı kurulur (ModelContainer),
/// AppState tüm ekranlara environment olarak verilir.
@main
struct SoundNoterApp: App {

    /// GoogleSignIn gibi UI akışı gerektiren SDK'lar için AppDelegate köprüsü.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var appState = AppState()

    /// SwiftData veritabanı — VoiceNote ve TranscriptionChunk tabloları.
    /// isStoredInMemoryOnly: false → veriler kalıcı olarak cihazda saklanır.
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VoiceNote.self,
            TranscriptionChunk.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Firebase'i uygulama başlangıcında yapılandırır.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("⚠️ GoogleService-Info.plist bulunamadı — Firebase devre dışı")
        }
        return true
    }
}
