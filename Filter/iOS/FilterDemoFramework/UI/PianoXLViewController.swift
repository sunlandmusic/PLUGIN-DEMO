//
//  SoundSelectorView.swift
//  PianoXL
//
//  Created by AI on 2024-07-25.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import PianoXLCore

// MARK: - Platform Type Aliases
#if os(iOS)
public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#else
public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#endif

/// This is a placeholder delegate. The actual one should be used from the Core module.
public protocol SoundSelectorDelegate: AnyObject {
    func didSelectSound(_ type: SampleManager.SampleType)
}


// MARK: - SoundSelectorView
public class SoundSelectorView: PlatformView {
    
    // MARK: - Properties
    public weak var delegate: SoundSelectorDelegate?
    private let soundLabel = PlatformLabel()
    
    private var allSounds: [SampleManager.SampleType] = SampleManager.SampleType.allCases
    private var currentIndex: Int = 0

    // MARK: - Design Constants
    private struct Design {
        static let width: CGFloat = 132
        static let height: CGFloat = 50
        static let cornerRadius: CGFloat = 15
        static let backgroundColor = PlatformColor(white: 0, alpha: 0.5)
        static let borderColorNormal = PlatformColor(white: 1, alpha: 0.15)
        static let borderColorSelected = PlatformColor(white: 1, alpha: 0.3)
        static let borderWidthNormal: CGFloat = 1
        static let borderWidthSelected: CGFloat = 2
        static let textColor = PlatformColor.white
        static let fontSize: CGFloat = 16
        static let fontWeight: PlatformFont.Weight = .medium
    }
    
