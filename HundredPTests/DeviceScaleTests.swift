import XCTest
@testable import HundredP

final class DeviceScaleTests: XCTestCase {

    func testMMPerDevicePoint() {
        XCTAssertEqual(DeviceScale.mmPerDevicePoint, 0.1924, accuracy: 0.001)
    }

    func testDeviceToPDFPointScale() {
        XCTAssertEqual(DeviceScale.deviceToPDFPointScale, 0.54554, accuracy: 0.001)
    }

    func testFinelinerWidthIsApproximatelyOnePointFiveSix() {
        XCTAssertEqual(Double(DeviceScale.finelinerWidthDevicePoints), 1.559, accuracy: 0.01)
    }

    func testA4PageSizeInPoints() {
        XCTAssertEqual(DeviceScale.a4PageSize.width, 595.28, accuracy: 0.1)
        XCTAssertEqual(DeviceScale.a4PageSize.height, 841.89, accuracy: 0.1)
    }

    /// The whole point of these constants: a device-point rectangle scaled
    /// by deviceToPDFPointScale must fit inside an A4 page with margin to
    /// spare on this specific iPad model.
    func testScaledScreenFitsWithinA4() {
        let scale = DeviceScale.deviceToPDFPointScale
        let scaledWidth = DeviceScale.referenceScreenSize.width * scale
        let scaledHeight = DeviceScale.referenceScreenSize.height * scale
        XCTAssertLessThan(scaledWidth, DeviceScale.a4PageSize.width)
        XCTAssertLessThan(scaledHeight, DeviceScale.a4PageSize.height)
        XCTAssertEqual(scaledWidth, 558.6, accuracy: 1.0)
        XCTAssertEqual(scaledHeight, 745.0, accuracy: 1.0)
    }
}
