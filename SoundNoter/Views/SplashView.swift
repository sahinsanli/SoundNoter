import SwiftUI

/// Açılış ekranı — logo neon parlar, kısa bir gecikme sonrası ana akışa geçer.
struct SplashView: View {

    @Environment(AppState.self) private var appState
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Theme.appBlue)
                    .neonGlow(color: Theme.appBlue, radius: isAnimating ? 18 : 6)

                Text("SoundNoter")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text("Sesini notlara dönüştür")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .scaleEffect(isAnimating ? 1.0 : 0.92)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            // Splash süresi — 1.6 saniye sonra devam.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation {
                    appState.isSplashFinished = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AppState())
}
