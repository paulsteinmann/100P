import XCTest
@testable import HundredP

final class PDFLayoutTests: XCTestCase {
    private let pageRect = CGRect(origin: .zero, size: DeviceScale.a4PageSize)

    func testHairlineRectIsCenteredHorizontallyAndVertically() {
        let rect = PDFExporter.hairlineRect(in: pageRect)
        let leftMargin = rect.minX
        let rightMargin = pageRect.width - rect.maxX
        let topMargin = rect.minY
        let bottomMargin = pageRect.height - rect.maxY

        XCTAssertEqual(leftMargin, rightMargin, accuracy: 0.01)
        XCTAssertEqual(topMargin, bottomMargin, accuracy: 0.01)
        XCTAssertEqual(leftMargin, 18.3, accuracy: 0.5)
        XCTAssertEqual(topMargin, 48.4, accuracy: 0.5)
    }

    func testCaptionFitsWithinBottomMargin() {
        let rect = PDFExporter.hairlineRect(in: pageRect)
        let bottomMargin = pageRect.height - rect.maxY
        let captionSpaceNeeded = PDFExporter.gapBelowHairline + PDFExporter.lineHeight
        XCTAssertLessThan(captionSpaceNeeded, bottomMargin, "Caption must fit inside the bottom margin below the hairline")
    }

    func testCaptionTextFormatWithOwnerName() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 27
        components.hour = 14
        components.minute = 32
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let date = calendar.date(from: components)!

        let page = NotebookPage(index: 0, createdAt: date)
        let text = PDFExporter.captionText(page: page, totalPages: 42, ownerName: "Max Mustermann")

        XCTAssertEqual(text, "Max Mustermann  20260827 14:32  001/042%")
    }

    func testCaptionTextFormatWithoutOwnerName() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 27
        components.hour = 14
        components.minute = 32
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let date = calendar.date(from: components)!

        let page = NotebookPage(index: 0, createdAt: date)
        let text = PDFExporter.captionText(page: page, totalPages: 42, ownerName: "")

        XCTAssertEqual(text, "20260827 14:32  001/042%")
    }

    func testCaptionTextZeroPadsPageNumbers() {
        let page = NotebookPage(index: 8, createdAt: Date())
        let text = PDFExporter.captionText(page: page, totalPages: 12, ownerName: "Max Mustermann")
        XCTAssertTrue(text.hasSuffix("009/012%"))
    }

    func testCaptionLeftTextIsJustTheNotebookNumber() {
        XCTAssertEqual(PDFExporter.captionLeftText(notebookNumber: 1), "#1")
        XCTAssertEqual(PDFExporter.captionLeftText(notebookNumber: 12), "#12")
    }
}
