import Foundation
import PencilKit

/// One page of the notebook. `index` is 0-based and also determines file
/// naming/ordering; pages are never reordered or deleted, only appended.
final class NotebookPage: Identifiable, Equatable {
    let id: Int          // == index, stable identity for SwiftUI/UIKit lists
    let index: Int
    let createdAt: Date
    var drawing: PKDrawing

    init(index: Int, createdAt: Date, drawing: PKDrawing = PKDrawing()) {
        self.id = index
        self.index = index
        self.createdAt = createdAt
        self.drawing = drawing
    }

    static func == (lhs: NotebookPage, rhs: NotebookPage) -> Bool {
        lhs.index == rhs.index
    }

    /// Filename for this page's raw drawing data inside `.100p-pages-<n>/`.
    /// 1-based, zero-padded to 4 digits (matches the PDF caption's page
    /// numbering, which is also 1-based).
    var fileName: String {
        String(format: "page-%04d.drawing", index + 1)
    }
}
