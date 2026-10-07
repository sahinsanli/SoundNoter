import SwiftUI

/// İlk açılışta gösterilen tanıtım ekranı — 3 sayfalık kaydırılabilir onboarding.
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @State private var currentPage = 0

    private struct Page {
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
    }

    private let pages: [Page] = [
        Page(icon: "mic.fill", title: "Kaydet", subtitle: "Toplantıları, dersleri, fikirlerini tek dokunuşla sesli kaydet.", color: Theme.appRed),
        Page(icon: "text.bubble.fill", title: "Transkribe Et", subtitle: "Yapay zeka kayıtlarını otomatik olarak yazıya çevirir.", color: Theme.appBlue),
        Page(icon: "sparkles", title: "Özetle", subtitle: "Uzun kayıtların özetini ve anahtar noktalarını saniyeler içinde al.", color: Theme.appPurple),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 28) {
                            Image(systemName: page.icon)
                                .font(.system(size: 64))
                                .foregroundStyle(page.color)
                                .neonGlow(color: page.color, radius: 12)

                            Text(page.title)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)

                            Text(page.subtitle)
                                .font(.body)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    withAnimation {
                        appState.hasSeenOnboarding = true
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Başlayalım" : "Atla")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .glassmorphicBackground(cornerRadius: 100)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
