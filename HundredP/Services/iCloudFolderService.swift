import Foundation
import PencilKit

/// One entry in `.100p-pages-<n>/index.json` — just enough to reconstruct page
/// order and the `createdAt` timestamp the PDF caption needs, independent of
/// filesystem metadata (which iCloud sync can rewrite).
struct StoredPageMeta: Codable {
    let index: Int
    let createdAt: Date
}

/// Resolves the user-chosen iCloud folder into the concrete sub-locations
/// 100P needs, and does the raw FileManager I/O for pages, their metadata,
/// and the exported PDF. Direct FileManager reads/writes, no
/// NSFileCoordinator/NSFilePresenter.
/// This folder is the single source of truth: raw `.drawing` files here
/// are what survive an app reinstall, not just the flattened PDF.
///
/// The folder holds any number of finished 100-page notebooks as
/// `100P-0001.pdf`, `100P-0002.pdf`, … — the app itself only ever works on
/// the newest one. Its raw pages live in `.100p-pages-<number>/`; starting a
/// new notebook creates the next numbered folder and deletes the old one,
/// while the old PDF stays untouched.
final class iCloudFolderService {
    private static let pagesFolderPrefix = ".100p-pages-"
    private static let pdfNamePattern = try! NSRegularExpression(pattern: #"^\.?100P-(\d+)\.pdf(\.icloud)?$"#)
    private let indexFileName = "index.json"

    private let rootURL: URL

    /// 1-based number of the notebook currently in use (`#1`, `#2`, …). Taken
    /// from the newest pages folder; with none there (first launch, or a
    /// fresh install into a folder that already holds old PDFs) it continues
    /// after the highest PDF number found, so a finished PDF is never
    /// overwritten.
    private(set) var notebookNumber: Int

    init(rootURL: URL) throws {
        self.rootURL = rootURL
        // The "100P" folder itself is created here on first use, inside the
        // location the user picked.
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let existingFolders = Self.pagesFolderNumbers(in: rootURL)
        if let newest = existingFolders.max() {
            notebookNumber = newest
        } else {
            notebookNumber = (Self.highestPDFNumber(in: rootURL) ?? 0) + 1
        }

        // A reset interrupted between creating the new pages folder and
        // deleting the old one leaves both behind; the older is stale.
        for number in existingFolders where number < notebookNumber {
            try? FileManager.default.removeItem(at: Self.pagesURL(in: rootURL, number: number))
        }
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
    }

    static func pdfFileName(number: Int) -> String {
        String(format: "100P-%04d.pdf", number)
    }

    var pdfURL: URL {
        rootURL.appendingPathComponent(Self.pdfFileName(number: notebookNumber))
    }

    private var pagesURL: URL {
        Self.pagesURL(in: rootURL, number: notebookNumber)
    }

    private static func pagesURL(in rootURL: URL, number: Int) -> URL {
        rootURL.appendingPathComponent(String(format: "%@%04d", pagesFolderPrefix, number), isDirectory: true)
    }

    private static func pagesFolderNumbers(in rootURL: URL) -> [Int] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: rootURL.path)) ?? []
        return names.compactMap { name in
            guard name.hasPrefix(pagesFolderPrefix) else { return nil }
            return Int(name.dropFirst(pagesFolderPrefix.count))
        }
    }

    /// Highest `100P-<n>.pdf` in the folder. Also recognizes the hidden
    /// `.100P-<n>.pdf.icloud` placeholder iCloud leaves for files that are
    /// not downloaded on this device.
    private static func highestPDFNumber(in rootURL: URL) -> Int? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: rootURL.path)) ?? []
        return names.compactMap { name -> Int? in
            let range = NSRange(name.startIndex..., in: name)
            guard let match = pdfNamePattern.firstMatch(in: name, range: range),
                  let digits = Range(match.range(at: 1), in: name) else { return nil }
            return Int(name[digits])
        }.max()
    }

    /// Moves on to the next notebook: switches to a fresh, empty pages
    /// folder (`notebookNumber + 1`) and deletes the old one. The old
    /// notebook's PDF is deliberately left alone — callers must have written
    /// its final version *before* calling this.
    func startNewNotebook() throws {
        let previousPagesURL = pagesURL
        notebookNumber += 1
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: previousPagesURL)
    }

    // MARK: - Metadata index

    private var indexURL: URL {
        pagesURL.appendingPathComponent(indexFileName)
    }

    func loadMetaIndex() -> [StoredPageMeta] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? decoder.decode([StoredPageMeta].self, from: data)) ?? []
        return entries.sorted { $0.index < $1.index }
    }

    func saveMetaIndex(_ entries: [StoredPageMeta]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries.sorted(by: { $0.index < $1.index })) else { return }
        try? atomicWrite(data: data, to: indexURL)
    }

    // MARK: - Page drawings

    private func fileURL(for page: NotebookPage) -> URL {
        pagesURL.appendingPathComponent(page.fileName)
    }

    func saveDrawing(_ page: NotebookPage) {
        let data = page.drawing.dataRepresentation()
        try? atomicWrite(data: data, to: fileURL(for: page))
    }

    private func loadDrawing(fileName: String) -> PKDrawing {
        let url = pagesURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return PKDrawing() }
        return (try? PKDrawing(data: data)) ?? PKDrawing()
    }

    // MARK: - Loading all pages at launch

    /// Loads every page found in the metadata index, in order. If the index
    /// is empty (first launch ever, nothing in iCloud yet), returns a
    /// single blank page and writes its metadata immediately.
    func loadAllPages() -> [NotebookPage] {
        let entries = loadMetaIndex()
        guard !entries.isEmpty else {
            let firstPage = NotebookPage(index: 0, createdAt: Date())
            saveMetaIndex([StoredPageMeta(index: 0, createdAt: firstPage.createdAt)])
            saveDrawing(firstPage)
            return [firstPage]
        }
        return entries.map { entry in
            let page = NotebookPage(index: entry.index, createdAt: entry.createdAt)
            page.drawing = loadDrawing(fileName: page.fileName)
            return page
        }
    }

    // MARK: - Atomic write helper (iCloud-sync-safe)

    func atomicWrite(data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } else {
            try FileManager.default.moveItem(at: tmpURL, to: url)
        }
    }
}
