import UIKit
import SwiftUI
import PencilKit

/// Hosts one HundredPCanvasView, full-bleed (ignores safe area — "das Format
/// ist immer so groß wie das iPad selbst").
final class CanvasPageViewController: UIViewController {
    let page: NotebookPage
    let canvasView: HundredPCanvasView
    private weak var store: NotebookStore?

    // Live on-screen mirror of the PDF's caption line (see
    // PDFExporter.captionLeftText(notebookNumber:) / .captionText, the same formatting
    // functions the PDF export uses). Plain UILabels, not part of
    // HundredPCanvasView, and never interactive — this repeats the
    // hit-testing lesson from PagerViewController's hot-zone bug earlier:
    // an overlay that isn't purely visual can silently steal touches from
    // the canvas underneath. `isUserInteractionEnabled = false` (UILabel's
    // default, but set explicitly here since getting it wrong would be a
    // "why can't I draw at the bottom of the page" bug) keeps these purely
    // decorative.
    private let creditLeftLabel = UILabel()
    private let creditRightLabel = UILabel()
    private static let creditBottomInset: CGFloat = 16
    private static let creditSideInset: CGFloat = 12

    // Full-page black flash, the only feedback (besides the haptic) that a
    // long-press copy just succeeded. Added last so it sits on top of the
    // canvas and the credit line; `isUserInteractionEnabled = false` so it
    // never blocks input even while flashing.
    private let copyFlashView = UIView()

    init(page: NotebookPage, store: NotebookStore) {
        self.page = page
        self.store = store
        self.canvasView = HundredPCanvasView(frame: .zero)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        canvasView.frame = view.bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.drawing = page.drawing
        canvasView.delegate = self
        view.addSubview(canvasView)

        configureCreditLabel(creditLeftLabel, alignment: .left)
        configureCreditLabel(creditRightLabel, alignment: .right)
        creditLeftLabel.text = PDFExporter.captionLeftText(notebookNumber: store?.notebookNumber ?? 1)
        creditRightLabel.text = PDFExporter.captionText(
            page: page,
            totalPages: store?.pageCount ?? (page.index + 1),
            ownerName: AppSettings.shared.ownerName ?? ""
        )
        view.addSubview(creditLeftLabel)
        view.addSubview(creditRightLabel)
        [creditLeftLabel, creditRightLabel].forEach { $0.sizeToFit() }
        layoutCreditLabels()

        copyFlashView.backgroundColor = .black
        copyFlashView.alpha = 0
        copyFlashView.isUserInteractionEnabled = false
        copyFlashView.frame = view.bounds
        copyFlashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(copyFlashView)

        setupCopyGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCreditLabels()
    }

    private func configureCreditLabel(_ label: UILabel, alignment: NSTextAlignment) {
        label.font = UIFont(name: "Menlo", size: PDFExporter.liveCaptionFontSize)
            ?? UIFont(name: "Courier", size: PDFExporter.liveCaptionFontSize)
            ?? UIFont.systemFont(ofSize: PDFExporter.liveCaptionFontSize)
        label.textColor = .black
        label.textAlignment = alignment
        label.isUserInteractionEnabled = false
        label.backgroundColor = .clear
    }

    private func layoutCreditLabels() {
        let y = view.bounds.height - Self.creditBottomInset - creditLeftLabel.bounds.height
        creditLeftLabel.frame.origin = CGPoint(x: Self.creditSideInset, y: y)
        creditRightLabel.frame.origin = CGPoint(
            x: view.bounds.width - Self.creditSideInset - creditRightLabel.bounds.width,
            y: y
        )
    }

    // MARK: - Long-press-and-hold with a finger → copy the page as PNG

