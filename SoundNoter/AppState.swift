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
    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    /// Kullanıcı giriş yapmış mı?
    var isAuthenticated: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
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
