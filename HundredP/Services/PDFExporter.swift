import Foundation
import CoreGraphics
import UIKit
import PencilKit

/// Builds one notebook's 100P-<n>.pdf: one A4 page per notebook page, each showing
/// a true-to-scale hairline outline of the iPad screen, the page's drawing
/// rendered as vector paths (not a raster image — real print quality at any
/// zoom), and a monospace caption line.
///
/// If the vector reconstruction of strokes ever looks visually wrong versus
/// what's on-screen (e.g. because PencilKit's real rendering diverges from
/// a naive polyline-through-points), the documented fallback is to rasterize
/// instead via `PKDrawing.image(from:scale:)` at scale 300/72 (300dpi) and
/// draw that image into `hairlineRect`. Not implemented unless needed.
enum PDFExporter {
    static let captionFontSize: CGFloat = 9
    static let lineHeight: CGFloat = 11
    static let gapBelowHairline: CGFloat = 5

    /// Font size for the same credit line shown live in the app (see
    /// `CanvasPageViewController`) — sized to visually match the iOS status
    /// bar's text (time/battery/Wi-Fi) rather than the small print-caption
    /// size above, per the user's explicit ask.
    static let liveCaptionFontSize: CGFloat = 15

    static func data(for pages: [NotebookPage], notebookNumber: Int, ownerName: String) -> Data {
        let pageRect = CGRect(origin: .zero, size: DeviceScale.a4PageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for page in pages {
                context.beginPage()
                draw(page: page, totalPages: pages.count, notebookNumber: notebookNumber, ownerName: ownerName, in: context.cgContext, pageRect: pageRect)
            }
        }
    }

    /// The hairline rectangle: the iPad screen's true physical size,
    /// centered on the A4 page. Exposed (not `private`) so
    /// `@testable import HundredP` can verify this geometry deterministically
    /// without rendering a whole PDF.
    static func hairlineRect(in pageRect: CGRect) -> CGRect {
        let scale = CGFloat(DeviceScale.deviceToPDFPointScale)
        let deviceSize = DeviceScale.referenceScreenSize
        let hairlineSize = CGSize(width: deviceSize.width * scale, height: deviceSize.height * scale)
        let origin = CGPoint(
            x: (pageRect.width - hairlineSize.width) / 2,
            y: (pageRect.height - hairlineSize.height) / 2
        )
        return CGRect(origin: origin, size: hairlineSize)
    }

    private static func draw(page: NotebookPage, totalPages: Int, notebookNumber: Int, ownerName: String, in ctx: CGContext, pageRect: CGRect) {
        let hairlineRect = hairlineRect(in: pageRect)
        let scale = CGFloat(DeviceScale.deviceToPDFPointScale)

        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(0.5)
        ctx.stroke(hairlineRect)

        drawStrokes(page.drawing, in: ctx, origin: hairlineRect.origin, scale: scale)
        drawCaption(page: page, totalPages: totalPages, notebookNumber: notebookNumber, ownerName: ownerName, below: hairlineRect, in: ctx)
    }

    /// Draws every stroke as a vector CGPath through its sampled points,
    /// scaled into the hairline rect. `stroke.transform` must be applied to
    /// each point — `PKStroke.path` holds points *before* that transform.
    private static func drawStrokes(_ drawing: PKDrawing, in ctx: CGContext, origin: CGPoint, scale: CGFloat) {
        guard !drawing.strokes.isEmpty else { return }

        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: scale, y: scale)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(UIColor.black.cgColor)
        // Width is set once here, in device points, *inside* the scaled
        // context — CoreGraphics scales the stroke width along with the
        // geometry, exactly the physical-scale behavior we want.
        ctx.setLineWidth(DeviceScale.finelinerWidthDevicePoints)

        for stroke in drawing.strokes {
            let path = CGMutablePath()
            var isFirst = true
            for point in stroke.path {
                let location = point.location.applying(stroke.transform)
                if isFirst {
                    path.move(to: location)
                    isFirst = false
                } else {
                    path.addLine(to: location)
                }
            }
            ctx.addPath(path)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private static func drawCaption(page: NotebookPage, totalPages: Int, notebookNumber: Int, ownerName: String, below hairlineRect: CGRect, in ctx: CGContext) {
        let font = UIFont(name: "Menlo", size: captionFontSize)
            ?? UIFont(name: "Courier", size: captionFontSize)
            ?? UIFont.systemFont(ofSize: captionFontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let leftText = captionLeftText(notebookNumber: notebookNumber)
        (leftText as NSString).draw(at: CGPoint(x: hairlineRect.minX, y: hairlineRect.maxY + gapBelowHairline), withAttributes: attributes)

        let rightText = captionText(page: page, totalPages: totalPages, ownerName: ownerName)
        let rightSize = (rightText as NSString).size(withAttributes: attributes)
        (rightText as NSString).draw(
            at: CGPoint(x: hairlineRect.maxX - rightSize.width, y: hairlineRect.maxY + gapBelowHairline),
            withAttributes: attributes
        )
    }

    /// Left column of the caption/credit line: "#1" in the first PDF, "#2" in
    /// the second, etc.
    /// Shared between the PDF export and the live on-screen credit line
    /// (see `CanvasPageViewController`) so both read one formatting source.
    static func captionLeftText(notebookNumber: Int) -> String {
        "#\(notebookNumber)"
    }

    /// Right column of the caption/credit line, e.g.
    /// "Max Mustermann  20260827 17:40  001/010%". `ownerName` is set once on
    /// 100P's first-setup screen (see `FolderPickerView`) — an empty name
    /// (shouldn't normally happen, the setup screen requires one) just
    /// leaves that part blank rather than producing a doubled leading
    /// space. Shared with the live on-screen credit line, same reasoning as
    /// `captionLeftText` above.
    static func captionText(page: NotebookPage, totalPages: Int, ownerName: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd HH:mm"
        let timestamp = formatter.string(from: page.createdAt)
        let pageNumber = String(format: "%03d/%03d%%", page.index + 1, totalPages)
        let trimmedName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "\(timestamp)  \(pageNumber)" }
        return "\(trimmedName)  \(timestamp)  \(pageNumber)"
    }
}
