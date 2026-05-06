@testable import ChipsUIKit
import UIKit
import XCTest

final class ChipsUIKitTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsUIKit.version.isEmpty)
    }

    @MainActor
    func testButtonConstructs() {
        let button = ChipsButton()
        button.title = "ok"
        XCTAssertNotNil(button)
        XCTAssertGreaterThan(button.intrinsicContentSize.width, 0)
    }

    @MainActor
    func testKnobValueClampsToRange() {
        let knob = ChipsKnob()
        knob.minValue = 0
        knob.maxValue = 1
        knob.value = 0.5
        XCTAssertEqual(knob.value, 0.5, accuracy: 1.0e-6)
    }

    @MainActor
    func testFaderConstructs() {
        let fader = ChipsFader()
        fader.value = 0.7
        XCTAssertEqual(fader.value, 0.7, accuracy: 1.0e-6)
    }

    @MainActor
    func testTimecodeShowsText() {
        let label = ChipsTimecodeLabel()
        label.text = "1.1.00"
        XCTAssertNotNil(label)
    }

    @MainActor
    func testTrackPaletteHasColors() {
        XCTAssertGreaterThanOrEqual(ChipsTheme.trackPalette.count, 6)
        let c0 = ChipsTheme.trackColor(at: 0)
        let cWrapped = ChipsTheme.trackColor(at: ChipsTheme.trackPalette.count)
        XCTAssertEqual(c0, cWrapped)
    }
}
