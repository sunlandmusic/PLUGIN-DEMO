# PLUGIN22 Audio Unit Plugin Rewrite Project

## Overview
Transform the existing Audio Unit Filter Demo into a Piano plugin by modifying the working codebase. This project maintains the existing Audio Unit infrastructure while replacing the filter functionality with a piano instrument.

## First Steps: Changing App Display
To change how the plugin appears in host apps (GarageBand, AUM), update these locations:
1. `MainInterface.storyboard` - Update label text to "Piano XL"
2. `Info.plist` - Modify:
   - AudioComponents description: "Piano XL Plugin"
   - AudioComponents name: "Piano XL"
   - Manufacturer: Your identifier
   - Type: Instrument (not Effect)

## Next Steps: Modifying Functionality
Follow this sequence to ensure a working transformation:

1. `/Filter/iOS/FilterDemoFramework/UI/`
   - Replace FilterView with PianoKeyboardView
   - Implement Metal-based keyboard rendering
   - Add touch handling for piano keys
   - Keep same file structure, update content

2. `/Filter/iOS/FilterDemoAppExtension/`
   - Update FilterDemoViewController to handle piano functionality
   - Implement MIDI input processing
   - Add preset management for different sounds
   - Connect UI events to sound generation

3. `/Filter/iOS/FilterDemoApp/`
   - Update main app interface
   - Modify view controllers for piano display
   - Ensure proper Audio Unit initialization

## Sound Implementation
1. Add sound resources to the project:
   - Copy all .aif files to the project
   - Required sounds:
     - PIANO-C0.aif (1.4MB)
     - RHODES-C0.aif (949KB)
     - BALAFON-C0.aif (769KB)
     - BASS.aif (388KB)
     - DOTS-C0.aif (845KB)
     - PAD-C0.aif (2.8MB)
     - PLUCK-C0.aif (1.3MB)

2. Implement sample loading:
   ```swift
   class SampleManager {
       enum SampleType: String, CaseIterable {
           case piano = "PIANO-C0"
           case rhodes = "RHODES-C0"
           // ... other instruments
       }
       
       func loadSample(_ type: SampleType) throws -> AVAudioFile
   }
   ```

## Required Features
1. Audio Unit v3 Plugin (iOS)
   - Proper initialization
   - Parameter handling
   - Preset management

2. Piano Keyboard Interface
   - Metal-based rendering
   - Multi-touch support
   - Visual feedback on key press

3. Sound Generation
   - Sample-based playback
   - Pitch shifting
   - Velocity sensitivity

4. MIDI Support
   - Input handling
   - Note on/off
   - Control changes
   - Program changes

## Implementation Details

### Audio Unit Structure
```swift
public class PianoXLAudioUnit: AUAudioUnit {
    // Core setup
    private let kernelAdapter = PianoXLKernelAdapter()
    private var outputBusArray: AUAudioUnitBusArray!
    
    // Initialize with standard format
    public override init(componentDescription: AudioComponentDescription,
                        options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        // ... setup code ...
    }
}
```

### UI Implementation
```swift
class PianoKeyboardView: UIView {
    // Key dimensions
    private let whiteKeyWidth: CGFloat = 23
    private let blackKeyWidth: CGFloat = 13
    private let blackKeyHeight: CGFloat = 100
    
    // Touch handling
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // ... implementation ...
    }
}
```

### MIDI Handling
```swift
public class MIDIHandler {
    // MIDI setup
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    
    // Message processing
    private func processMIDIPacket(_ data: [UInt8]) {
        // ... implementation ...
    }
}
```

## Testing Requirements
1. App loads in GarageBand/AUM
2. Piano keyboard responds to touch
3. Different sounds play correctly
4. MIDI input works
5. Presets change instruments

## Code Change Format
When implementing changes, use this format:
```swift
// File: /Filter/iOS/FilterDemoFramework/FilterView.swift
// Replace entire file with:

import UIKit
import Metal
import MetalKit

class PianoKeyboardView: UIView {
    // New implementation
}

// What it does: Replaces filter UI with piano keyboard
// Why: Transform filter into piano instrument
// Expected: Displays piano keys, handles touch input
// Dependencies: Metal, MetalKit frameworks
```

## Reference Implementation
See the complete reference implementation in `REWRITE_REFERENCE.md` for:
- Full class implementations
- Sample management code
- MIDI handling
- UI rendering details

## Important Notes
1. Keep the Audio Unit infrastructure intact
2. Maintain file naming conventions
3. Update bundle identifiers appropriately
4. Test thoroughly in host applications
5. Handle memory efficiently for samples 