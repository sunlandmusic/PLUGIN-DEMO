// UTF-8
import AudioToolbox
import AVFoundation

public class PianoXLKernelAdapter {
    // MARK: - Properties
    private var format: AVAudioFormat?
    private var sampleRate: Double = 44100.0
    private var activeNotes: Set<UInt8> = []
    private var parameters: [AUParameterAddress: AUValue] = [:]
    private let sampleManager = SampleManager()
    
    // Thread-safe MIDI event queue
    private let midiEventQueue = DispatchQueue(label: "com.pianoXL.midiQueue", attributes: .concurrent)
    
    public var midiOutputEventBlock: AUMIDIOutputEventBlock?
    public var internalRenderBlock: AUInternalRenderBlock!
    
    // MARK: - Initialization
    public init() {
        setupInternalRenderBlock()
    }
    
    private func setupInternalRenderBlock() {
        internalRenderBlock = { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock in
            guard let self = self else { return noErr }
            
            // Process MIDI events first
            var event = realtimeEventListHead
            while event != nil {
                guard let currentEvent = event?.pointee else {
                    event = nil
                    continue
                }
                
                switch currentEvent.head.eventType {
                case .MIDI:
                    let midiData = currentEvent.MIDI
                    self.handleMIDIEvent(status: midiData.data.0,
                                       data1: midiData.data.1,
                                       data2: midiData.data.2)
                default:
                    break
                }
                
                // Correct way to traverse to next event
                event = UnsafePointer(currentEvent.head.next)
            }
            
            // Process audio
            self.process(timestamp: timestamp, frameCount: frameCount, output: outputData)
            
            return noErr
        }
    }
    
    // MARK: - Parameter Management
    public func setParameter(_ address: AUParameterAddress, value: AUValue) {
        parameters[address] = value
    }
    
    public func getParameter(_ address: AUParameterAddress) -> AUValue {
        return parameters[address] ?? 0.0
    }
    
    // MARK: - Format Management
    public func shouldChangeToFormat(_ format: AVAudioFormat) -> Bool {
        self.format = format
        self.sampleRate = format.sampleRate
        return true
    }
    
    // MARK: - Sample Management
    public func setSampleType(_ type: SampleManager.SampleType) {
        sampleManager.setCurrentType(type)
    }
    
    // MARK: - MIDI Event Handling
    public func handleMIDIEvent(status: UInt8, data1: UInt8, data2: UInt8) {
        let statusType = status & 0xF0
        let channel = status & 0x0F
        
        switch statusType {
        case 0x90: // Note On
            if data2 > 0 {
                noteOn(note: data1, velocity: data2)
            } else {
                noteOff(note: data1)
            }
        case 0x80: // Note Off
            noteOff(note: data1)
        case 0xB0: // Control Change
            controlChange(controller: data1, value: data2)
        case 0xE0: // Pitch Bend
            let value = Float((UInt16(data2) << 7) | UInt16(data1)) / 16383.0
            pitchBend(value: value)
        default:
            break
        }
    }
    
    public func noteOn(note: UInt8, velocity: UInt8) {
        midiEventQueue.async {
            self.activeNotes.insert(note)
            self.sampleManager.playSample(atNote: note, withVelocity: velocity)
        }
    }
    
    public func noteOff(note: UInt8) {
        midiEventQueue.async {
            self.activeNotes.remove(note)
            self.sampleManager.stopSample(note: note)
        }
    }
    
    public func controlChange(controller: UInt8, value: UInt8) {
        // Handle control change messages
    }
    
    public func pitchBend(value: Float) {
        // Handle pitch bend
    }
    
    // MARK: - Audio Processing
    public func process(timestamp: UnsafePointer<AudioTimeStamp>,
                       frameCount: AUAudioFrameCount,
                       output: UnsafeMutablePointer<AudioBufferList>) {
        // Audio processing is now handled by AVAudioEngine in SampleManager
    }
    
    // MARK: - Helper Functions
    private func midiNoteToFrequency(_ note: UInt8) -> Double {
        let a4 = 440.0
        return a4 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }
} 