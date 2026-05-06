@testable import ChipsEngine
import XCTest

final class ChipsEngineTests: XCTestCase {
    private let sampleRate: Double = 48000
    private let frames = 256

    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsEngine.version.isEmpty)
    }

    func testEngineCreationFailsWithInvalidParameters() {
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 0, maxFrames: 256))
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 48000, maxFrames: 0))
    }

    func testSampleRateMatchesInit() throws {
        let engine = try ChipsEngine(sampleRate: 44100, maxFrames: 128)
        XCTAssertEqual(engine.sampleRate, 44100)
    }

    func testRenderProducesSilenceWithEmptyGraph() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        for i in 0 ..< frames * 2 {
            buffer[i] = 99.0
        }
        engine.render(into: buffer, frames: frames)
        for i in 0 ..< frames * 2 {
            XCTAssertEqual(buffer[i], 0.0)
        }
    }

    func testSineToOutputProducesNonZero() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let sine = engine.addNode(.sine) else {
            XCTFail("addNode falló")
            return
        }
        engine.setOutputNode(sine)
        XCTAssertTrue(engine.compile())
        engine.setParameter(sine, sine: .frequency, value: 440)
        engine.setParameter(sine, sine: .amplitude, value: 0.25)
        engine.setParameter(sine, sine: .enabled, value: 1.0)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        engine.render(into: buffer, frames: frames)

        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        let rms = (sumSquares / Double(frames * 2)).squareRoot()
        XCTAssertGreaterThan(rms, 0.05)
    }

    func testCompileFailsWithoutOutputNode() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        XCTAssertFalse(engine.compile())
    }

    func testCompileFailsWithCycle() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let a = engine.addNode(.passthrough), let b = engine.addNode(.passthrough) else {
            XCTFail("addNode falló")
            return
        }
        engine.connect(a, port: 0, to: b, port: 0)
        engine.connect(b, port: 0, to: a, port: 0)
        engine.setOutputNode(a)
        XCTAssertFalse(engine.compile())
    }

    func testFiftyPassthroughsInChainPreserveSource() throws {
        // test_source → PT1 → PT2 → ... → PT50 → output
        // El passthrough (stereo, 2 canales) copia entrada a salida sin retardo,
        // así que la salida del último PT debe coincidir con la del source.
        // El source es mono → debemos usar passthrough mono. Cambiamos a chain
        // mono usando test_source (mono) + passthroughs configurados implícitamente
        // como stereo (channels=2 hardcoded en M2). Para que esta cadena funcione
        // alimentamos el mismo source en ambos canales del primer PT y verificamos.
        //
        // Por simplicidad y para el intent del test, encadenamos directamente
        // sine(stereo) -> 50 passthroughs (stereo) y verificamos paridad RMS.
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let sine = engine.addNode(.sine) else {
            XCTFail("source")
            return
        }
        var prev = sine
        for _ in 0 ..< 50 {
            guard let pt = engine.addNode(.passthrough) else {
                XCTFail("passthrough add")
                return
            }
            XCTAssertTrue(engine.connect(prev, port: 0, to: pt, port: 0))
            XCTAssertTrue(engine.connect(prev, port: 1, to: pt, port: 1))
            prev = pt
        }
        engine.setOutputNode(prev)
        XCTAssertTrue(engine.compile())
        engine.setParameter(sine, sine: .frequency, value: 440)
        engine.setParameter(sine, sine: .amplitude, value: 0.25)
        engine.setParameter(sine, sine: .enabled, value: 1.0)

        let bufferChain = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { bufferChain.deallocate() }
        engine.render(into: bufferChain, frames: frames)

        // Comparar contra un engine que tiene solo sine -> output.
        let direct = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let dSine = direct.addNode(.sine) else {
            XCTFail("direct sine")
            return
        }
        direct.setOutputNode(dSine)
        XCTAssertTrue(direct.compile())
        direct.setParameter(dSine, sine: .frequency, value: 440)
        direct.setParameter(dSine, sine: .amplitude, value: 0.25)
        direct.setParameter(dSine, sine: .enabled, value: 1.0)

        let bufferDirect = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { bufferDirect.deallocate() }
        direct.render(into: bufferDirect, frames: frames)

        for i in 0 ..< frames * 2 {
            XCTAssertEqual(bufferChain[i], bufferDirect[i], accuracy: 1.0e-6)
        }
    }

    func testRemoveAndRebuildGraph() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let sine = engine.addNode(.sine) else {
            XCTFail("sine")
            return
        }
        engine.setOutputNode(sine)
        XCTAssertTrue(engine.compile())
        XCTAssertTrue(engine.removeNode(sine))
        XCTAssertFalse(engine.compile()) // ya no hay output node
    }
}