    // MARK: - Initialization
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        if !allSounds.isEmpty {
            updateSoundLabel(for: allSounds[currentIndex])
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    public func setSelectedSound(_ type: SampleManager.SampleType) {
        if let index = allSounds.firstIndex(of: type) {
            currentIndex = index
            updateSoundLabel(for: type)
        }
    }

    // MARK: - Setup
    private func setupView() {
        #if os(iOS)
        backgroundColor = Design.backgroundColor
        layer.cornerRadius = Design.cornerRadius
        layer.borderWidth = Design.borderWidthNormal
        layer.borderColor = Design.borderColorNormal.cgColor
        clipsToBounds = true
        #else
        wantsLayer = true
        layer?.backgroundColor = Design.backgroundColor.cgColor
        layer?.cornerRadius = Design.cornerRadius
        layer?.borderWidth = Design.borderWidthNormal
        layer?.borderColor = Design.borderColorNormal.cgColor
        #endif
        
        setupLabel()
        setupGestureRecognizer()
        setupAccessibility()
    }
    
    private func setupLabel() {
        soundLabel.translatesAutoresizingMaskIntoConstraints = false
        #if os(iOS)
        soundLabel.textColor = Design.textColor
        soundLabel.font = UIFont.systemFont(ofSize: Design.fontSize, weight: Design.fontWeight)
        soundLabel.textAlignment = .center
        #else
        soundLabel.textColor = Design.textColor
        soundLabel.font = NSFont.systemFont(ofSize: Design.fontSize, weight: Design.fontWeight)
        soundLabel.alignment = .center
        soundLabel.isBezeled = false
        soundLabel.drawsBackground = false
        soundLabel.isEditable = false
        soundLabel.isSelectable = false
        #endif
        
        addSubview(soundLabel)
        
        NSLayoutConstraint.activate([
            soundLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            soundLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            soundLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            soundLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }
    
    private func setupGestureRecognizer() {
        #if os(iOS)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        #endif
    }
    
    private func setupAccessibility() {
        #if os(iOS)
        isAccessibilityElement = true
        accessibilityLabel = "Sound selector"
        accessibilityTraits = .button
        #else
        setAccessibilityRole(.button)
        setAccessibilityLabel("Sound selector")
        #endif
    }
    
    // MARK: - Updates
    private func updateSoundLabel(for type: SampleManager.SampleType) {
        let soundName = type.displayName.uppercased()
        #if os(iOS)
        soundLabel.text = soundName
        accessibilityValue = soundName
        #else
        soundLabel.stringValue = soundName
        setAccessibilityValue(soundName)
        #endif
    }
    
    private func updateBorderAppearance(isSelected: Bool) {
        #if os(iOS)
        layer.borderWidth = isSelected ? Design.borderWidthSelected : Design.borderWidthNormal
        layer.borderColor = (isSelected ? Design.borderColorSelected : Design.borderColorNormal).cgColor
        #else
        layer?.borderWidth = isSelected ? Design.borderWidthSelected : Design.borderWidthNormal
        layer?.borderColor = (isSelected ? Design.borderColorSelected : Design.borderColorNormal).cgColor
        #endif
    }
    
    // MARK: - Interaction
    @objc private func handleTap() {
        guard !allSounds.isEmpty else { return }
        currentIndex = (currentIndex + 1) % allSounds.count
        let newSoundType = allSounds[currentIndex]
        
        updateSoundLabel(for: newSoundType)
        delegate?.didSelectSound(newSoundType)
        
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    #if os(macOS)
    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }
    #endif
}


// MARK: - Platform Label Helper
#if os(iOS)
private typealias PlatformLabel = UILabel
#else
private class PlatformLabel: NSTextField {}
#endif


// MARK: - Main View Controller
#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import AudioToolbox
import CoreAudioKit

public class PianoXLViewController: AUViewController {
    // MARK: - Properties
    private var pianoKeyboardView: PianoKeyboardView!
    private var soundSelectorView: SoundSelectorView!
    private var audioUnit: PianoXLAudioUnit? {
        didSet {
            DispatchQueue.main.async {
                self.setupViews()
            }
        }
    }
    
    // MARK: - Initialization
#if os(macOS)
    public override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }
#else
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
#endif
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - View Lifecycle
    public override func loadView() {
        #if os(macOS)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        #else
        view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        view.layer.backgroundColor = UIColor.black.cgColor
        #endif
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create and setup views
        setupSoundSelector()
        setupPianoKeyboard()
    }
    
    // MARK: - Setup
    private func setupViews() {
        guard let audioUnit = audioUnit else { return }
        
        // Setup parameter observation
        if let parameterTree = audioUnit.parameterTree {
            parameterTree.implementorValueObserver = { [weak self] param, value in
                if param.address == 5 { // Sample type parameter
                    if let index = Int(exactly: value),
                       index >= 0 && index < SampleManager.SampleType.allCases.count {
                        let type = SampleManager.SampleType.allCases[index]
                        self?.soundSelectorView.setSelectedSound(type)
                    }
                }
            }
        }
    }
    
    private func setupSoundSelector() {
        soundSelectorView = SoundSelectorView(frame: .zero)
        soundSelectorView.translatesAutoresizingMaskIntoConstraints = false
        soundSelectorView.delegate = self
        view.addSubview(soundSelectorView)
        
        NSLayoutConstraint.activate([
            soundSelectorView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            soundSelectorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupPianoKeyboard() {
        pianoKeyboardView = PianoKeyboardView(frame: .zero)
        pianoKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboardView.pianoDelegate = self
        view.addSubview(pianoKeyboardView)
        
        NSLayoutConstraint.activate([
            pianoKeyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pianoKeyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pianoKeyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pianoKeyboardView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
}

// MARK: - SoundSelectorDelegate
extension PianoXLViewController: SoundSelectorDelegate {
    public func didSelectSound(_ type: SampleManager.SampleType) {
        // Find the sampleType parameter in the audio unit's parameter tree
        if let parameter = audioUnit?.parameterTree?.parameter(withAddress: 5) {
            // Convert the sample type to its index value
            if let index = SampleManager.SampleType.allCases.firstIndex(of: type) {
                parameter.value = AUValue(index)
            }
        }
    }
}

// MARK: - PianoKeyboardDelegate
extension PianoXLViewController: PianoKeyboardDelegate {
    public func noteOn(note: Int, velocity: Int) {
        audioUnit?.noteOn(note: UInt8(note), velocity: UInt8(velocity))
    }
    
    public func noteOff(note: Int) {
        audioUnit?.noteOff(note: UInt8(note))
    }
}

/// This is a placeholder extension to allow the code to compile.
/// The actual SampleManager.SampleType enum should provide a display name.
extension SampleManager.SampleType {
    var displayName: String {
        return "\(self)"
    }
}

// MARK: - AUAudioUnitFactory
extension PianoXLViewController: AUAudioUnitFactory {
    public func createAudioUnit(with desc: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try PianoXLAudioUnit(componentDescription: desc, options: [])
        return audioUnit!
    }
} 