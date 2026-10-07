import SwiftUI
import SwiftData

/// Kayıt ekranı — animasyonlu ses dalgaları (waveform) ve timer.
/// Kayıt bitince ViewModel.stopRecordingAndProcess() çağrılır ve
/// ekran otomatik "işleniyor" görünümüne geçer.
struct RecordingView: View {

    @Bindable var viewModel: VoiceNoteViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recordingFinished = false
    @State private var waveformBars: [CGFloat] = Array(repeating: 0.1, count: 36)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if recordingFinished {
                processingView
            } else {
                recordingInterface
            }
        }
        .interactiveDismissDisabled(viewModel.isRecording || viewModel.isProcessing)
    }

    // MARK: - Kayıt arayüzü

    private var recordingInterface: some View {
        VStack(spacing: 44) {
            Spacer()

            // Animasyonlu waveform — viewModel.audioLevel ile canlanır.
            WaveformView(level: viewModel.audioLevel, bars: $waveformBars)

            VStack(spacing: 8) {
                Text(timeText(viewModel.elapsedRecordingTime))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)

                Text(viewModel.isRecording ? "Kaydediliyor..." : "Hazır")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isRecording ? Theme.appRed : Theme.textSecondary)
            }

            Spacer()

            // Kayıt kontrol butonları.
            HStack(spacing: 48) {
                // İptal
                Button {
                    viewModel.stopObservingForCancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 60, height: 60)
                        .glassmorphicBackground(cornerRadius: 30)
                }

                // Kaydet / Durdur
                Button {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecordingAndProcess(modelContext: modelContext)
                            recordingFinished = true
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(viewModel.isRecording ? Theme.appRed : Theme.appBlue)
                        .clipShape(Circle())
                        .neonGlow(
                            color: viewModel.isRecording ? Theme.appRed : Theme.appBlue,
                            radius: 16
                        )
                }
            }
            .padding(.bottom, 56)
        }
        .task {
            await viewModel.startRecording()
        }
    }

    // MARK: - İşleniyor görünümü

    private var processingView: some View {
        VStack(spacing: 28) {
            Spacer()

            ProgressView()
                .scaleEffect(1.6)
                .tint(Theme.appBlue)

            Text("İşleniyor...")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut, value: viewModel.statusMessage)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Kapat ve listeye dön")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .glassmorphicBackground(cornerRadius: 100)
            }
            .disabled(viewModel.isProcessing)
            .opacity(viewModel.isProcessing ? 0.4 : 1)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Yardımcılar

    private func timeText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform

/// Ses seviyesine göre canlanan dalga formu göstergesi.
struct WaveformView: View {
    let level: Float
    @Binding var bars: [CGFloat]

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(
                        index < bars.count / 2
                            ? Theme.appBlue.gradient
                            : Theme.appPurple.gradient
                    )
                    .frame(width: 5, height: max(8, bars[index] * 90))
                    .neonGlow(color: Theme.appBlue.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 100)
        .onReceive(timer) { _ in
            // Her bar, merkeze yakınlığına göre ağırlıklandırılmış rastgele seviye alır.
            let center = CGFloat(bars.count) / 2
            for index in bars.indices {
                let distance = abs(CGFloat(index) - center) / center
                let weight = 1 - distance * 0.5
                let random = CGFloat.random(in: 0.25...1.0)
                bars[index] = CGFloat(level) * weight * random + 0.08
            }
        }
    }
}

#Preview {
    RecordingView(viewModel: VoiceNoteViewModel())
        .modelContainer(for: [VoiceNote.self, TranscriptionChunk.self], inMemory: true)
}
