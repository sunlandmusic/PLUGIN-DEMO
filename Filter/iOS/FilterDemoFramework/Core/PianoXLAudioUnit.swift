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
    
    // MARK: - AUAudioUnit Overrides
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        kernelAdapter.setParameter(0, value: 1.0) // Default volume
    }
    
    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }
    
    // MARK: - MIDI
    public override var midiOutputEventBlock: AUMIDIOutputEventBlock? {
        get { return kernelAdapter.midiOutputEventBlock }
        set { kernelAdapter.midiOutputEventBlock = newValue }
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
    
    // MARK: - Presets
    public override var factoryPresets: [AUAudioUnitPreset] {
        let presets = SampleManager.SampleType.allCases.enumerated().map { (index, type) in
            let preset = AUAudioUnitPreset()
            preset.number = Int(index)
            preset.name = type.rawValue
            return preset
        }
        return presets
    }
    
    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            guard let preset = newValue else { return }
            
            if preset.number >= 0 && preset.number < SampleManager.SampleType.allCases.count {
                let type = SampleManager.SampleType.allCases[Int(preset.number)]
                kernelAdapter.setSampleType(type)
                _currentPreset = preset
            }
        }
    }
    
    // MARK: - MIDI Support
    public override var midiOutputNames: [String] {
        return ["Piano XL Output"]
    }
    
    // MARK: - UI Event Handling
    public func noteOn(note: UInt8, velocity: UInt8) {
        kernelAdapter.noteOn(note: note, velocity: velocity)
    }
    
    public func noteOff(note: UInt8) {
        kernelAdapter.noteOff(note: note)
    }
} 