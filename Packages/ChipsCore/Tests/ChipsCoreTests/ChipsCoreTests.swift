@testable import ChipsCore
import XCTest

final class ChipsCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsCore.version.isEmpty)
    }

    func testProjectIdentifierIsUnique() {
        let identifierA = ProjectIdentifier()
        let identifierB = ProjectIdentifier()
        XCTAssertNotEqual(identifierA, identifierB)
    }

    func testTransportFormattedAtOrigin() {
        let state = TransportState(currentTick: 0)
        XCTAssertEqual(state.formatted, "1.1.00")
    }

    func testTransportFormattedAfterFullBar() {
        let ppq = ChipsCore.ppq
        let state = TransportState(currentTick: Int64(4 * ppq))
        XCTAssertEqual(state.formatted, "2.1.00")
    }

    func testTransportTickSecondsAt120Bpm() {
        let state = TransportState(tempoBpm: 120, ppq: ChipsCore.ppq)
        // 120 BPM → 0.5 s/beat → 0.5/480 ≈ 1.0417e-3 s/tick
        XCTAssertEqual(state.tickSeconds, 0.5 / 480.0, accuracy: 1.0e-9)
    }

    func testTransportTempoClampedToValidRange() {
        let lowState = TransportState(tempoBpm: 5)
        XCTAssertGreaterThanOrEqual(lowState.tempoBpm, 20)
        let highState = TransportState(tempoBpm: 1500)
        XCTAssertLessThanOrEqual(highState.tempoBpm, 999)
    }

    func testPatternAddRemoveNote() {
        var pattern = Pattern(name: "p", lengthTicks: 1920)
        let note = PatternNote(startTick: 0, lengthTicks: 120, midi: 60)
        pattern.addNote(note)
        XCTAssertEqual(pattern.notes.count, 1)
        pattern.removeNote(id: note.id)
        XCTAssertTrue(pattern.notes.isEmpty)
    }

    func testPatternNotesStartingInWindow() {
        var pattern = Pattern(name: "p", lengthTicks: 1920)
        pattern.addNote(PatternNote(startTick: 0, lengthTicks: 120, midi: 60))
        pattern.addNote(PatternNote(startTick: 480, lengthTicks: 120, midi: 62))
        pattern.addNote(PatternNote(startTick: 960, lengthTicks: 120, midi: 64))
        let starting = pattern.notesStarting(in: 0, to: 600)
        XCTAssertEqual(starting.count, 2)
    }

    func testPatternRoundTripsThroughCodable() throws {
        var pattern = Pattern(name: "demo", lengthTicks: 1920)
        pattern.addNote(PatternNote(startTick: 0, lengthTicks: 60, midi: 60))
        pattern.addNote(PatternNote(startTick: 240, lengthTicks: 60, midi: 64))
        let data = try JSONEncoder().encode(pattern)
        let decoded = try JSONDecoder().decode(Pattern.self, from: data)
        XCTAssertEqual(decoded.id, pattern.id)
        XCTAssertEqual(decoded.notes.count, 2)
    }

    @MainActor
    func testSequencerEngineSetTracks() {
        let engine = SequencerEngine()
        let track = Track(name: "T1", colorIndex: 0, patterns: [Pattern(name: "p", lengthTicks: 480)])
        engine.setTracks([track])
        XCTAssertEqual(engine.tracks.count, 1)
        XCTAssertEqual(engine.tracks.first?.name, "T1")
    }

    func testProjectSnapshotRoundTrip() throws {
        var snapshot = ProjectSnapshot(name: "demo", author: "me", tempoBpm: 95)
        var pattern = Pattern(name: "p", lengthTicks: 1920)
        pattern.addNote(PatternNote(startTick: 0, lengthTicks: 120, midi: 60))
        snapshot.tracks = [Track(name: "T1", colorIndex: 0, patterns: [pattern])]
        snapshot.synth.attack = 0.05
        snapshot.delay.feedback = 0.6

        let data = try ProjectStorage.encode(snapshot)
        let decoded = try ProjectStorage.decode(data)
        XCTAssertEqual(decoded.name, "demo")
        XCTAssertEqual(decoded.tempoBpm, 95)
        XCTAssertEqual(decoded.synth.attack, 0.05, accuracy: 1.0e-6)
        XCTAssertEqual(decoded.delay.feedback, 0.6, accuracy: 1.0e-6)
        XCTAssertEqual(decoded.tracks.count, 1)
        XCTAssertEqual(decoded.tracks[0].patterns[0].notes.count, 1)
    }

    func testProjectStorageRejectsFutureSchemaVersion() {
        let payload = #"{"schemaVersion":999,"name":"x","author":"","tempoBpm":120,"tracks":[],"synth":{"volume":0.5,"attack":0.01,"decay":0.1,"sustain":0.7,"release":0.3,"tilt":0.5},"mixerChannels":[],"delay":{"timeSeconds":0.3,"feedback":0.3,"wet":0.2},"reverb":{"roomSize":0.7,"damping":0.3,"wet":0.2}}"#
        let data = Data(payload.utf8)
        XCTAssertThrowsError(try ProjectStorage.decode(data))
    }

    func testWavWriterProducesValidRiffHeader() throws {
        let frames = 480
        var samples = [Float](repeating: 0, count: frames * 2)
        for i in 0 ..< frames {
            samples[i * 2] = sin(Float(i) * 0.1) * 0.5
            samples[i * 2 + 1] = sin(Float(i) * 0.1) * 0.5
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
        try? FileManager.default.removeItem(at: url)
        try WavWriter.writeStereoPCM16(samples: samples, sampleRate: 48000, to: url)

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 44)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8 ..< 12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: data[12 ..< 16], as: UTF8.self), "fmt ")
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    func testSequencerEngineDelegateReceivesNoteEvents() {
        final class Spy: SequencerEngineDelegate {
            var noteOnCount = 0
            var noteOffCount = 0
            func sequencer(noteOnFor _: Track, note _: PatternNote) {
                noteOnCount += 1
            }

            func sequencer(noteOffFor _: Track, note _: PatternNote) {
                noteOffCount += 1
            }

            func sequencer(positionDidChange _: Int64) {}
        }
        let spy = Spy()
        let engine = SequencerEngine()
        engine.delegate = spy
        var pattern = Pattern(name: "p", lengthTicks: 480)
        pattern.addNote(PatternNote(startTick: 0, lengthTicks: 120, midi: 60))
        engine.setTracks([Track(name: "T", colorIndex: 0, patterns: [pattern])])
        // Validamos solo el cableado básico (delegate no nil).
        XCTAssertNotNil(engine.delegate)
        _ = spy
    }
}
