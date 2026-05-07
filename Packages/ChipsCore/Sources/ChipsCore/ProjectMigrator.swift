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

        let synthNode = NodeInstance(
            id: synthRef,
            typeId: "additive_synth",
            displayName: "Synth",
            parameters: [
                "volume": v1.synth.volume,
                "attack": v1.synth.attack,
                "decay": v1.synth.decay,
                "sustain": v1.synth.sustain,
                "release": v1.synth.release,
                "tilt": v1.synth.tilt,
            ]
        )

        let mixerNode = NodeInstance(
            id: mixerRef,
            typeId: "mixer",
            displayName: "Mixer",
            parameters: mixerParameters(from: v1.mixerChannels)
        )

        let delayNode = NodeInstance(
            id: delayRef,
            typeId: "delay",
            displayName: "Delay",
            parameters: [
                "time": v1.delay.timeSeconds,
                "feedback": v1.delay.feedback,
                "wet": v1.delay.wet,
            ]
        )

        let reverbNode = NodeInstance(
            id: reverbRef,
            typeId: "reverb",
            displayName: "Reverb",
            parameters: [
                "room_size": v1.reverb.roomSize,
                "damping": v1.reverb.damping,
                "wet": v1.reverb.wet,
            ]
        )

        let connections: [ConnectionDescriptor] = [
            .init(src: synthRef, srcPort: 0, dst: mixerRef, dstPort: 0),
            .init(src: synthRef, srcPort: 1, dst: mixerRef, dstPort: 1),
            .init(src: mixerRef, srcPort: 0, dst: delayRef, dstPort: 0),
            .init(src: mixerRef, srcPort: 1, dst: delayRef, dstPort: 1),
            .init(src: delayRef, srcPort: 0, dst: reverbRef, dstPort: 0),
            .init(src: delayRef, srcPort: 1, dst: reverbRef, dstPort: 1),
        ]

        // Heredamos los tracks; en v1 todos tocaban al synth único.
        var migratedTracks = v1.tracks
        for index in migratedTracks.indices where migratedTracks[index].instrumentRef == nil {
            migratedTracks[index].instrumentRef = synthRef
        }

        return ProjectGraph(
            schemaVersion: ProjectGraph.currentSchemaVersion,
            name: v1.name,
            author: v1.author,
            tempoBpm: v1.tempoBpm,
            nodes: [synthNode, mixerNode, delayNode, reverbNode],
            connections: connections,
            outputNodeRef: reverbRef,
            tracks: migratedTracks
        )
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
