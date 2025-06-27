// UTF-8
import Foundation
import CoreMIDI
import AVFoundation

public protocol MIDIHandlerDelegate: AnyObject {
    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    func noteOff(note: UInt8, velocity: UInt8, channel: UInt8)
    func controlChange(controller: UInt8, value: UInt8, channel: UInt8)
    func pitchBend(value: UInt16, channel: UInt8)
    func programChange(program: UInt8, channel: UInt8)
}

public class MIDIHandler {
    // MARK: - Properties
    public weak var delegate: MIDIHandlerDelegate?
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var virtualSource: MIDIEndpointRef = 0
    private var virtualDestination: MIDIEndpointRef = 0
    
    public var midiEventHandler: ((UInt8, UInt8, UInt8) -> Void)?
    
    // MARK: - Constants
    private enum MIDIConstants {
        static let noteOnStatus: UInt8 = 0x90
        static let noteOffStatus: UInt8 = 0x80
        static let controlChangeStatus: UInt8 = 0xB0
        static let programChangeStatus: UInt8 = 0xC0
        static let pitchBendStatus: UInt8 = 0xE0
        static let channelMask: UInt8 = 0x0F
        static let statusMask: UInt8 = 0xF0
    }
    
    // MARK: - Initialization
    public init() {
        setupMIDI()
    }
    
    deinit {
        cleanupMIDI()
    }
    
