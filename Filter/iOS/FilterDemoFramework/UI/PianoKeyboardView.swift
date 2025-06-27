#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Metal
import MetalKit
import AVFoundation

// UTF-8

public protocol PianoKeyboardDelegate: AnyObject {
    func noteOn(note: Int, velocity: Int)
    func noteOff(note: Int)
}

#if os(iOS)
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
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetalView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalView()
    }
    
    private func setupMetalView() {
        metalView = MTKView(frame: bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(metalView)
        
        renderer = PianoKeyboardRenderer(metalView: metalView)
        metalView.delegate = renderer
        
        // Enable multiple touch
        metalView.isMultipleTouchEnabled = true
        
        // Calculate key rectangles
        calculateKeyRects()
    }
    
    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
        calculateKeyRects()
    }
    
    private func calculateKeyRects() {
        keyRects.removeAll()
        
        let height = bounds.height
        var x: CGFloat = 0
        
        // Calculate white key positions
        for i in 0..<whiteKeyCount {
            let keyRect = CGRect(x: x, y: 0, width: whiteKeyWidth, height: height)
            keyRects.append(keyRect)
            x += whiteKeyWidth
        }
        
        // Calculate black key positions
        x = whiteKeyWidth - (blackKeyWidth / 2)
        for i in 0..<(whiteKeyCount - 1) {
            let octavePosition = i % 7
            if blackKeyOffsets[octavePosition] != 0 {
                let keyRect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
                keyRects.append(keyRect)
            }
            x += whiteKeyWidth
        }
    }
    
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
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    // MARK: - Helper Functions
    private func findKey(at point: CGPoint) -> (note: Int, isBlack: Bool)? {
        // Check black keys first (they're on top)
        for (index, rect) in keyRects.enumerated() {
            if index >= whiteKeyCount && rect.contains(point) {
                let note = firstNote + index
                return (note, true)
            }
        }
        
        // Then check white keys
        for (index, rect) in keyRects.enumerated() {
            if index < whiteKeyCount && rect.contains(point) {
                let note = firstNote + index
                return (note, false)
            }
        }
        
        return nil
    }
    
    // MARK: - Public Interface
    public func setActiveNotes(_ notes: Set<Int>) {
        renderer.setActiveNotes(notes)
        setNeedsDisplay()
    }
}
#else
class PianoKeyboardView: NSView {
    // MARK: - Properties
    public weak var pianoDelegate: PianoKeyboardDelegate?
    
    private var metalView: MTKView!
    private var renderer: PianoKeyboardRenderer!
    private var touchedKeys: [NSTouch: Int] = [:]
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
    
    // MARK: - Initialization
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupMetalView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetalView()
    }
    
    private func setupMetalView() {
        metalView = MTKView(frame: bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.autoresizingMask = [.width, .height]
        addSubview(metalView)
        
        renderer = PianoKeyboardRenderer(metalView: metalView)
        metalView.delegate = renderer
        
        // Enable multiple touch
        metalView.isMultipleTouchEnabled = true
        
        // Calculate key rectangles
        calculateKeyRects()
    }
    
    // MARK: - Layout
    public override func layout() {
        super.layout()
        metalView.frame = bounds
        calculateKeyRects()
    }
    
    private func calculateKeyRects() {
        keyRects.removeAll()
        
        let height = bounds.height
        var x: CGFloat = 0
        
        // Calculate white key positions
        for i in 0..<whiteKeyCount {
            let keyRect = CGRect(x: x, y: 0, width: whiteKeyWidth, height: height)
            keyRects.append(keyRect)
            x += whiteKeyWidth
        }
        
        // Calculate black key positions
        x = whiteKeyWidth - (blackKeyWidth / 2)
        for i in 0..<(whiteKeyCount - 1) {
            let octavePosition = i % 7
            if blackKeyOffsets[octavePosition] != 0 {
                let keyRect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
                keyRects.append(keyRect)
            }
            x += whiteKeyWidth
        }
    }
    
    // Convert NSPoint to CGPoint for consistency
    private func convertTouchLocation(_ touch: NSTouch) -> CGPoint {
        let point = touch.normalizedPosition
        return CGPoint(
            x: point.x * bounds.width,
            y: (1 - point.y) * bounds.height
        )
    }
    
    // MARK: - Mouse/Touch Handling
    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        handleTouchDown(at: location, pressure: Float(event.pressure))
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        handleTouchMove(at: location, pressure: Float(event.pressure))
    }
    
    public override func mouseUp(with event: NSEvent) {
        for touch in touchedKeys.values {
            pianoDelegate?.noteOff(note: touch)
        }
        touchedKeys.removeAll()
        setNeedsDisplay()
    }
    
    private func handleTouchDown(at location: CGPoint, pressure: Float) {
        if let (note, _) = findKey(at: location) {
            touchedKeys[NSTouch(phase: .began, location: location, pressure: pressure)] = note
            let velocity = pressure > 0 ? pressure : 0.7 // Default velocity if pressure not available
            pianoDelegate?.noteOn(note: note, velocity: Int(velocity))
            renderer.setKeyHighlight(note: note, intensity: 1.0)
            setNeedsDisplay()
        }
    }
    
    private func handleTouchMove(at location: CGPoint, pressure: Float) {
        if let (note, _) = findKey(at: location) {
            touchedKeys[NSTouch(phase: .moved, location: location, pressure: pressure)] = note
            let velocity = pressure > 0 ? pressure : 0.7
            pianoDelegate?.noteOn(note: note, velocity: Int(velocity))
            renderer.setKeyHighlight(note: note, intensity: 1.0)
            setNeedsDisplay()
        }
    }
    
    // MARK: - Helper Functions
    private func findKey(at point: CGPoint) -> (note: Int, isBlack: Bool)? {
        // Check black keys first (they're on top)
        for (index, rect) in keyRects.enumerated().reversed() {
            if index >= whiteKeyCount && rect.contains(point) {
                let note = firstNote + index
                return (note, true)
            }
        }
        
        // Then check white keys
        for (index, rect) in keyRects.enumerated() {
            if index < whiteKeyCount && rect.contains(point) {
                let note = firstNote + index
                return (note, false)
            }
        }
        
        return nil
    }
    
    // MARK: - Public Interface
    public func setActiveNotes(_ notes: Set<Int>) {
        renderer.setActiveNotes(notes)
        setNeedsDisplay()
    }
}
#endif 