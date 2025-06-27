// UTF-8
import Foundation

public enum Scale: String, CaseIterable {
    case major = "Major"
    case naturalMinor = "Natural Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    
    public var intervals: [Int] {
        switch self {
        case .major:
            return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:
            return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:
            return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:
            return [0, 2, 3, 5, 7, 9, 11]
        }
    }
}

public enum ChordQuality: String {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Diminished"
    case augmented = "Augmented"
    case dominant7 = "Dominant 7"
    case major7 = "Major 7"
    case minor7 = "Minor 7"
}

public struct Chord {
    public let root: Int
    public let quality: ChordQuality
    public let inversion: Int
    public let notes: Set<Int>
    
    public init(root: Int, quality: ChordQuality, inversion: Int, notes: Set<Int>) {
        self.root = root
        self.quality = quality
        self.inversion = inversion
        self.notes = notes
    }
}

public class MusicTheoryEngine {
    // MARK: - Properties
    private var activeNotes: Set<Int> = []
    private var currentChord: Chord?
    private var currentScale: Scale?
    private var currentKey: Int = 60 // Middle C
    
    public init() {}
    
    // MARK: - Note Management
    public func noteOn(note: Int) {
        activeNotes.insert(note)
        _ = analyzeChord()
        detectScale()
    }
    
    public func noteOff(note: Int) {
        activeNotes.remove(note)
        _ = analyzeChord()
        detectScale()
    }
    
    // MARK: - Chord Analysis
    public func analyzeChord() -> Chord? {
        guard activeNotes.count >= 3 else {
            currentChord = nil
            return nil
        }
        
        let sortedNotes = Array(activeNotes).sorted()
        let intervals = getIntervals(from: sortedNotes)
        
        // Basic triad detection
        if intervals.count >= 2 {
            let root = sortedNotes[0]
            let third = intervals[0]
            let fifth = intervals[1]
            
            switch (third, fifth) {
            case (4, 7):
                currentChord = Chord(root: root, quality: .major, inversion: 0, notes: activeNotes)
            case (3, 7):
                currentChord = Chord(root: root, quality: .minor, inversion: 0, notes: activeNotes)
            case (3, 6):
                currentChord = Chord(root: root, quality: .diminished, inversion: 0, notes: activeNotes)
            case (4, 8):
                currentChord = Chord(root: root, quality: .augmented, inversion: 0, notes: activeNotes)
            default:
                currentChord = nil
            }
        }
        
        return currentChord
    }
    
    private func detectScale() {
        guard activeNotes.count >= 3 else {
            currentScale = nil
            return
        }
        
        let sortedNotes = Array(activeNotes).sorted()
        let intervals = getIntervals(from: sortedNotes)
        
        for scale in Scale.allCases {
            if scale.intervals.starts(with: intervals) {
                currentScale = scale
                return
            }
        }
        
        currentScale = nil
    }
    
    // MARK: - Scale Suggestions
    public func suggestScales(for notes: [Int]) -> [Scale] {
        var suggestions: [Scale] = []
        
        // Get unique pitch classes
        let pitchClasses = notes.map { $0 % 12 }.unique
        
        // Check each scale type for compatibility
        for scale in Scale.allCases {
            if isCompatible(pitchClasses: pitchClasses, withScale: scale) {
                suggestions.append(scale)
            }
        }
        
        return suggestions
    }
    
    // MARK: - Helper Functions
    private func getIntervals(from notes: [Int]) -> [Int] {
        guard !notes.isEmpty else { return [] }
        let root = notes[0]
        return notes.dropFirst().map { ($0 - root) % 12 }
    }
    
    private func isCompatible(pitchClasses: Set<Int>, withScale scale: Scale) -> Bool {
        let scalePattern = getScalePattern(for: scale)
        let scalePitchClasses = generatePitchClasses(from: scalePattern)
        return pitchClasses.isSubset(of: scalePitchClasses)
    }
    
    private func getScalePattern(for scale: Scale) -> [Int] {
        switch scale {
        case .major:
            return [2, 2, 1, 2, 2, 2, 1] // W-W-H-W-W-W-H
        case .naturalMinor:
            return [2, 1, 2, 2, 1, 2, 2] // W-H-W-W-H-W-W
        case .harmonicMinor:
            return [2, 1, 2, 2, 1, 3, 1] // W-H-W-W-H-WH-H
        case .melodicMinor:
            return [2, 1, 2, 2, 2, 2, 1] // W-H-W-W-W-W-H
        }
    }
    
    private func generatePitchClasses(from pattern: [Int]) -> Set<Int> {
        var pitchClasses: Set<Int> = [0] // Start with root note
        var currentPitch = 0
        
        for interval in pattern {
            currentPitch = (currentPitch + interval) % 12
            pitchClasses.insert(currentPitch)
        }
        
        return pitchClasses
    }
    
    public func getCurrentChord() -> Chord? {
        return currentChord
    }
    
    public func getCurrentScale() -> Scale? {
        return currentScale
    }
}

// MARK: - Extensions
extension Array where Element: Hashable {
    var unique: Set<Element> {
        return Set(self)
    }
} 