    // MARK: - MIDI Setup
    private func setupMIDI() {
        // Create MIDI client
        let status = MIDIClientCreate("PianoXL" as CFString, nil, nil, &midiClient)
        guard status == noErr else {
            print("Error creating MIDI client: \(status)")
            return
        }
        
        // Create input port
        let inputPortStatus = MIDIInputPortCreate(midiClient, "PianoXL Input" as CFString, midiReadProc, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &inputPort)
        guard inputPortStatus == noErr else {
            print("Error creating MIDI input port: \(inputPortStatus)")
            return
        }
        
        // Create virtual source
        let sourceStatus = MIDISourceCreate(midiClient, "PianoXL Source" as CFString, &virtualSource)
        guard sourceStatus == noErr else {
            print("Error creating virtual source: \(sourceStatus)")
            return
        }
        
        // Create virtual destination
        let destStatus = MIDIDestinationCreate(midiClient, "PianoXL Destination" as CFString, midiReadProc, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &virtualDestination)
        guard destStatus == noErr else {
            print("Error creating virtual destination: \(destStatus)")
            return
        }
        
        // Connect to all available sources
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
        }
    }
    
    private func cleanupMIDI() {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
    }
    
    private let midiReadProc: MIDIReadProc = { pktList, readProcRefCon, srcConnRefCon in
        let handler = Unmanaged<MIDIHandler>.fromOpaque(readProcRefCon!).takeUnretainedValue()
        
        let packets = UnsafePointer<MIDIPacketList>(pktList).pointee
        var packet = packets.packet
        
        for _ in 0..<packets.numPackets {
            var messageIndex = 0
            let data = withUnsafeBytes(of: packet.data) { bytes -> [UInt8] in
                Array(bytes.prefix(Int(packet.length)))
            }
            
            while messageIndex < data.count {
                let status = data[messageIndex] & 0xF0
                
                // Calculate message length based on status byte
                let messageLength: Int
                switch status {
                case 0x80, 0x90, 0xA0, 0xB0, 0xE0: // Note Off, Note On, Poly Pressure, Control Change, Pitch Bend
                    messageLength = 3
                case 0xC0, 0xD0: // Program Change, Channel Pressure
                    messageLength = 2
                case 0xF0: // System messages
                    if data[messageIndex] == 0xF0 {
                        // Find end of SysEx message
                        messageLength = data[messageIndex...].firstIndex(of: 0xF7)
                            .map { $0 - messageIndex + 1 } ?? data.count - messageIndex
                    } else {
                        messageLength = 1
                    }
                default:
                    messageLength = 1
                }
                
                // Ensure we have enough data for the complete message
                guard messageIndex + messageLength <= data.count else {
                    break
                }
                
                // Process complete MIDI message
                if messageLength >= 2 {
                    let byte1 = data[messageIndex + 1]
                    let byte2 = messageLength >= 3 ? data[messageIndex + 2] : 0
                    handler.midiEventHandler?(data[messageIndex], byte1, byte2)
                }
                
                messageIndex += messageLength
            }
            
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    // MARK: - MIDI Input Processing
    private func processMIDIPacket(_ data: [UInt8]) {
        guard data.count >= 2 else { return }
        
        let status = data[0]
        let channel = status & MIDIConstants.channelMask
        
        switch status & MIDIConstants.statusMask {
        case MIDIConstants.noteOnStatus:
            if data.count >= 3 {
                let note = data[1]
                let velocity = data[2]
                if velocity > 0 {
                    delegate?.noteOn(note: note, velocity: velocity, channel: channel)
                } else {
                    delegate?.noteOff(note: note, velocity: velocity, channel: channel)
                }
            }
            
        case MIDIConstants.noteOffStatus:
            if data.count >= 3 {
                let note = data[1]
                let velocity = data[2]
                delegate?.noteOff(note: note, velocity: velocity, channel: channel)
            }
            
        case MIDIConstants.controlChangeStatus:
            if data.count >= 3 {
                let controller = data[1]
                let value = data[2]
                delegate?.controlChange(controller: controller, value: value, channel: channel)
            }
            
        case MIDIConstants.programChangeStatus:
            if data.count >= 2 {
                let program = data[1]
                delegate?.programChange(program: program, channel: channel)
            }
            
        case MIDIConstants.pitchBendStatus:
            if data.count >= 3 {
                let lsb = UInt16(data[1])
                let msb = UInt16(data[2])
                let value = (msb << 7) | lsb
                delegate?.pitchBend(value: value, channel: channel)
            }
            
        default:
            break
        }
    }
    
    // MARK: - MIDI Output
    public func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        let status = MIDIConstants.noteOnStatus | (channel & MIDIConstants.channelMask)
        sendMIDIEvent([status, note, velocity])
    }
    
    public func sendNoteOff(note: UInt8, velocity: UInt8 = 0, channel: UInt8 = 0) {
        let status = MIDIConstants.noteOffStatus | (channel & MIDIConstants.channelMask)
        sendMIDIEvent([status, note, velocity])
    }
    
    public func sendControlChange(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        let status = MIDIConstants.controlChangeStatus | (channel & MIDIConstants.channelMask)
        sendMIDIEvent([status, controller, value])
    }
    
    public func sendProgramChange(program: UInt8, channel: UInt8 = 0) {
        let status = MIDIConstants.programChangeStatus | (channel & MIDIConstants.channelMask)
        sendMIDIEvent([status, program])
    }
    
    public func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        let status = MIDIConstants.pitchBendStatus | (channel & MIDIConstants.channelMask)
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        sendMIDIEvent([status, lsb, msb])
    }
    
    private func sendMIDIEvent(_ data: [UInt8]) {
        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = UInt16(data.count)
        
        withUnsafeMutableBytes(of: &packet.data) { ptr in
            for (index, byte) in data.enumerated() {
                ptr[index] = byte
            }
        }
        
        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            let destination = MIDIGetDestination(i)
            MIDISend(virtualDestination, destination, &packetList)
        }
    }
    
    // MARK: - Public Methods
    public func getDestinations() -> [String] {
        var destinations: [String] = []
        let count = MIDIGetNumberOfDestinations()
        
        for i in 0..<count {
            let endpoint = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
            if let nameString = name?.takeRetainedValue() as String? {
                destinations.append(nameString)
            }
        }
        
        return destinations
    }
} 