import SwiftUI

/// SwiftUI bridge to PagerViewController. `updateUIViewController` is
/// intentionally a no-op — pages are mutated in place inside `store`, and
/// PagerViewController's own child view controllers already hold live
/// references to them, so there's nothing to push through on re-render.
struct PagerView: UIViewControllerRepresentable {
    let store: NotebookStore

    func makeUIViewController(context: Context) -> PagerViewController {
        PagerViewController(store: store)
    }

    func updateUIViewController(_ uiViewController: PagerViewController, context: Context) {}
}
