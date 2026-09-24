import Foundation
import Combine

/// Persists the user's one-time choice of a storage *location* (any folder,
/// e.g. iCloud Drive) for 100P, via a security-scoped bookmark. The app
/// keeps its files in a "100P" folder inside that location — see
/// `storageFolder(inside:)`. (Keys are named "storageLocation…", not the
/// older "notebookFolder…" of the first build, which pointed at the picked
/// folder itself; the old choice is deliberately not carried over.)
/// Security-scoped-bookmark pattern (iOS only — 100P has no macOS target).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var storageLocationPath: String? {
        didSet {
            UserDefaults.standard.set(storageLocationPath, forKey: "storageLocationPath")
        }
    }

    /// Set once, on the same one-time first-setup screen as the folder
    /// picker. Printed in the PDF caption ahead of the timestamp — see
    /// `PDFExporter.captionText`.
    @Published var ownerName: String? {
        didSet {
            UserDefaults.standard.set(ownerName, forKey: "ownerName")
        }
    }

    @Published var showFolderPicker: Bool = false
    @Published var needsBookmarkRefresh: Bool = false

    private var securityScopedURL: URL?

    static let storageFolderName = "100P"

    /// The folder the app actually uses: a "100P" folder inside the location
    /// the user picked (created on first use by `iCloudFolderService`). If the
    /// user picked a folder that is itself called "100P", that one is used
    /// directly instead of nesting `100P/100P`.
    static func storageFolder(inside pickedLocation: URL) -> URL {
        if pickedLocation.lastPathComponent == storageFolderName { return pickedLocation }
        return pickedLocation.appendingPathComponent(storageFolderName, isDirectory: true)
    }

    private init() {
        storageLocationPath = UserDefaults.standard.string(forKey: "storageLocationPath")
        ownerName = UserDefaults.standard.string(forKey: "ownerName")

        if storageLocationPath == nil {
            showFolderPicker = true
        } else {
            let url = loadBookmarkedURL()
            if url == nil || securityScopedURL == nil {
                needsBookmarkRefresh = true
                showFolderPicker = true
            }
        }
    }

    var storageLocationURL: URL? {
        guard let path = storageLocationPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    func setStorageLocation(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "storageLocationBookmark")
            storageLocationPath = url.path
            needsBookmarkRefresh = false
        } catch {
            storageLocationPath = url.path
        }
    }

    /// Resolves the bookmarked folder and starts security-scoped access.
    /// Safe to call repeatedly; each successful call starts a new access
    /// session (matching the usual pattern — this app never calls
    /// `stopAccessingSecurityScopedResource()` since the folder needs to
    /// stay reachable for the whole app lifetime).
    @discardableResult
    func loadBookmarkedURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "storageLocationBookmark") else {
            return storageLocationURL
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if url.startAccessingSecurityScopedResource() {
                securityScopedURL = url
            }

            return url
        } catch {
            return storageLocationURL
        }
    }
}
