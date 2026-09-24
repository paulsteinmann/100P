import XCTest
@testable import HundredP

@MainActor
final class NotebookRolloverTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("100P-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func names() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    func testPageLimitIsOneHundred() {
        XCTAssertEqual(DeviceScale.maxPagesPerNotebook, 100)
    }

    func testPDFFileNameIsFourDigitsZeroPadded() {
        XCTAssertEqual(iCloudFolderService.pdfFileName(number: 1), "100P-0001.pdf")
        XCTAssertEqual(iCloudFolderService.pdfFileName(number: 42), "100P-0042.pdf")
    }

    func testSetupScreenLinesAreAtMostFiftyCharacters() {
        for line in FolderPickerView.titleLines + FolderPickerView.introLines {
            XCTAssertLessThanOrEqual(line.count, FolderPickerView.maxLineLength, line)
        }
    }

    func testResetDialogLinesAreAtMostFiftyCharacters() {
        for number in [1, 9, 99, 1234] {
            for line in ResetDialogView.lines(currentNumber: number) {
                XCTAssertLessThanOrEqual(line.count, FolderPickerView.maxLineLength, line)
            }
        }
    }

    func testStorageFolderIsA100PFolderInsideThePickedLocation() {
        let picked = URL(fileURLWithPath: "/iCloud/Documents", isDirectory: true)
        XCTAssertEqual(AppSettings.storageFolder(inside: picked).path, "/iCloud/Documents/100P")
    }

    func testPickingAFolderCalled100PDoesNotNest() {
        let picked = URL(fileURLWithPath: "/iCloud/100P", isDirectory: true)
        XCTAssertEqual(AppSettings.storageFolder(inside: picked).path, "/iCloud/100P")
    }

    func testServiceCreatesTheMissingStorageFolder() throws {
        let storage = AppSettings.storageFolder(inside: folder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.path))
        _ = try iCloudFolderService(rootURL: storage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.path))
    }

    func testFreshFolderStartsAtNumberOne() throws {
        let service = try iCloudFolderService(rootURL: folder)
        XCTAssertEqual(service.notebookNumber, 1)
        XCTAssertEqual(service.pdfURL.lastPathComponent, "100P-0001.pdf")
    }

    func testFreshInstallContinuesAfterHighestExistingPDF() throws {
        try Data().write(to: folder.appendingPathComponent("100P-0001.pdf"))
        try Data().write(to: folder.appendingPathComponent("100P-0003.pdf"))
        // iCloud placeholder for a PDF that isn't downloaded on this device.
        try Data().write(to: folder.appendingPathComponent(".100P-0004.pdf.icloud"))
        let service = try iCloudFolderService(rootURL: folder)
        XCTAssertEqual(service.notebookNumber, 5)
    }

    func testResetKeepsOldPDFAndStartsNewOneWithSingleBlankPage() throws {
        let store = NotebookStore(folderService: try iCloudFolderService(rootURL: folder))
        XCTAssertEqual(store.notebookNumber, 1)
        while store.canAddPage { store.addPage() }
        XCTAssertEqual(store.pageCount, 100)
        XCTAssertNil(store.addPage())
        let oldPDF = folder.appendingPathComponent("100P-0001.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldPDF.path))

        let firstPage = store.startNewNotebook()

        XCTAssertNotNil(firstPage)
        XCTAssertEqual(store.notebookNumber, 2)
        XCTAssertEqual(store.pageCount, 1)
        XCTAssertEqual(store.currentIndex, 0)
        XCTAssertTrue(names().contains("100P-0001.pdf"))
        XCTAssertTrue(names().contains("100P-0002.pdf"))
        // Only the new notebook's raw pages remain.
        XCTAssertEqual(names().filter { $0.hasPrefix(".100p-pages-") }, [".100p-pages-0002"])
    }

    func testNotebookNumberSurvivesRelaunch() throws {
        let store = NotebookStore(folderService: try iCloudFolderService(rootURL: folder))
        store.startNewNotebook()
        let relaunched = NotebookStore(folderService: try iCloudFolderService(rootURL: folder))
        XCTAssertEqual(relaunched.notebookNumber, 2)
        XCTAssertEqual(relaunched.pageCount, 1)
    }
}
