import Foundation

/// Migrador entre versiones del formato de proyecto.
///
/// `ProjectSnapshot` (schema v1) tenía campos rígidos por instrumento y una
/// cadena fija synth → mixer → delay → reverb → output. `ProjectGraph` (v2) es
/// dinámico (lista de nodos + conexiones). El migrador reproduce la cadena v1
/// como nodos+conexiones explícitas.
public enum ProjectMigrator {
    /// Convierte un snapshot v1 a un `ProjectGraph` v2 equivalente.
    /// - Cada track sin `instrumentRef` se enruta al synth migrado.
    /// - El output node es el reverb (final de la cadena v1).
    public static func migrateV1ToV2(_ v1: ProjectSnapshot) -> ProjectGraph {
        let synthRef = UUID()
        let mixerRef = UUID()
        let delayRef = UUID()
        let reverbRef = UUID()

        let nodes = [
            makeSynthNode(ref: synthRef, settings: v1.synth),
            makeMixerNode(ref: mixerRef, channels: v1.mixerChannels),
            makeDelayNode(ref: delayRef, settings: v1.delay),
            makeReverbNode(ref: reverbRef, settings: v1.reverb),
        ]
        let connections = makeConnections(synth: synthRef, mixer: mixerRef, delay: delayRef, reverb: reverbRef)
        let migratedTracks = routeTracks(v1.tracks, toSynth: synthRef)

        return ProjectGraph(
            schemaVersion: ProjectGraph.currentSchemaVersion,
            name: v1.name,
            author: v1.author,
            tempoBpm: v1.tempoBpm,
            nodes: nodes,
            connections: connections,
            outputNodeRef: reverbRef,
            tracks: migratedTracks
        )
    }

    private static func makeSynthNode(ref: UUID, settings: SynthSettings) -> NodeInstance {
        NodeInstance(
            id: ref,
            typeId: "additive_synth",
            displayName: "Synth",
            parameters: [
                "volume": settings.volume,
                "attack": settings.attack,
                "decay": settings.decay,
                "sustain": settings.sustain,
                "release": settings.release,
                "tilt": settings.tilt,
            ]
        )
    }

    private static func makeMixerNode(ref: UUID, channels: [MixerChannelSettings]) -> NodeInstance {
        NodeInstance(
            id: ref,
            typeId: "mixer",
            displayName: "Mixer",
            parameters: mixerParameters(from: channels)
        )
    }

    private static func makeDelayNode(ref: UUID, settings: DelaySettings) -> NodeInstance {
        NodeInstance(
            id: ref,
            typeId: "delay",
            displayName: "Delay",
            parameters: [
                "time": settings.timeSeconds,
                "feedback": settings.feedback,
                "wet": settings.wet,
            ]
        )
    }

    private static func makeReverbNode(ref: UUID, settings: ReverbSettings) -> NodeInstance {
        NodeInstance(
            id: ref,
            typeId: "reverb",
            displayName: "Reverb",
            parameters: [
                "room_size": settings.roomSize,
                "damping": settings.damping,
                "wet": settings.wet,
            ]
        )
    }

    private static func makeConnections(
        synth: UUID, mixer: UUID, delay: UUID, reverb: UUID
    ) -> [ConnectionDescriptor] {
        [
            .init(src: synth, srcPort: 0, dst: mixer, dstPort: 0),
            .init(src: synth, srcPort: 1, dst: mixer, dstPort: 1),
            .init(src: mixer, srcPort: 0, dst: delay, dstPort: 0),
            .init(src: mixer, srcPort: 1, dst: delay, dstPort: 1),
            .init(src: delay, srcPort: 0, dst: reverb, dstPort: 0),
            .init(src: delay, srcPort: 1, dst: reverb, dstPort: 1),
        ]
    }

    private static func routeTracks(_ tracks: [Track], toSynth synthRef: UUID) -> [Track] {
        var result = tracks
        for index in result.indices where result[index].instrumentRef == nil {
            result[index].instrumentRef = synthRef
        }
        return result
    }

    private static func mixerParameters(from channels: [MixerChannelSettings]) -> [String: Float] {
        var params: [String: Float] = [:]
        for (index, channel) in channels.enumerated() where index < 4 {
            params["ch\(index)_gain"] = channel.gain
            params["ch\(index)_pan"] = channel.pan
            params["ch\(index)_mute"] = channel.muted ? 1 : 0
        }
        return params
    }
}
