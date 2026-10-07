import SwiftUI
import FirebaseAuth

/// E-posta giriş/kayıt ekranı — Firebase Auth.
struct EmailAuthView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let authService = AuthService()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 22) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.appBlue)
                        .neonGlow(color: Theme.appBlue, radius: 10)

                    Text(isSignUp ? "Hesap Oluştur" : "Giriş Yap")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    TextField("E-posta", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(16)
                        .glassmorphicBackground(cornerRadius: 14)

                    SecureField("Şifre", text: $password)
                        .textContentType(.password)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(16)
                        .glassmorphicBackground(cornerRadius: 14)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.appRed)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await authenticate() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(Theme.textPrimary)
                            } else {
                                Text(isSignUp ? "Kayıt Ol" : "Giriş Yap")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(isLoading || email.isEmpty || password.count < 6)

                    Button {
                        withAnimation { isSignUp.toggle() }
                    } label: {
                        Text(isSignUp ? "Zaten hesabın var mı? Giriş yap" : "Hesabın yok mu? Kayıt ol")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 28)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func authenticate() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            // AppState Firebase listener üzerinden isAuthenticated'ı true yapar.
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EmailAuthView()
}
