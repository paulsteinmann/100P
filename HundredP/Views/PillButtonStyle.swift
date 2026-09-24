import SwiftUI

extension Font {
    /// The one font of every 100P screen besides the pages: Menlo at the size
    /// of the caption line at the foot of each page.
    static let hundredP = Font.custom("Menlo", fixedSize: PDFExporter.liveCaptionFontSize)
}

/// Pill-shaped (fully rounded) push button, black and white only: black outline
/// and text on white, or — `filled` — white text on black. Inverted while
/// pressed. Gray only when disabled. Used for every button in the app, so
/// they stand clearly apart from the square name field.
struct PillButtonStyle: ButtonStyle {
    var filled = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let ink: Color = isEnabled ? .black : .gray
        let pressed = configuration.isPressed && isEnabled
        let solid = filled != pressed   // pressed flips the look
        return configuration.label
            .font(.hundredP)
            .foregroundColor(solid ? .white : ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Capsule().fill(solid ? ink : Color.white))
            .overlay(Capsule().stroke(ink, lineWidth: 1.5))
    }
}
