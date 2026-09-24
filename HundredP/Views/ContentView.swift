import SwiftUI

/// Root view: shows the (one-time) folder picker until a folder is chosen,
/// then hands off entirely to the pager. No other UI exists.
struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var store: NotebookStore?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let store {
                PagerView(store: store)
                    .ignoresSafeArea()
            } else {
                FolderPickerView(settings: settings)
            }
        }
        .onAppear(perform: setupStoreIfPossible)
        .onChange(of: settings.storageLocationPath) { _, _ in setupStoreIfPossible() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                store?.regeneratePDF()
            }
        }
    }

    private func setupStoreIfPossible() {
        guard store == nil else { return }
        guard let url = settings.loadBookmarkedURL() else { return }
        guard let folderService = try? iCloudFolderService(rootURL: AppSettings.storageFolder(inside: url)) else { return }
        store = NotebookStore(folderService: folderService)
    }
}