    // Finger-only (`.direct`), same reasoning as everywhere else touch type
    // is restricted in this app: the Pencil is exclusively for drawing, and
    // HundredPCanvasView's `drawingPolicy = .pencilOnly` already ignores finger
    // touches for ink — so a stationary finger hold is otherwise unused and
    // safe to claim here. A real page-turn/add-page swipe requires actual
    // horizontal movement (see PagerViewController), which fails this
    // recognizer's (default ~10pt) movement tolerance, so the two never
    // fight over the same touch.
    private func setupCopyGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCopyLongPress(_:)))
        longPress.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        longPress.minimumPressDuration = 0.6
        view.addGestureRecognizer(longPress)
    }

    @objc private func handleCopyLongPress(_ gesture: UILongPressGestureRecognizer) {
        // `.began` fires exactly once when the hold duration is reached —
        // `.changed`/`.ended` would otherwise re-copy on every finger
        // wiggle or on release.
        guard gesture.state == .began else { return }

        UIPasteboard.general.image = renderPageImageWithTransparentBackground()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flashCopyFeedback()
    }

    /// Renders the whole page view — canvas *and* the credit line below it —
    /// exactly as currently on screen, except with the white "paper"
    /// swapped out for transparency: useful for pasting the page over
    /// something else instead of always carrying its own white square.
    /// (The raw `PKDrawing` alone won't do — that has no credit line, since
    /// the labels aren't part of the drawing itself.)
    ///
    /// Backgrounds are flipped to `.clear` only for the instant of this
    /// synchronous render and restored immediately after — no run-loop turn
    /// happens in between, so the on-screen page never actually flashes
    /// transparent.
    private func renderPageImageWithTransparentBackground() -> UIImage {
        let previousViewBackground = view.backgroundColor
        let previousCanvasBackground = canvasView.backgroundColor
        let previousCanvasOpaque = canvasView.isOpaque
        view.backgroundColor = .clear
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }

        view.backgroundColor = previousViewBackground
        canvasView.backgroundColor = previousCanvasBackground
        canvasView.isOpaque = previousCanvasOpaque

        return image
    }

    /// Snap to black, hold for an instant, fade back out — a camera-shutter
    /// style flash confirming the copy landed. Done *after* the pasteboard
    /// image was already rendered above, so the flash itself never ends up
    /// in the copied PNG.
    private func flashCopyFeedback() {
        copyFlashView.layer.removeAllAnimations()
        copyFlashView.alpha = 1
        UIView.animate(
            withDuration: 0.2,
            delay: 0.05,
            options: [.curveEaseOut],
            animations: { self.copyFlashView.alpha = 0 }
        )
    }
}

extension CanvasPageViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        page.drawing = canvasView.drawing
        store?.drawingDidChange(for: page)
    }
}

/// Wraps UIPageViewController for horizontal paging. Deliberately NOT
/// SwiftUI's `TabView(.page)`: we need direct access to the internal
/// UIScrollView's pan gesture to restrict page-turning to finger touches
/// only (`allowedTouchTypes = [.direct]`), so the Apple Pencil — which
/// draws via `drawingPolicy = .pencilOnly` on the canvas — never
/// accidentally turns a page, and a finger swipe never draws.
final class PagerViewController: UIPageViewController {
    private let store: NotebookStore
    private var addPageGesture: UIPanGestureRecognizer?
    private var addPageTimer: Timer?
    private let addPageHoldDuration: TimeInterval = 0.45
    private let addPageThreshold: CGFloat = -80
    // True from the moment the reset dialog is requested until it was
    // answered (and, for "Reset", the new notebook is on screen). The finger
    // that triggered it is usually still down and keeps sending pan updates,
    // which would otherwise re-arm the hold timer and stack a second dialog.
    private var isPresentingResetDialog = false

    init(store: NotebookStore) {
        self.store = store
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        view.backgroundColor = .white

        restrictInternalScrollGestureToFingerOnly()

        if let firstPage = store.page(at: store.currentIndex) {
            setViewControllers([makeViewController(for: firstPage)], direction: .forward, animated: false)
        }

        setupHotZoneIfNeeded()
    }

