import SwiftUI
import UIKit

/// The one and only screen 100P shows besides the pages, and only until the
/// user has picked a storage location once.
///
/// Strictly black on white, in the same Menlo size as the caption line at the
/// foot of every page (`PDFExporter.liveCaptionFontSize`); gray appears only
/// for things that are disabled (empty name field placeholder, the button
/// while no name is entered). Lines are broken by hand so none is longer than
/// `maxLineLength` characters.
struct FolderPickerView: View {
    static let maxLineLength = 50

    static let titleLines = [
        "Wähle den Speicherort für deinen 100P-Ordner",
    ]

    static let introLines = [
        "Die App legt dort selbst einen Ordner „100P“ an.",
        "Darin liegen alle deine PDFs:",
        "100P-0001.pdf, 100P-0002.pdf, …",
        "Du erreichst sie über die Dateien-App",
        "bzw. den Finder. Am besten wählst du iCloud.",
    ]

    @ObservedObject var settings: AppSettings
    @State private var showDocumentPicker = false
    @State private var ownerName: String = ""

    private var trimmedOwnerName: String {
        ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 28) {
            Image("Startup")
                .resizable()
                .scaledToFit()
                .frame(width: 432)
                .accessibilityHidden(true)

            centeredLines(Self.titleLines)

            centeredLines(Self.introLines)

            // Printed in the PDF caption ahead of the timestamp on every
            // page — see PDFExporter.captionText. Asked here because this
            // is the one-time first-setup screen; there's no settings UI
            // to change it later (100P has none).
            TextField("", text: $ownerName, prompt: Text("Dein Name").foregroundColor(.gray))
                .font(.hundredP)
                .foregroundColor(.black)
                .tint(.black)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .padding(.vertical, 10)
                .frame(maxWidth: 432)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))

            Button("Speicherort auswählen") {
                settings.ownerName = trimmedOwnerName
                showDocumentPicker = true
            }
            .buttonStyle(PillButtonStyle())
            .disabled(trimmedOwnerName.isEmpty)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showDocumentPicker) {
            NotebookDocumentPicker(settings: settings)
        }
    }

    private func centeredLines(_ lines: [String]) -> some View {
        VStack(spacing: 4) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.hundredP)
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

struct NotebookDocumentPicker: UIViewControllerRepresentable {
    let settings: AppSettings

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: NotebookDocumentPicker

        init(_ parent: NotebookDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            parent.settings.setStorageLocation(url: url)
            url.stopAccessingSecurityScopedResource()
            parent.settings.showFolderPicker = false
        }
    }
}
