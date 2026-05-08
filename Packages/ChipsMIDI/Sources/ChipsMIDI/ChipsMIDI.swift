import CoreMIDI
import Foundation

public enum ChipsMIDI {
    public static let version = "1.0.0"
}

public enum ChipsMIDIError: Error, CustomStringConvertible {
    case clientCreate(OSStatus)
    case destinationCreate(OSStatus)

    public var description: String {
        switch self {
        case .clientCreate(let status): return "MIDIClientCreate failed: \(status)"
        case .destinationCreate(let status): return "MIDIDestinationCreate failed: \(status)"
        }
    }
}

/// Wrapper de CoreMIDI que crea una virtual MIDI destination y entrega note
/// on/off + control change al consumidor. La destination es visible para
/// otras apps MIDI (BLEMIDI, Network Session, AUv3 controllers, etc.) que
/// pueden enviar eventos a Chips.
///
/// Las clausuras se invocan desde el thread interno de CoreMIDI; el consumidor
/// debe dispatcharlas al MainActor si necesita operar sobre la app.
public final class ChipsMIDIInput: @unchecked Sendable {
    /// channel (0..15), midi (0..127), velocity (0..1).
    public typealias NoteOnHandler = @Sendable (Int, Int, Float) -> Void
    /// channel, midi.
    public typealias NoteOffHandler = @Sendable (Int, Int) -> Void
    /// channel, controller (0..127), value (0..127).
    public typealias ControlChangeHandler = @Sendable (Int, Int, Int) -> Void

    public var onNoteOn: NoteOnHandler?
    public var onNoteOff: NoteOffHandler?
    public var onControlChange: ControlChangeHandler?

    private var client: MIDIClientRef = 0
    private var destination: MIDIEndpointRef = 0

    public init(name: String = "Chips") throws {
        var client: MIDIClientRef = 0
        let clientStatus = MIDIClientCreateWithBlock(name as CFString, &client, nil)
        guard clientStatus == noErr else {
            throw ChipsMIDIError.clientCreate(clientStatus)
        }
        self.client = client

        var dest: MIDIEndpointRef = 0
        let destStatus = MIDIDestinationCreateWithBlock(client, name as CFString, &dest) { [weak self] packetList, _ in
            self?.dispatch(packetList: packetList)
        }
        guard destStatus == noErr else {
            MIDIClientDispose(client)
            self.client = 0
            throw ChipsMIDIError.destinationCreate(destStatus)
        }
        self.destination = dest
    }

    deinit {
        if destination != 0 { MIDIEndpointDispose(destination) }
        if client != 0 { MIDIClientDispose(client) }
    }

    private func dispatch(packetList: UnsafePointer<MIDIPacketList>) {
        let list = packetList.pointee
        var packet = list.packet
        for _ in 0..<Int(list.numPackets) {
            handlePacket(packet)
            packet = withUnsafePointer(to: packet) { MIDIPacketNext($0).pointee }
        }
    }

    private func handlePacket(_ packet: MIDIPacket) {
        let length = Int(packet.length)
        guard length > 0 else { return }
        withUnsafePointer(to: packet.data) { tuplePointer in
            let bytes = UnsafeRawPointer(tuplePointer).assumingMemoryBound(to: UInt8.self)
            var index = 0
            while index < length {
                let status = bytes[index]
                let high = status & 0xF0
                let channel = Int(status & 0x0F)
                switch high {
                case 0x90: // Note on
                    if index + 2 < length {
                        let midi = Int(bytes[index + 1])
                        let vel = Int(bytes[index + 2])
                        if vel == 0 {
                            onNoteOff?(channel, midi)
                        } else {
                            onNoteOn?(channel, midi, Float(vel) / 127.0)
                        }
                        index += 3
                    } else { index += 1 }
                case 0x80: // Note off
                    if index + 2 < length {
                        let midi = Int(bytes[index + 1])
                        onNoteOff?(channel, midi)
                        index += 3
                    } else { index += 1 }
                case 0xB0: // CC
                    if index + 2 < length {
                        let cc = Int(bytes[index + 1])
                        let value = Int(bytes[index + 2])
                        onControlChange?(channel, cc, value)
                        index += 3
                    } else { index += 1 }
                case 0xC0, 0xD0: // 2-byte (program change, channel pressure)
                    index += 2
                case 0xA0, 0xE0: // 3-byte (poly aftertouch, pitch bend)
                    index += 3
                case 0xF0: // System messages — varían
                    if status == 0xF0 {
                        // SysEx: skip until 0xF7.
                        var p = index + 1
                        while p < length && bytes[p] != 0xF7 { p += 1 }
                        index = p + 1
                    } else if status == 0xF1 || status == 0xF3 { index += 2 }
                    else if status == 0xF2 { index += 3 }
                    else { index += 1 }
                default:
                    index += 1
                }
            }
        }
    }
}
