import SwiftUI

/// Uygulamanın Premium karanlık tema renklerinin ve parlama (Neon glow)
/// özelliklerinin merkezi noktası.
enum Theme {

    // MARK: - Renkler

    /// Ana mavi — neon vurgular.
    static let appBlue = Color(red: 0.25, green: 0.55, blue: 1.00)

    /// Canlı mor — ikincil vurgu.
    static let appPurple = Color(red: 0.62, green: 0.36, blue: 1.00)

    /// Kayıt aktif rengi.
    static let appRed = Color(red: 1.00, green: 0.28, blue: 0.36)

    /// Arka plan — derin karanlık.
    static let background = Color(red: 0.05, green: 0.05, blue: 0.08)

    /// Yüzey (kartlar) — hafif daha açık karanlık.
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.15)

    /// Ana metin rengi.
    static let textPrimary = Color.white

    /// İkincil metin rengi.
    static let textSecondary = Color(white: 0.62)

    // MARK: - Cam efekti (Glassmorphism)

    /// Yarı saydam, bulanıklaştırılmış cam görünümü.
    struct GlassmorphicBackground: ViewModifier {
        var cornerRadius: CGFloat

        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }

    // MARK: - Neon parlama

    /// İçerik etrafına renkli bir parlama (glow) ekler.
    struct NeonGlow: ViewModifier {
        var color: Color
        var radius: CGFloat

        func body(content: Content) -> some View {
            content
                .shadow(color: color.opacity(0.8), radius: radius)
                .shadow(color: color.opacity(0.4), radius: radius * 2)
        }
    }
}

// MARK: - View genişletmeleri

extension View {
    /// Cam efekti (Glassmorphism) arka planı uygular.
    func glassmorphicBackground(cornerRadius: CGFloat) -> some View {
        modifier(Theme.GlassmorphicBackground(cornerRadius: cornerRadius))
    }

    /// Neon parlama efekti uygular.
    func neonGlow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(Theme.NeonGlow(color: color, radius: radius))
    }
}
