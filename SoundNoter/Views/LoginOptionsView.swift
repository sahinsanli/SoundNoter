import SwiftUI

/// Giriş seçenekleri ekranı — E-posta veya Google ile giriş.
struct LoginOptionsView: View {

    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.appBlue)
                    .neonGlow(color: Theme.appBlue, radius: 14)

                Text("SoundNoter'a hoş geldin")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text("Devam etmek için giriş yap")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showEmailAuth = true
                    } label: {
                        Label("E-posta ile devam et", systemImage: "envelope.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassPrimary)

                    // Google ile giriş — Firebase Auth (GoogleSignIn UI akışı).
                    // AuthService.signIn(withGoogle:accessToken:) ile Firebase'e aktarılır.
                    Button {
                        // GoogleSignIn akışı buradan tetiklenir.
                        GoogleSignInBridge.shared.present()
                    } label: {
                        HStack(spacing: 10) {
                            Text("G")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Theme.textPrimary.opacity(0.1))
                                .clipShape(Circle())

                            Text("Google ile devam et")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassPrimary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
    }
}

/// GoogleSignIn UI köprüsü. AppDelegate URL回调larını yönlendirir.
/// Not: Gerçek client ID, GoogleService-Info.plist'ten okunmalıdır.
@Observable
final class GoogleSignInBridge {
    static let shared = GoogleSignInBridge()

    func present() {
        // GoogleSignIn SDK UI akışı:
        // GIDSignIn.sharedInstance.signIn(withPresenting:) → idToken/accessToken
        // → AuthService.signIn(withGoogle:accessToken:)
        // Kurulum adımı README'de detaylı anlatılmıştır.
        print("ℹ️ GoogleSignIn: kurulum adımları için README'ye bak (client ID gerekli)")
    }
}

// MARK: - Glass buton stili

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassmorphicBackground(cornerRadius: 18)
            .neonGlow(color: Theme.appBlue.opacity(0.35), radius: 8)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}

#Preview {
    LoginOptionsView()
}
