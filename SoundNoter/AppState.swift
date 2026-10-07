import Foundation
import Observation
import FirebaseCore
import FirebaseAuth

/// Uygulamanın anlık durumunu tutar:
/// Splash bitti mi? Onboarding görüldü mü? Kullanıcı giriş yapmış mı?
/// ContentView bu durumlara bakarak doğru ekranı gösterir.
@Observable
final class AppState {

    /// Splash ekranı bitti mi?
    var isSplashFinished: Bool = false

    /// Kullanıcı onboarding'i daha önce gördü mü?
    /// NOT: @Observable bağımlılık takibi stored property'lerde çalışır —
    /// UserDefaults'u doğrudan okuyan computed property view'ları GÜNCELLEMEZ.
    /// Bu yüzden stored property + didSet ile persist edilir.
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }
    /// Kullanıcı giriş yapmış mı?
    var isAuthenticated: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        // Persist edilmiş değeri yükle (ilk açılışta false).
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        setupFirebaseListener()
    }

    /// Firebase "auth state changed" sinyalini yakalar:
    /// giriş yapılınca isAuthenticated = true, çıkışta false olur ve
    /// ContentView otomatik olarak doğru ekranı gösterir.
    /// Firebase yapılandırılmamışsa (plist yok) sessizce atlanır —
    /// uygulama girişsiz de çalışabilmelidir.
    func setupFirebaseListener() {
        guard FirebaseApp.app() != nil else {
            print("⚠️ Firebase yapılandırılmamış (GoogleService-Info.plist eksik?) — auth dinleyicisi kurulmadı")
            return
        }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isAuthenticated = (user != nil)
        }
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
