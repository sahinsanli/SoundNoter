import SwiftUI
import SwiftData

/// Ana ekran: kayıtların listelendiği, Glassmorphism tabanlı özel dock'a sahip liste.
/// @Query ile SwiftData'daki notlar otomatik listelenir.
struct MainListView: View {

    @Bindable var viewModel: VoiceNoteViewModel

    @Query(sort: \VoiceNote.createdAt, order: .reverse) private var voiceNotes: [VoiceNote]
    @Environment(\.modelContext) private var modelContext

    @State private var showRecording = false
    @State private var selectedNote: VoiceNote?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if voiceNotes.isEmpty {
                emptyState
            } else {
                notesList
            }

            // Glassmorphism floating dock — kayıt butonu.
            floatingDock
        }
        .navigationTitle("SoundNoter")
        .sheet(isPresented: $showRecording) {
            RecordingView(viewModel: viewModel)
                .presentationBackground(Theme.background)
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                NoteDetailView(viewModel: viewModel, voiceNote: note)
            }
            .presentationBackground(Theme.background)
        }
    }

    // MARK: - Liste

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(voiceNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        NoteCardView(note: note)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 140)
        }
    }

    // MARK: - Boş durum

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textSecondary)

            Text("Henüz kayıt yok")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Altaki butona basıp ilk ses kaydını oluştur")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.appBlue)
            }
        }
    }

    // MARK: - Floating dock

    private var floatingDock: some View {
        VStack {
            Spacer()
            HStack(spacing: 26) {
                dockIcon(system: "trash", label: "Sil") {
                    if let first = voiceNotes.first {
                        viewModel.deleteNote(first, modelContext: modelContext)
                    }
                }

                // Ana kayıt butonu — neon parlayan kırmızı daire.
                Button {
                    showRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Theme.appRed)
                        .clipShape(Circle())
                        .neonGlow(color: Theme.appRed, radius: 14)
                }

                dockIcon(system: "arrow.counterclockwise", label: "Yenile") {
                    if let failed = voiceNotes.first(where: { $0.status == .failed }) {
                        Task {
                            await viewModel.retryProcessing(failed, modelContext: modelContext)
                        }
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 44)
            .glassmorphicBackground(cornerRadius: 32)
            .padding(.bottom, 24)
        }
    }

    private func dockIcon(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Not kartı

/// Tek bir ses kaydının listedeki kart görünümü.
struct NoteCardView: View {
    let note: VoiceNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 16))

                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(note.createdAt.formatted(.dateTime.day().month().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if let summary = note.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label(durationText, systemImage: "clock")
                Label("\(note.keyPoints.count) madde", systemImage: "list.bullet")
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicBackground(cornerRadius: 20)
    }

    private var statusIcon: String {
        switch note.status {
        case .new: "circle.dotted"
        case .recording: "mic.fill"
        case .transcribing, .summarizing: "hourglass"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch note.status {
        case .new: Theme.textSecondary
        case .recording: Theme.appRed
        case .transcribing, .summarizing: Theme.appBlue
        case .completed: .green
        case .failed: Theme.appRed
        }
    }

    private var durationText: String {
        let minutes = Int(note.duration) / 60
        let seconds = Int(note.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MainListView(viewModel: VoiceNoteViewModel())
        .modelContainer(for: [VoiceNote.self, TranscriptionChunk.self], inMemory: true)
}
