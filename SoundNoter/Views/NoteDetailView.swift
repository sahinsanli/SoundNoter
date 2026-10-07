import SwiftUI
import SwiftData

/// Not detay ekranı:
/// - Karaoke tarzı (kelime kelime aydınlanan) transkripsiyon takibi
/// - Apple Music tarzı ses çalar (AudioPlayerService)
/// - AI özet + anahtar noktalar
struct NoteDetailView: View {

    @Bindable var viewModel: VoiceNoteViewModel
    let voiceNote: VoiceNote

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Kelime zaman damgaları (karaoke takibi için).
    @State private var timestampedWords: [SpeechTimestampService.TimestampedWord] = []

    /// Şu an parlayan kelime indeksi.
    @State private var activeWordIndex: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                playerCard
                if let summary = voiceNote.summary { summaryCard(summary) }
                if !voiceNote.keyPoints.isEmpty { keyPointsCard }
                if let transcription = voiceNote.fullTranscription {
                    transcriptionCard(transcription)
                }
            }
            .padding(18)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Not")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    viewModel.deleteNote(voiceNote, modelContext: modelContext)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.appRed)
                }
            }
        }
        .onAppear {
            timestampedWords = SpeechTimestampService.decode(from: voiceNote.timestampedWordsJSON)
            viewModel.player.currentTimeHandler = { [self] time in
                updateActiveWord(for: time)
            }
        }
        .onDisappear {
            viewModel.player.currentTimeHandler = nil
            viewModel.player.stop()
        }
    }

    // MARK: - Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(voiceNote.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text("\(voiceNote.createdAt.formatted(date: .long, time: .shortened)) · \(timeText(voiceNote.duration))")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Ses çalar

    private var playerCard: some View {
        HStack(spacing: 18) {
            // Oynat/duraklat butonu.
            Button {
                if viewModel.player.isPlaying {
                    viewModel.player.pause()
                } else if viewModel.player.currentFileName == voiceNote.audioFileName {
                    viewModel.player.resume()
                } else {
                    viewModel.player.play(fileName: voiceNote.audioFileName)
                }
            } label: {
                Image(systemName: viewModel.player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.appBlue)
                    .clipShape(Circle())
                    .neonGlow(color: Theme.appBlue, radius: 10)
            }

            VStack(spacing: 6) {
                // İlerleme çubuğu — sürüklenerek ileri/geri sarılabilir.
                Slider(
                    value: Binding(
                        get: { viewModel.player.currentTime },
                        set: { viewModel.player.seek(to: $0) }
                    ),
                    in: 0...max(voiceNote.duration, 0.1)
                )
                .tint(Theme.appBlue)

                HStack {
                    Text(timeText(viewModel.player.currentTime))
                    Spacer()
                    Text(timeText(voiceNote.duration))
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .glassmorphicBackground(cornerRadius: 22)
    }

    // MARK: - Özet

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Özet", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Theme.appPurple)

            Text(summary)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicBackground(cornerRadius: 22)
    }

    // MARK: - Anahtar noktalar

    private var keyPointsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Anahtar Noktalar", systemImage: "list.bullet")
                .font(.headline)
                .foregroundStyle(Theme.appBlue)

            ForEach(Array(voiceNote.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.appBlue)
                        .frame(width: 22, height: 22)
                        .background(Theme.appBlue.opacity(0.15))
                        .clipShape(Circle())
                        .padding(.top, 2)

                    Text(point)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicBackground(cornerRadius: 22)
    }

    // MARK: - Karaoke transkripsiyon

    /// Kelimeler ses ile senkron aydınlanır: söylenmiş kelimeler parlak,
    /// söylenmemişler soluk gösterilir.
    private func transcriptionCard(_ transcription: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transkripsiyon", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)

            if timestampedWords.isEmpty {
                // Timestamp yoksa düz metin göster.
                Text(transcription)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(4)
            } else {
                // Karaoke modu: kelime kelime akış.
                FlowLayout(spacing: 6) {
                    ForEach(Array(timestampedWords.enumerated()), id: \.element.id) { index, word in
                        Text(word.word)
                            .font(.body)
                            .foregroundStyle(
                                index <= activeWordIndex
                                    ? Theme.textPrimary
                                    : Theme.textSecondary.opacity(0.45)
                            )
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                index == activeWordIndex
                                    ? Theme.appBlue.opacity(0.18)
                                    : .clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .animation(.easeInOut(duration: 0.15), value: activeWordIndex)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicBackground(cornerRadius: 22)
    }

    // MARK: - Karaoke mantığı

    /// Oynatma süresine göre parlayan kelimeyi günceller.
    private func updateActiveWord(for time: TimeInterval) {
        var newIndex = -1
        for (index, word) in timestampedWords.enumerated() where word.startTime <= time {
            newIndex = index
        }
        if newIndex != activeWordIndex {
            activeWordIndex = newIndex
        }
    }

    private func timeText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Akış düzeni (kelimeler satır sonuna taşar)

/// Basit sarma düzeni — kelimeleri satır dolunca alt satıra kaydırır.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + width, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(
            viewModel: VoiceNoteViewModel(),
            voiceNote: VoiceNote(audioFileName: "sample.m4a", duration: 95)
        )
    }
    .modelContainer(for: [VoiceNote.self, TranscriptionChunk.self], inMemory: true)
}
