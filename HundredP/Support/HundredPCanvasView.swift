import UIKit
import PencilKit

/// The one and only drawing surface. Structurally enforces every "permanent
/// ink" invariant:
///   - Pencil only (`drawingPolicy = .pencilOnly`) — finger touches never draw.
///   - Exactly one tool, set once, never a PKToolPicker.
///   - No undo/redo, via any input method.
final class HundredPCanvasView: PKCanvasView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        drawingPolicy = .pencilOnly
        backgroundColor = .white
        isOpaque = true
        // PencilKit auto-adapts ink color for dark mode (e.g. black → near-
        // white) so it stays visible against whatever background the app
        // uses. Our canvas is *always* white paper, regardless of system
        // appearance — without forcing light mode here, that adaptation
        // fights the fixed white background and the "black" ink can render
        // white-on-white, invisible while still recording real stroke data
        // (which is why it still showed up fine in the PDF export, which
        // paints strokes hard-coded black itself).
        overrideUserInterfaceStyle = .light
        // .monoline ignores pencil pressure entirely — a constant-width
        // line, matching a real fineliner far better than `.pen` (which
        // varies width with pressure). See DeviceScale.swift for the width
        // derivation.
        tool = PKInkingTool(.monoline, color: .black, width: DeviceScale.liveToolWidthDevicePoints)
        // No PKToolPicker is ever created or shown — there is structurally
        // no UI path to change tool, color, or width.

        // PencilKit ships its own finger-driven interaction for selecting
        // and moving *existing* strokes (long-press → system Edit Menu with
        // "Select All" → drag to reposition the selection) — completely
        // separate from `drawingPolicy`, which only gates *new* ink, not
        // editing what's already there. Found on-device: it was still very
        // much reachable despite pencil-only drawing. That directly
        // violates the "nothing can be moved" rule, so strip whatever
        // `UIInteraction`s PKCanvasView attached for it — plain touch/pencil
        // drawing isn't interaction-based, so this doesn't touch that.
        for interaction in interactions {
            removeInteraction(interaction)
        }
    }

    // No `undoManager` override here on purpose. An earlier version
    // returned a fresh, empty `UndoManager()` on every access to make
    // external undo/redo permanently harmless — but PencilKit relies on
    // `self.undoManager` internally to commit a stroke (roughly:
    // `beginUndoGrouping()` on touch-down, `endUndoGrouping()` on
    // touch-up). Since every access handed back a *different* instance,
    // that pairing never matched, and strokes silently failed to commit —
    // the Pencil would draw live but nothing ever landed in `drawing`.
    // `canPerformAction` below (plus `applicationSupportsShakeToEdit =
    // false` in AppDelegate) already blocks every external trigger for
    // undo/redo, so letting PKCanvasView keep its normal, stable
    // undoManager is enough to satisfy "no undo, no redo" without
    // breaking PencilKit's own use of it.
    // Blanket-deny every responder-chain action, not just undo/redo. This
    // is what actually keeps the system Edit Menu (Select All / Cut / Copy
    // / Delete / …) from ever having anything to show — both the legacy
    // UIMenuController and the newer UIEditMenuInteraction ask
    // `canPerformAction` for every candidate action before displaying
    // anything, so if nothing can perform, no menu appears. Ink is
    // permanent and never becomes a target for any post-hoc edit: no eraser,
    // no lasso, no moving.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}
