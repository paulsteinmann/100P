import SwiftUI

/// The "notebook is full" dialog, shown when page 101 is requested. Custom
/// instead of a system `UIAlertController` so it follows the app's look:
/// Menlo, black on white, pill buttons. Presented full screen by
/// `PagerViewController`.
struct ResetDialogView: View {
    let currentNumber: Int
    let onCancel: () -> Void
    let onReset: () -> Void

    static func title() -> String {
        "\(DeviceScale.maxPagesPerNotebook) Seiten voll"
    }

    static func lines(currentNumber: Int) -> [String] {
        [
            "Reset löscht alle Seiten in der App und",
            "beginnt PDF #\(currentNumber + 1) mit einer leeren ersten Seite.",
            "PDF #\(currentNumber) bleibt in iCloud erhalten.",
        ]
    }

    var body: some View {
        ZStack {
            // Dimming is a light white wash, not a gray one.
            Color.white.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(Self.title())
                    .font(.hundredP)
                    .foregroundColor(.black)

                VStack(spacing: 4) {
                    ForEach(Self.lines(currentNumber: currentNumber), id: \.self) { line in
                        Text(line)
                            .font(.hundredP)
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }

                HStack(spacing: 16) {
                    Button("Abbrechen", action: onCancel)
                        .buttonStyle(PillButtonStyle())
                    Button("Reset", action: onReset)
                        .buttonStyle(PillButtonStyle(filled: true))
                }
            }
            .padding(36)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
        }
        .preferredColorScheme(.light)
    }
}
