// UTF-8
import Foundation
import AudioToolbox
import AVFoundation

public struct Preset: Codable {
    public let name: String
    public let parameters: [String: Float]
    public let version: Int
    
    // MARK: - Current Version
    public static let currentVersion = 1
    
    // MARK: - Factory Presets
    public static let defaultPreset = Preset(
        name: "Default",
        parameters: [
            "volume": 1.0,
            "attack": 0.01,
            "decay": 0.1,
            "sustain": 0.7,
            "release": 0.3
        ],
        version: currentVersion
    )
    
    public static let presets: [Preset] = [
        defaultPreset,
        Preset(
            name: "Soft Piano",
            parameters: [
                "volume": 0.8,
                "attack": 0.05,
                "decay": 0.2,
                "sustain": 0.6,
                "release": 0.4
            ],
            version: currentVersion
        ),
        Preset(
            name: "Bright Piano",
            parameters: [
                "volume": 1.0,
                "attack": 0.001,
                "decay": 0.08,
                "sustain": 0.8,
                "release": 0.2
            ],
            version: currentVersion
        )
    ]
    
    public init(name: String, parameters: [String: Float], version: Int) {
        self.name = name
        self.parameters = parameters
        self.version = version
    }
}

public class PresetManager {
    // MARK: - Properties
    private let userPresetsURL: URL
    private var userPresets: [Preset] = []
    
    // MARK: - Initialization
    public init() {
        // Get the application support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("PianoXL")
        let presetsDirectory = appDirectory.appendingPathComponent("Presets")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
        
        // Set the presets file URL
        userPresetsURL = presetsDirectory.appendingPathComponent("user_presets.json")
        
        // Load user presets
        loadUserPresets()
    }
    
    // MARK: - Preset Management
    public func loadUserPresets() {
        guard let data = try? Data(contentsOf: userPresetsURL),
              let presets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return
        }
        userPresets = presets
    }
    
    public func saveUserPresets() {
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        try? data.write(to: userPresetsURL)
    }
    
    public func savePreset(_ preset: Preset) {
        if let index = userPresets.firstIndex(where: { $0.name == preset.name }) {
            userPresets[index] = preset
        } else {
            userPresets.append(preset)
        }
        saveUserPresets()
    }
    
    public func deletePreset(named name: String) {
        userPresets.removeAll { $0.name == name }
        saveUserPresets()
    }
    
    // MARK: - Preset Access
    public func getAllPresets() -> [Preset] {
        return Preset.presets + userPresets
    }
    
    public func getPreset(named name: String) -> Preset? {
        if let factoryPreset = Preset.presets.first(where: { $0.name == name }) {
            return factoryPreset
        }
        return userPresets.first(where: { $0.name == name })
    }
    
    // MARK: - AUAudioUnit State Support
    public func getStateData() -> [String: Any] {
        return [
            "currentPreset": userPresets.last?.name ?? Preset.defaultPreset.name,
            "userPresets": userPresets.map { preset in
                [
                    "name": preset.name,
                    "parameters": preset.parameters,
                    "version": preset.version
                ]
            }
        ]
    }
    
    public func setStateData(_ state: [String: Any]) {
        if let presetData = state["userPresets"] as? [[String: Any]] {
            userPresets = presetData.compactMap { data in
                guard let name = data["name"] as? String,
                      let parameters = data["parameters"] as? [String: Float],
                      let version = data["version"] as? Int else {
                    return nil
                }
                return Preset(name: name, parameters: parameters, version: version)
            }
            saveUserPresets()
        }
    }
} 