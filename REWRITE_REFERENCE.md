# PianoXL Reference Implementation Guide

## Table of Contents
1. [Core Audio Unit Implementation](#core-audio-unit-implementation)
2. [UI Components](#ui-components)
3. [MIDI Implementation](#midi-implementation)
4. [Sample Management](#sample-management)
5. [Sound Resources](#sound-resources)

## Core Audio Unit Implementation

### PianoXLAudioUnit.swift
```swift
import AudioToolbox
import AVFoundation
import CoreAudioKit

public class PianoXLAudioUnit: AUAudioUnit {
    // MARK: - Properties
    private let kernelAdapter = PianoXLKernelAdapter()
    private var outputBusArray: AUAudioUnitBusArray!
    private var _currentPreset: AUAudioUnitPreset?
    private var _parameterTree: AUParameterTree?
    
    // MARK: - Parameters
    public override var parameterTree: AUParameterTree? {
        get { return _parameterTree }
        set { _parameterTree = newValue }
    }
    
    // MARK: - Audio Processing Properties
    public override var inputBusses: AUAudioUnitBusArray {
        get { return super.inputBusses }
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return outputBusArray
    }
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        return kernelAdapter.internalRenderBlock
    }
    
    public override var providesUserInterface: Bool {
        return true
    }
    
    public override var supportsMPE: Bool {
        return true
    }
    
    private var maximumChannels: Int = 16
    
    // MARK: - Initialization
    public override init(componentDescription: AudioComponentDescription,
                        options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        
        // Setup output bus
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let outputBus = try AUAudioUnitBus(format: format)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self,
                                           busType: .output,
                                           busses: [outputBus])
        
        // Setup parameters
        setupParameterTree()
        
        // Setup render resources
        kernelAdapter.internalRenderBlock = internalRenderBlock
        maximumFramesToRender = 4096
    }
    
    // MARK: - Parameter Management
    private func setupParameterTree() {
        let volume = AUParameterTree.createParameter(
            withIdentifier: "volume",
            name: "Volume",
            address: 0,
            min: 0.0,
            max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        _parameterTree = AUParameterTree.createTree(withChildren: [volume])
        
        _parameterTree?.implementorValueObserver = { [weak self] param, value in
            self?.kernelAdapter.setParameter(param.address, value: value)
        }
        
        _parameterTree?.implementorValueProvider = { [weak self] param in
            return self?.kernelAdapter.getParameter(param.address) ?? param.value
        }
    }
    
    // MARK: - MIDI Support
    public func noteOn(note: UInt8, velocity: UInt8) {
        kernelAdapter.noteOn(note: note, velocity: velocity)
    }
    
    public func noteOff(note: UInt8) {
        kernelAdapter.noteOff(note: note)
    }
}
```

## UI Components

### PianoKeyboardView.swift
```swift
#if os(iOS)
import UIKit
import Metal
import MetalKit

class PianoKeyboardView: UIView {
    // MARK: - Properties
    public weak var pianoDelegate: PianoKeyboardDelegate?
    private var metalView: MTKView!
    private var renderer: PianoKeyboardRenderer!
    private var touchedKeys: [UITouch: Int] = [:]
    private var keyRects: [CGRect] = []
    private var whiteKeyCount: Int = 52 // 88-key piano
    private var firstNote: Int = 21 // A0
    
    // MARK: - Constants
    private let whiteKeyWidth: CGFloat = 23
    private let blackKeyWidth: CGFloat = 13
    private let blackKeyHeight: CGFloat = 100
    private let blackKeyOffsets: [CGFloat] = [
        14.0,  // C#
        14.0,  // D#
        0.0,   // (no black key after E)
        14.0,  // F#
        14.0,  // G#
        14.0,  // A#
        0.0    // (no black key after B)
    ]
    
    // MARK: - Touch Handling
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if let (note, _) = findKey(at: location) {
                touchedKeys[touch] = note
                let velocity = Float(touch.force / touch.maximumPossibleForce)
                pianoDelegate?.noteOn(note: note, velocity: Int(velocity))
                setNeedsDisplay()
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if let (note, _) = findKey(at: location) {
                if let oldNote = touchedKeys[touch], oldNote != note {
                    pianoDelegate?.noteOff(note: oldNote)
                    touchedKeys[touch] = note
                    let velocity = Float(touch.force / touch.maximumPossibleForce)
                    pianoDelegate?.noteOn(note: note, velocity: Int(velocity))
                    setNeedsDisplay()
                }
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let note = touchedKeys[touch] {
                pianoDelegate?.noteOff(note: note)
                touchedKeys.removeValue(forKey: touch)
                setNeedsDisplay()
            }
        }
    }
}
#endif
```

## MIDI Implementation

### MIDIHandler.swift
```swift
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
    
    // MARK: - MIDI Processing
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
        }
    }
}
```

## Sample Management

### SampleManager.swift
```swift
import AVFoundation

class SampleManager {
    enum SampleType: String, CaseIterable {
        case piano = "PIANO-C0"
        case rhodes = "RHODES-C0"
        case balafon = "BALAFON-C0"
        case bass = "BASS"
        case dots = "DOTS-C0"
        case pad = "PAD-C0"
        case pluck = "PLUCK-C0"
    }

    private var samples: [SampleType: AVAudioFile] = [:]
    
    func loadSample(_ type: SampleType) throws -> AVAudioFile {
        if let loaded = samples[type] {
            return loaded
        }
        
        guard let url = Bundle.main.url(forResource: type.rawValue, withExtension: "aif") else {
            throw NSError(domain: "SampleManager", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Sample not found"])
        }
        
        let file = try AVAudioFile(forReading: url)
        samples[type] = file
        return file
    }
}
```

## Sound Resources

### Available Sound Files
The following .aif files must be included in the project:

1. `PIANO-C0.aif` (1.4MB)
   - Main piano sound
   - Base note: C0

2. `RHODES-C0.aif` (949KB)
   - Electric piano sound
   - Base note: C0

3. `BALAFON-C0.aif` (769KB)
   - Percussion sound
   - Base note: C0

4. `BASS.aif` (388KB)
   - Bass instrument sound

5. `DOTS-C0.aif` (845KB)
   - Special effect sound
   - Base note: C0

6. `PAD-C0.aif` (2.8MB)
   - Synthesizer pad sound
   - Base note: C0

7. `PLUCK-C0.aif` (1.3MB)
   - Plucked string sound
   - Base note: C0

### Sample Implementation Notes
1. All samples should be:
   - Added to the project resources
   - Included in the app bundle
   - Properly referenced in Info.plist
   - Loaded on demand to manage memory

2. Sample Format:
   - Format: .aif (AIFF)
   - Sample Rate: 44.1kHz
   - Bit Depth: 16-bit
   - Channels: Stereo

3. Memory Management:
   - Total size: ~8.5MB
   - Consider loading/unloading as needed
   - Cache frequently used samples
   - Monitor memory usage

## Implementation Notes

### Key Classes
1. `PianoXLAudioUnit`: Main Audio Unit implementation
2. `PianoKeyboardView`: UI rendering and touch handling
3. `MIDIHandler`: MIDI input/output processing
4. `SampleManager`: Sound file management

### Dependencies
1. Frameworks:
   - AudioToolbox
   - AVFoundation
   - CoreAudioKit
   - Metal
   - MetalKit

2. Resources:
   - .aif sound files
   - Metal shaders (if used)

### Memory Considerations
1. Sample Loading:
   - Load samples on demand
   - Unload unused samples
   - Cache frequently used sounds

2. UI Performance:
   - Use Metal for efficient rendering
   - Optimize touch handling
   - Minimize main thread work

### Testing Points
1. Audio:
   - Sample playback
   - Pitch shifting
   - Volume control

2. UI:
   - Key rendering
   - Touch response
   - Visual feedback

3. MIDI:
   - Input handling
   - Output generation
   - Channel management 