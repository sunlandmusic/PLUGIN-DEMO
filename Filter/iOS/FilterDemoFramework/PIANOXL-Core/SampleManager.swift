import AVFoundation
import AudioToolbox

public class SampleManager {
    // MARK: - Types
    public enum SampleType: String, CaseIterable {
        case piano = "PIANO"
        case rhodes = "RHODES"
        case bass = "BASS"
        case balafon = "BALAFON"
        case dots = "DOTS"
        case pad = "PAD"
        case pluck = "PLUCK"
    }
    
    // MARK: - Properties
    private var currentType: SampleType = .piano
    private var sampleBuffers: [SampleType: AVAudioPCMBuffer] = [:]
    private var activeSamples: [UInt8: (buffer: AVAudioPCMBuffer, playhead: Int)] = [:]
    private let sampleQueue = DispatchQueue(label: "com.pianoXL.sampleQueue", attributes: .concurrent)
    private let sampleRate: Double = 44100.0
    
    // MARK: - Initialization
    public init() {
        loadSamples()
    }
    
    private func loadSamples() {
        for type in SampleType.allCases {
            if let url = Bundle.main.url(forResource: "\(type.rawValue)-C0", withExtension: "aif") {
                do {
                    let file = try AVAudioFile(forReading: url)
                    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
                    try file.read(into: buffer)
                    sampleBuffers[type] = buffer
                } catch {
                    print("Error loading sample \(type.rawValue): \(error)")
                }
            }
        }
    }
    
    // MARK: - Sample Management
    public func setCurrentType(_ type: SampleType) {
        sampleQueue.async(flags: .barrier) {
            self.currentType = type
        }
    }
    
    public func playSample(atNote note: UInt8, withVelocity velocity: UInt8) {
        sampleQueue.async(flags: .barrier) {
            guard let sourceBuffer = self.sampleBuffers[self.currentType] else { return }
            
            // Create a new buffer for this note
            let format = sourceBuffer.format
            let newBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: sourceBuffer.frameCapacity)!
            
            // Copy the source buffer
            let frameCount = sourceBuffer.frameLength
            memcpy(newBuffer.floatChannelData?[0],
                  sourceBuffer.floatChannelData?[0],
                  Int(frameCount) * MemoryLayout<Float>.size)
            newBuffer.frameLength = frameCount
            
            // Apply velocity scaling
            let velocityScale = Float(velocity) / 127.0
            let floatData = UnsafeMutableBufferPointer(start: newBuffer.floatChannelData?[0],
                                                      count: Int(frameCount))
            for i in 0..<Int(frameCount) {
                floatData[i] *= velocityScale
            }
            
            // Store the buffer and reset playhead
            self.activeSamples[note] = (buffer: newBuffer, playhead: 0)
        }
    }
    
    public func stopSample(note: UInt8) {
        sampleQueue.async(flags: .barrier) {
            self.activeSamples.removeValue(forKey: note)
        }
    }
    
    // MARK: - Audio Processing
    public func processBuffer(outputBuffer: AVAudioPCMBuffer, frameCount: AVAudioFrameCount) {
        guard let outputData = outputBuffer.floatChannelData?[0] else { return }
        
        // Clear the output buffer
        memset(outputData, 0, Int(frameCount) * MemoryLayout<Float>.size)
        
        sampleQueue.sync {
            // Process each active sample
            for (note, var sampleInfo) in activeSamples {
                let buffer = sampleInfo.buffer
                let playhead = sampleInfo.playhead
                
                guard let inputData = buffer.floatChannelData?[0] else { continue }
                
                // Calculate how many frames we can copy
                let remainingFrames = Int(buffer.frameLength) - playhead
                let framesToProcess = min(Int(frameCount), remainingFrames)
                
                // Mix the sample into the output buffer
                for frame in 0..<framesToProcess {
                    outputData[frame] += inputData[playhead + frame]
                }
                
                // Update playhead
                sampleInfo.playhead += framesToProcess
                
                // Remove finished samples
                if sampleInfo.playhead >= Int(buffer.frameLength) {
                    activeSamples.removeValue(forKey: note)
                } else {
                    activeSamples[note] = sampleInfo
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func pitchShiftBuffer(_ buffer: AVAudioPCMBuffer, semitones: Float) -> AVAudioPCMBuffer? {
        // Simple resampling-based pitch shift
        let pitchRatio = pow(2.0, Float(semitones) / 12.0)
        let newLength = AVAudioFrameCount(Float(buffer.frameLength) / pitchRatio)
        
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                             frameCapacity: newLength) else { return nil }
        
        newBuffer.frameLength = newLength
        
        guard let inputData = buffer.floatChannelData?[0],
              let outputData = newBuffer.floatChannelData?[0] else { return nil }
        
        for frame in 0..<Int(newLength) {
            let sourceFrame = Float(frame) * pitchRatio
            let sourceFrameInt = Int(sourceFrame)
            let fraction = sourceFrame - Float(sourceFrameInt)
            
            if sourceFrameInt + 1 < buffer.frameLength {
                // Linear interpolation
                let sample1 = inputData[sourceFrameInt]
                let sample2 = inputData[sourceFrameInt + 1]
                outputData[frame] = sample1 + fraction * (sample2 - sample1)
            } else {
                outputData[frame] = 0.0
            }
        }
        
        return newBuffer
    }
} 