    private func restrictInternalScrollGestureToFingerOnly() {
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            }
        }
    }

    /// Force-ends the internal page-turn scrollView's still-active pan
    /// gesture. See the comment in `commitAddPage()` for why this is
    /// needed. Disabling then re-enabling a `UIGestureRecognizer` is the
    /// standard trick for cancelling its current touch tracking outright.
    private func cancelInternalPageTurnGesture() {
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.panGestureRecognizer.isEnabled = false
                scrollView.panGestureRecognizer.isEnabled = true
            }
        }
    }

    private func makeViewController(for page: NotebookPage) -> CanvasPageViewController {
        CanvasPageViewController(page: page, store: store)
    }

    // MARK: - "Swipe left and hold at the last page" → add a new page
    //
    // Modeled after GoodNotes: the touch surface for this gesture is the
    // *whole* page, same as an ordinary page-turn attempt — there's no
    // separate edge zone to find. On the last page a normal-length left
    // swipe just has nowhere to go (there's no next page). Pushing the
    // swipe further than that and holding is what confirms "yes, I actually
    // want a new page", not a stray reach for the next one.
    //
    // This gesture recognizer is attached directly to `view` — deliberately
    // *not* a separate full-screen overlay `UIView`. A same-size overlay
    // would sit on top in the hit-test hierarchy and swallow every touch
    // before it reaches the canvas or the internal page-turn scroll view
    // underneath (tried that: broke both drawing and page-turning at once).
    // Attaching the recognizer straight to the ancestor view lets it watch
    // the same touches the views below it already receive, without
    // intercepting them — that's what `shouldRecognizeSimultaneously`
    // below is for.
    //
    // `view.backgroundColor` is what shows through during the rubber-band
    // overscroll when there's nowhere left to page to — on a white page
    // against a white background that's invisible, so there was no way to
    // *feel* "this is the last page" while swiping. Black only while on
    // the last page makes that edge legible; it naturally follows along to
    // whatever page is current-last after `commitAddPage()` re-triggers
    // this same setup call.
    private func setupHotZoneIfNeeded() {
        if let existing = addPageGesture {
            view.removeGestureRecognizer(existing)
            addPageGesture = nil
        }
        view.backgroundColor = store.isOnLastPage ? .black : .white
        // On the last page the gesture is offered even when the notebook is
        // full: on page 100 it opens the reset dialog instead of adding a
        // page. See DeviceScale.maxPagesPerNotebook.
        guard store.isOnLastPage else { return }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleHotZonePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pan.delegate = self
        view.addGestureRecognizer(pan)
        addPageGesture = pan
    }

    @objc private func handleHotZonePan(_ gesture: UIPanGestureRecognizer) {
        guard !isPresentingResetDialog else { return }
        let translationX = gesture.translation(in: view).x

        switch gesture.state {
        case .changed:
            if translationX <= addPageThreshold, addPageTimer == nil {
                // Built with `.scheduledTimer` + a plain `Timer` reference,
                // this would never fire while the finger is held down:
                // active touch tracking runs the run loop in `.tracking`
                // mode, and a timer scheduled that way only lives in
                // `.default` mode. Registering it for `.common` modes makes
                // it fire during the hold, not just after release.
                let timer = Timer(timeInterval: addPageHoldDuration, repeats: false) { [weak self] _ in
                    self?.commitAddPage()
                }
                RunLoop.current.add(timer, forMode: .common)
                addPageTimer = timer
            } else if translationX > addPageThreshold {
                cancelAddPageTimer()
            }
        case .ended, .cancelled, .failed:
            cancelAddPageTimer()
        default:
            break
        }
    }

    private func cancelAddPageTimer() {
        addPageTimer?.invalidate()
        addPageTimer = nil
    }

    private func commitAddPage() {
        cancelAddPageTimer()
        // Fires while the finger is still down (that's the whole point of
        // "hold"), which means UIPageViewController's own internal
        // scrollView is still mid-interactive-pan when we get here. Calling
        // `setViewControllers` while that's still in progress is a known
        // UIPageViewController trap — it silently does nothing, since the
        // internal transition coordinator is still owned by the live
        // gesture. Toggling the internal pan gesture off/on force-cancels
        // its tracking (a standard way to end an active UIKit gesture
        // programmatically), freeing the coordinator up before we call
        // setViewControllers below.
        cancelInternalPageTurnGesture()
        guard store.canAddPage else {
            presentResetDialog()
            return
        }
        guard let newPage = store.addPage() else { return }
        store.setCurrentIndex(newPage.index)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        setViewControllers([makeViewController(for: newPage)], direction: .forward, animated: true) { [weak self] _ in
            self?.setupHotZoneIfNeeded()
        }
    }

    // MARK: - Notebook full (page 101 requested) → reset dialog

    private func presentResetDialog() {
        guard !isPresentingResetDialog else { return }
        isPresentingResetDialog = true
        // Also end our own pan, not just the internal page-turn one — same
        // disable/enable trick as `cancelInternalPageTurnGesture()`.
        addPageGesture?.isEnabled = false
        addPageGesture?.isEnabled = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let dialog = ResetDialogView(
            currentNumber: store.notebookNumber,
            onCancel: { [weak self] in
                self?.dismiss(animated: true) { self?.isPresentingResetDialog = false }
            },
            onReset: { [weak self] in
                self?.dismiss(animated: true) { self?.performReset() }
            }
        )
        let host = UIHostingController(rootView: dialog)
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.view.backgroundColor = .clear
        present(host, animated: true)
    }

    private func performReset() {
        defer { isPresentingResetDialog = false }
        guard let firstPage = store.startNewNotebook() else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        setViewControllers([makeViewController(for: firstPage)], direction: .reverse, animated: false)
        setupHotZoneIfNeeded()
    }
}

extension PagerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? CanvasPageViewController else { return nil }
        guard let previousPage = store.page(at: current.page.index - 1) else { return nil }
        return makeViewController(for: previousPage)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? CanvasPageViewController else { return nil }
        guard let nextPage = store.page(at: current.page.index + 1) else { return nil }
        return makeViewController(for: nextPage)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed, let current = pageViewController.viewControllers?.first as? CanvasPageViewController else { return }
        store.setCurrentIndex(current.page.index)
        setupHotZoneIfNeeded()
    }
}

extension PagerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
