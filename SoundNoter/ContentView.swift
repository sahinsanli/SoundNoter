import SwiftUI

/// Yönlendirme merkezi. AppState'e bakarak kullanıcıyı
/// Splash → Onboarding → Login → Ana Ekran akışında yönlendirir.
struct ContentView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel = VoiceNoteViewModel()

    var body: some View {
        Group {
            if !appState.isSplashFinished {
                SplashView()
            } else if !appState.hasSeenOnboarding {
                OnboardingView()
            } else if !appState.isAuthenticated {
                LoginOptionsView()
            } else {
                MainListView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.isSplashFinished)
        .animation(.easeInOut(duration: 0.35), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: appState.hasSeenOnboarding)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [VoiceNote.self, TranscriptionChunk.self], inMemory: true)
}
