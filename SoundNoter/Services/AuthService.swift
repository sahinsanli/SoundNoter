import Foundation
import FirebaseCore
import FirebaseAuth

/// Firebase üzerinden E-posta ve Google ile giriş/çıkış işlemlerini yapar.
final class AuthService: ObservableObject {

    /// Aktif kullanıcı (giriş yapılmadıysa nil).
    @Published private(set) var currentUser: User?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Firebase "auth state changed" sinyalini dinle — AppState bu servisi gözlemler.
        // Firebase yapılandırılmamışsa sessizce atlanır.
        guard FirebaseApp.app() != nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - E-posta

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    // MARK: - Google

    /// Google ile giriş. GoogleSignIn UI akışı AppDelegate üzerinden yürür;
    /// burada elde edilen kimlik Firebase'e aktarılır.
    func signIn(withGoogle idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Çıkış

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
