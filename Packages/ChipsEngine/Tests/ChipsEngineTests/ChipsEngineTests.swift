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

    func testAdditiveSynthSilentByDefault() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth) else {
            XCTFail("addNode")
            return
        }
        engine.setOutputNode(synth)
        XCTAssertTrue(engine.compile())
        engine.setParameter(synth, additive: .volume, value: 0.5)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        engine.render(into: buffer, frames: frames)
        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        XCTAssertEqual((sumSquares / Double(frames * 2)).squareRoot(), 0.0, accuracy: 1.0e-5)
    }

    func testAdditiveSynthProducesSoundAfterNoteOn() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth) else {
            XCTFail("addNode")
            return
        }
        engine.setOutputNode(synth)
        XCTAssertTrue(engine.compile())
        engine.setParameter(synth, additive: .volume, value: 0.8)
        engine.setParameter(synth, additive: .attack, value: 0.001)
        engine.setParameter(synth, additive: .sustain, value: 1.0)
        engine.setParameter(synth, additive: .tilt, value: 0.5)
        XCTAssertTrue(engine.sendNoteOn(synth, midi: 69, velocity: 1.0))

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        // Renderizamos varios bloques para que el envelope llegue a sustain.
        for _ in 0 ..< 4 {
            engine.render(into: buffer, frames: frames)
        }
        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        let rms = (sumSquares / Double(frames * 2)).squareRoot()
        XCTAssertGreaterThan(rms, 0.05)
    }

    func testAdditiveSynthSilentAfterNoteOffAndRelease() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth) else {
            XCTFail("addNode")
            return
        }
        engine.setOutputNode(synth)
        XCTAssertTrue(engine.compile())
        engine.setParameter(synth, additive: .volume, value: 0.8)
        engine.setParameter(synth, additive: .attack, value: 0.001)
        engine.setParameter(synth, additive: .release, value: 0.01)
        engine.setParameter(synth, additive: .sustain, value: 1.0)

        engine.sendNoteOn(synth, midi: 69, velocity: 1.0)
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        for _ in 0 ..< 4 {
            engine.render(into: buffer, frames: frames)
        }
        engine.sendNoteOff(synth, midi: 69)
        // Release de 10 ms = 480 samples; renderizar 4096 frames es más que suficiente.
        for _ in 0 ..< 16 {
            engine.render(into: buffer, frames: frames)
        }
        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        let rms = (sumSquares / Double(frames * 2)).squareRoot()
        XCTAssertLessThan(rms, 0.001)
    }

    func testMixerPassesAudioWithGain() throws {
        // sine -> mixer ch0 -> output. Verifica que mixer enruta y aplica gain.
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let sine = engine.addNode(.sine), let mixer = engine.addNode(.mixer) else {
            XCTFail("addNode")
            return
        }
        engine.connect(sine, port: 0, to: mixer, port: 0)
        engine.connect(sine, port: 1, to: mixer, port: 1)
        engine.setOutputNode(mixer)
        XCTAssertTrue(engine.compile())
        engine.setParameter(sine, sine: .frequency, value: 440)
        engine.setParameter(sine, sine: .amplitude, value: 0.25)
        engine.setParameter(sine, sine: .enabled, value: 1.0)
        engine.setMixerParameter(mixer, channel: 0, kind: .gain, value: 1.0)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        engine.render(into: buffer, frames: frames)

        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        XCTAssertGreaterThan((sumSquares / Double(frames * 2)).squareRoot(), 0.05)
    }

    func testMutedMixerChannelProducesSilence() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let sine = engine.addNode(.sine), let mixer = engine.addNode(.mixer) else {
            XCTFail("addNode")
            return
        }
        engine.connect(sine, port: 0, to: mixer, port: 0)
        engine.connect(sine, port: 1, to: mixer, port: 1)
        engine.setOutputNode(mixer)
        XCTAssertTrue(engine.compile())
        engine.setParameter(sine, sine: .frequency, value: 440)
        engine.setParameter(sine, sine: .amplitude, value: 0.25)
        engine.setParameter(sine, sine: .enabled, value: 1.0)
        engine.setMixerParameter(mixer, channel: 0, kind: .mute, value: 1.0)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        engine.render(into: buffer, frames: frames)
        for i in 0 ..< frames * 2 {
            XCTAssertEqual(buffer[i], 0.0, accuracy: 1.0e-5)
        }
    }

    func testFullSynthChainProducesAudio() throws {
        // synth -> mixer -> delay -> reverb -> output. Sanity end-to-end.
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth),
              let mixer = engine.addNode(.mixer),
              let delay = engine.addNode(.delay),
              let reverb = engine.addNode(.reverb)
        else {
            XCTFail("addNode")
            return
        }
        engine.connect(synth, port: 0, to: mixer, port: 0)
        engine.connect(synth, port: 1, to: mixer, port: 1)
        engine.connect(mixer, port: 0, to: delay, port: 0)
        engine.connect(mixer, port: 1, to: delay, port: 1)
        engine.connect(delay, port: 0, to: reverb, port: 0)
        engine.connect(delay, port: 1, to: reverb, port: 1)
        engine.setOutputNode(reverb)
        XCTAssertTrue(engine.compile())
        engine.setParameter(synth, additive: .volume, value: 0.8)
        engine.setParameter(synth, additive: .attack, value: 0.001)
        engine.setParameter(synth, additive: .sustain, value: 1.0)
        engine.setMixerParameter(mixer, channel: 0, kind: .gain, value: 1.0)
        engine.sendNoteOn(synth, midi: 60, velocity: 1.0)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        for _ in 0 ..< 8 {
            engine.render(into: buffer, frames: frames)
        }
        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        XCTAssertGreaterThan((sumSquares / Double(frames * 2)).squareRoot(), 0.01)
    }

    func testRegistryListsAllBuiltinTypes() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        let types = Set(engine.registeredTypes)
        XCTAssertTrue(types.contains("sine"))
        XCTAssertTrue(types.contains("passthrough"))
        XCTAssertTrue(types.contains("test_source"))
        XCTAssertTrue(types.contains("additive_synth"))
        XCTAssertTrue(types.contains("subtractive_synth"))
        XCTAssertTrue(types.contains("mixer"))
        XCTAssertTrue(types.contains("delay"))
        XCTAssertTrue(types.contains("reverb"))
    }

    func testSubtractiveSynthAutoRegisters() throws {
        // Plug-and-play: añadir un synth sin tocar coordinator/snapshot/UI core.
        // Aquí solo verificamos que el módulo se auto-registra y expone los
        // parámetros que la UI genérica espera.
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(typeId: "subtractive_synth") else {
            XCTFail("addNode subtractive_synth")
            return
        }
        XCTAssertEqual(engine.nodeTypeId(synth), "subtractive_synth")
        XCTAssertEqual(engine.parameterCount(of: synth), 7)
        let names = engine.parameterSpecs(of: synth).map(\.name)
        XCTAssertEqual(Set(names), ["volume", "cutoff", "resonance", "attack", "decay", "sustain", "release"])
    }

    func testSubtractiveSynthRendersAfterNoteOn() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(typeId: "subtractive_synth") else {
            XCTFail("addNode")
            return
        }
        engine.setOutputNode(synth)
        XCTAssertTrue(engine.compile())
        XCTAssertTrue(engine.sendNoteOn(synth, midi: 60, velocity: 1.0))

        let totalFrames = frames * 4
        var buffer = [Float](repeating: 0, count: totalFrames * 2)
        buffer.withUnsafeMutableBufferPointer { ptr in
            engine.render(into: ptr.baseAddress!, frames: totalFrames)
        }
        var sumSquares: Double = 0
        for i in 0 ..< (totalFrames * 2) {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        let rms = (sumSquares / Double(totalFrames * 2)).squareRoot()
        XCTAssertGreaterThan(rms, 0.01, "RMS=\(rms) — el synth no produjo audio audible tras note on")
    }

    func testNodeTypeIdMatchesRegistered() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth) else {
            XCTFail("addNode")
            return
        }
        XCTAssertEqual(engine.nodeTypeId(synth), "additive_synth")
        XCTAssertNil(engine.nodeTypeId(99999))
    }

    func testAdditiveSynthExposesSixParameters() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let synth = engine.addNode(.additiveSynth) else {
            XCTFail("addNode")
            return
        }
        XCTAssertEqual(engine.parameterCount(of: synth), 6)
        let specs = engine.parameterSpecs(of: synth)
        let names = Set(specs.map(\.name))
        XCTAssertEqual(names, ["volume", "attack", "decay", "sustain", "release", "tilt"])
        if let attack = specs.first(where: { $0.name == "attack" }) {
            XCTAssertEqual(attack.unit, "s")
            XCTAssertGreaterThan(attack.maxValue, attack.minValue)
            XCTAssertEqual(attack.paramId, AdditiveSynthParam.attack.rawValue)
        } else {
            XCTFail("attack spec missing")
        }
    }

    func testPassthroughExposesNoParameters() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let pt = engine.addNode(.passthrough) else {
            XCTFail("addNode")
            return
        }
        XCTAssertEqual(engine.parameterCount(of: pt), 0)
        XCTAssertNil(engine.parameterSpec(of: pt, at: 0))
    }

    func testMixerDefaultExposesEightChannels() throws {
        // R4: MixerModule paramétrico. Default factory crea con 8 canales.
        // 8 ch × 3 params (gain/pan/mute) = 24 specs.
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        guard let mixer = engine.addNode(.mixer) else {
            XCTFail("addNode")
            return
        }
        XCTAssertEqual(engine.parameterCount(of: mixer), 24)
        let specs = engine.parameterSpecs(of: mixer)
        XCTAssertEqual(specs.count, 24)
        XCTAssertTrue(specs.contains { $0.name == "ch0_gain" })
        XCTAssertTrue(specs.contains { $0.name == "ch7_mute" })
        XCTAssertFalse(specs.contains { $0.name == "ch8_gain" })
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
