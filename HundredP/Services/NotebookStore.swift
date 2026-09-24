import Foundation
import Combine
import PencilKit
import UIKit

/// Owns the in-memory list of pages, debounces per-page saves to the iCloud
/// folder, and triggers PDF regeneration on the two specified occasions:
/// backgrounding (see HundredPApp.swift's scenePhase handling) and immediately
/// after a new page is added.
@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var pages: [NotebookPage]
    @Published private(set) var currentIndex: Int = 0

    private let folderService: iCloudFolderService
    private var saveWorkItems: [Int: DispatchWorkItem] = [:]
    private let saveDebounce: TimeInterval = 1.5

    init(folderService: iCloudFolderService) {
        self.folderService = folderService
        let loadedPages = folderService.loadAllPages()
        self.pages = loadedPages
        // Reopen where you left off — like a physical notebook, not back to page 1.
        self.currentIndex = max(0, loadedPages.count - 1)
    }

    var pageCount: Int { pages.count }

    /// `#1`, `#2`, … — which 100-page PDF is currently being written.
    var notebookNumber: Int { folderService.notebookNumber }

    var isOnLastPage: Bool {
        currentIndex == pages.count - 1
    }

    var canAddPage: Bool {
        pages.count < DeviceScale.maxPagesPerNotebook
    }

    func page(at index: Int) -> NotebookPage? {
        guard pages.indices.contains(index) else { return nil }
        return pages[index]
    }

    func setCurrentIndex(_ index: Int) {
        currentIndex = index
    }

    /// Call from PKCanvasViewDelegate.canvasViewDrawingDidChange. Debounced
    /// so a burst of pen strokes doesn't hammer the filesystem/iCloud sync.
    func drawingDidChange(for page: NotebookPage) {
        // A page left over from before a reset can still report a late
        // change; its index would collide with the new notebook's pages.
        guard pages.contains(where: { $0 === page }) else { return }
        saveWorkItems[page.index]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.folderService.saveDrawing(page)
        }
        saveWorkItems[page.index] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: workItem)
    }

    /// Forces an immediate (non-debounced) save of every page. Call this on
    /// scenePhase transitions to background/inactive so nothing is lost even
    /// if the debounce timer hasn't fired yet — iOS can terminate the app
    /// without notice.
    func flushAllSaves() {
        for workItem in saveWorkItems.values {
            workItem.cancel()
        }
        saveWorkItems.removeAll()
        for page in pages {
            folderService.saveDrawing(page)
        }
    }

    /// Returns `nil` once `canAddPage` is false instead of ever exceeding
    /// `DeviceScale.maxPagesPerNotebook` — callers (see
    /// `PagerViewController`) check `canAddPage` first and offer
    /// `startNewNotebook()` via the reset dialog instead.
    @discardableResult
    func addPage() -> NotebookPage? {
        guard canAddPage else { return nil }
        let newPage = NotebookPage(index: pages.count, createdAt: Date())
        pages.append(newPage)
        folderService.saveDrawing(newPage)
        folderService.saveMetaIndex(pages.map { StoredPageMeta(index: $0.index, createdAt: $0.createdAt) })
        regeneratePDF()
        return newPage
    }

    /// The reset flow, run after the user confirmed the dialog shown when
    /// page 101 is requested: writes the full PDF one last time, switches to
    /// the next notebook (old PDF stays in iCloud, old raw pages are
    /// deleted), and immediately writes the new PDF with its blank first
    /// page. Returns that first page.
    @discardableResult
    func startNewNotebook() -> NotebookPage? {
        regeneratePDF()
        do {
            try folderService.startNewNotebook()
        } catch {
            return nil
        }
        let freshPages = folderService.loadAllPages()
        pages = freshPages
        currentIndex = 0
        regeneratePDF()
        return freshPages.first
    }

    /// On `scenePhase` transitioning to background, iOS only guarantees the
    /// app a very short slice of run time before it may be frozen —
    /// `regeneratePDF()`'s synchronous render + atomic write can occasionally
    /// lose that race and get cut off mid-write. Wrapping it in an explicit
    /// background task tells iOS to keep the app runnable for up to ~30s so
    /// the write actually finishes, instead of racing the freeze. Cheap and
    /// harmless on the addPage() call path too (finishes in milliseconds,
    /// ends the task immediately).
    func regeneratePDF() {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: "100P.regeneratePDF")
        flushAllSaves()
        let data = PDFExporter.data(
            for: pages,
            notebookNumber: notebookNumber,
            ownerName: AppSettings.shared.ownerName ?? ""
        )
        try? folderService.atomicWrite(data: data, to: folderService.pdfURL)
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
