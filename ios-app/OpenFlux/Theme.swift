import SwiftUI
import UIKit

/// Design tokens for the redesigned UI — mirrors the agreed light/dark
/// palette (see the design reference), using dynamic UIColor so it tracks
/// the system appearance automatically, same as the reference's
/// `prefers-color-scheme` behaviour.
enum Theme {
    static let ground      = dynamic(light: 0xF3F4F6, dark: 0x0B0D11)
    static let surface     = dynamic(light: 0xFFFFFF, dark: 0x15181D)
    static let surface2    = dynamic(light: 0xF7F8FA, dark: 0x1B1F26)
    static let border      = dynamic(light: 0xE1E4E9, dark: 0x272C34)
    static let ink         = dynamic(light: 0x14171C, dark: 0xEDEEF1)
    static let inkMuted    = dynamic(light: 0x6B7280, dark: 0x8E96A3)
    static let inkFaint    = dynamic(light: 0x9AA1AC, dark: 0x666E7A)
    static let accent      = dynamic(light: 0x3162E0, dark: 0x5B87F5)
    static let accentInk   = dynamic(light: 0xFFFFFF, dark: 0x0B0D11)
    static let accentWash  = dynamic(light: 0xE8EEFF, dark: 0x1B2436)
    static let success     = dynamic(light: 0x1E9E63, dark: 0x3BC787)
    static let successWash = dynamic(light: 0xE4F7ED, dark: 0x132821)
    static let warning     = dynamic(light: 0xB4740C, dark: 0xE3A83B)
    static let warningWash = dynamic(light: 0xFBF0DC, dark: 0x2B2214)
    static let danger      = dynamic(light: 0xD23B3B, dark: 0xF0605F)
    static let dangerWash  = dynamic(light: 0xFBE7E7, dark: 0x2C1717)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    /// UI text at a standard system text style (`.body`, `.subheadline`,
    /// `.footnote`, …) — same sizes iOS itself uses everywhere else, and
    /// they scale with the user's Dynamic Type setting. Stands in for the
    /// reference's "Instrument Sans"; swap in a real font later if wanted
    /// (add the .ttf to Assets, register it in Info.plist under
    /// UIAppFonts, then replace `.system` here with `.custom`).
    static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default).weight(weight)
    }
    /// Monospaced text (log, addresses, technical values) at a standard
    /// system text style — same size scale as `ui`, just the built-in
    /// monospaced design instead of the reference's "IBM Plex Mono".
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}
