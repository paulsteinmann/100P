import Foundation
import CoreGraphics

/// All physical-scale math lives here, and only here.
///
/// 100P's whole point is that the exported PDF is a *true-to-life* 1:1 print
/// template of the iPad screen. To do that we need to know the iPad's real
/// physical screen size in millimeters — Apple's UIKit "points" are logical
/// units, not physical ones, and vary in physical size from device to device.
///
/// Target device: iPad Pro 12.9" (3rd generation).
/// Logical portrait screen size: 1024 x 1366 pt — NOT the "classic" iPad
/// point space (768x1024, used by iPad/iPad Air/iPad mini). The 12.9" Pro
/// family has always had its own, larger point space. (Caught by actually
/// booting the exact device-type simulator and comparing the screenshot's
/// pixel size, 2048x2732 @2x, against this file's old — wrong — assumption.)
/// Physical active display area (from Apple's published tech specs, native
/// resolution 2732x2048 px @ 264 ppi): 2732/264 in = 10.348 in = 262.8 mm
/// (landscape long side), 2048/264 in = 7.758 in = 197.05 mm (short side).
/// In portrait: width = 197.05 mm, height = 262.8 mm.
///
/// If 100P is ever ported to a different iPad model, these are the ONLY
/// numbers that need to change (look up the new device's native resolution,
/// ppi, and *logical point size* from Apple's tech specs page — don't just
/// assume the classic 768x1024 point space, verify it, as this file's first
/// draft did not).
enum DeviceScale {

    /// Physical width of the device's screen in portrait orientation, in mm.
    static let screenWidthMM: Double = 197.05

    /// Physical height of the device's screen in portrait orientation, in mm.
    static let screenHeightMM: Double = 262.8

    /// The logical (point-based) portrait screen size this physical size
    /// corresponds to, per Apple's tech specs for this exact model.
    static let referenceScreenSize = CGSize(width: 1024, height: 1366)

    /// Millimeters of physical screen per one UIKit point, in this device's
    /// portrait orientation. Cross-checked: width and height must agree.
    ///   197.05 / 1024 ≈ 0.192432
    ///   262.8  / 1366 ≈ 0.192387
    /// (The tiny discrepancy is rounding in Apple's published mm figures;
    /// splitting the difference gives a single practical constant.)
    static let mmPerDevicePoint: Double = ((screenWidthMM / referenceScreenSize.width)
        + (screenHeightMM / referenceScreenSize.height)) / 2

    /// PDF/print convention: 1 inch = 72 pt, 1 inch = 25.4 mm, so
    /// 1 mm = 72/25.4 ≈ 2.83465 pt.
    static let pdfPointsPerMM: Double = 72.0 / 25.4

    /// Multiply any length in device points by this to get the physically
    /// true-to-life length in PDF points (i.e. what you'd need to draw on
    /// paper for a 1:1, life-size print).
    ///   mmPerDevicePoint * pdfPointsPerMM ≈ 0.54554
    static let deviceToPDFPointScale: Double = mmPerDevicePoint * pdfPointsPerMM

    /// The fineliner the user asked to simulate is 0.3mm wide. Converting
    /// that physical width into device points gives the PencilKit ink width
    /// to use on-screen so the *drawn* line is 0.3mm wide when printed 1:1.
    ///   0.3 / mmPerDevicePoint ≈ 1.559 device points
    /// NOTE: this is a starting value. PencilKit's actual rendered stroke
    /// width can differ subtly from the raw `width` you hand it (device
    /// pixel snapping, ink smoothing). The user explicitly wants to test
    /// and retune this on the real device/Pencil — see HOME.md "Offene
    /// Punkte" before treating this as final.
    static let finelinerWidthDevicePoints: CGFloat = CGFloat(0.3 / mmPerDevicePoint)

    /// PencilKit's `.monoline` ink renders visibly thicker on-screen than
    /// the literal `width` you hand `PKInkingTool` (device pixel snapping,
    /// ink smoothing/anti-aliasing) — confirmed on real hardware: the live
    /// stroke looked thicker than the same-width vector line in the PDF
    /// export, which paints at the literal width with no such softening.
    /// This is a separate, empirical correction for the *live tool* only;
    /// the PDF keeps using `finelinerWidthDevicePoints` unchanged, since
    /// that one is the physically-true 0.3mm reference. Started at -30%;
    /// retune further by eye on-device if still off.
    static let liveToolWidthDevicePoints: CGFloat = finelinerWidthDevicePoints * 0.7

    /// DIN A4 page size at the standard PDF/print convention of 72 points
    /// per inch: 210mm x 297mm.
    static let a4PageSize = CGSize(
        width: 210.0 * pdfPointsPerMM,
        height: 297.0 * pdfPointsPerMM
    )

    /// One notebook (one PDF) holds at most this many pages. Trying to add
    /// page 101 opens the reset dialog instead (see `PagerViewController`):
    /// the full PDF stays in iCloud, and a new notebook with a fresh PDF
    /// (`100P-<n+1>.pdf`) starts with one blank page.
    static let maxPagesPerNotebook = 100
}
