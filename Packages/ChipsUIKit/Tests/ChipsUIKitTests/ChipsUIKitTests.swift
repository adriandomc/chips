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

    // MARK: Accessibility (M11-D)

    @MainActor
    func testKnobIsAdjustableAccessibilityElement() {
        let knob = ChipsKnob()
        XCTAssertTrue(knob.isAccessibilityElement)
        XCTAssertTrue(knob.accessibilityTraits.contains(.adjustable))
    }

    @MainActor
    func testKnobAccessibilityLabelMirrorsLabel() {
        let knob = ChipsKnob()
        knob.label = "Cutoff"
        XCTAssertEqual(knob.accessibilityLabel, "Cutoff")
    }

    @MainActor
    func testKnobAccessibilityValueDefaultsToTwoDecimals() {
        let knob = ChipsKnob()
        knob.minValue = 0
        knob.maxValue = 1
        knob.value = 0.5
        XCTAssertEqual(knob.accessibilityValue, "0.50")
    }

    @MainActor
    func testKnobAccessibilityValueUsesFormatterWhenProvided() {
        let knob = ChipsKnob()
        knob.minValue = 0
        knob.maxValue = 1
        knob.value = 0.42
        knob.accessibilityValueFormatter = { value in String(format: "%.0f%%", value * 100) }
        XCTAssertEqual(knob.accessibilityValue, "42%")
    }

    @MainActor
    func testKnobIncrementMovesValueAndFiresEvent() {
        let knob = ChipsKnob()
        knob.minValue = 0
        knob.maxValue = 1
        knob.value = 0.5
        knob.accessibilityStepFraction = 0.1
        var events = 0
        knob.addAction(UIAction { _ in events += 1 }, for: .valueChanged)

        knob.accessibilityIncrement()
        XCTAssertEqual(knob.value, 0.6, accuracy: 1.0e-5)
        knob.accessibilityDecrement()
        knob.accessibilityDecrement()
        XCTAssertEqual(knob.value, 0.4, accuracy: 1.0e-5)
        XCTAssertEqual(events, 3)
    }

    @MainActor
    func testKnobIncrementClampsAtMax() {
        let knob = ChipsKnob()
        knob.minValue = 0
        knob.maxValue = 1
        knob.value = 0.98
        knob.accessibilityStepFraction = 0.1
        knob.accessibilityIncrement()
        XCTAssertEqual(knob.value, 1.0, accuracy: 1.0e-5)
    }

    @MainActor
    func testFaderIsAdjustable() {
        let fader = ChipsFader()
        XCTAssertTrue(fader.isAccessibilityElement)
        XCTAssertTrue(fader.accessibilityTraits.contains(.adjustable))
    }

    @MainActor
    func testFaderIncrementMovesValue() {
        let fader = ChipsFader()
        fader.minValue = 0
        fader.maxValue = 1
        fader.value = 0.5
        fader.accessibilityStepFraction = 0.1
        fader.accessibilityIncrement()
        XCTAssertEqual(fader.value, 0.6, accuracy: 1.0e-5)
    }

    @MainActor
    func testButtonExposesTitleAsAccessibilityLabel() {
        let button = ChipsButton()
        button.title = "save"
        XCTAssertTrue(button.isAccessibilityElement)
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertEqual(button.accessibilityLabel, "save")
    }

    @MainActor
    func testIconButtonReportsSelectedState() {
        let button = ChipsIconButton()
        button.systemImageName = "music.note.list"
        button.accessibilityLabel = "Sequencer"
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertFalse(button.accessibilityTraits.contains(.selected))
        button.isSelected = true
        XCTAssertTrue(button.accessibilityTraits.contains(.selected))
    }

    @MainActor
    func testTransportButtonHasAccessibleDefaults() {
        let play = ChipsTransportButton(kind: .play)
        XCTAssertEqual(play.accessibilityLabel, "Play")
        XCTAssertTrue(play.accessibilityTraits.contains(.button))
        let stop = ChipsTransportButton(kind: .stop)
        XCTAssertEqual(stop.accessibilityLabel, "Stop")
    }
}
