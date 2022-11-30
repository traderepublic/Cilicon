import Foundation

struct HardwareConfig: Decodable {
    /// Gigabytes of RAM for the Guest System.
    let ramGigabytes: UInt64
    /// Number of virtual CPU Cores. Defaults to the number of physical CPU cores.
    let cpuCores: Int?
    /// Display configuration.
    let display: DisplayConfig
    /// Whether or not to forward audio from the guest system to the host system audio device.
    let connectsToAudioDevice: Bool
    
    enum CodingKeys: CodingKey {
        case ramGigabytes
        case cpuCores
        case display
        case connectsToAudioDevice
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ramGigabytes = try container.decode(UInt64.self, forKey: .ramGigabytes)
        self.cpuCores = try container.decodeIfPresent(Int.self, forKey: .cpuCores)
        self.display = try container.decodeIfPresent(DisplayConfig.self, forKey: .display) ?? .default
        self.connectsToAudioDevice = try container.decodeIfPresent(Bool.self, forKey: .connectsToAudioDevice) ?? true
    }
    
    struct DisplayConfig: Decodable {
        static let `default`: DisplayConfig = .init(width: 1920, height: 1200, pixelsPerInch: 80)
        
        let width: Int
        let height: Int
        let pixelsPerInch: Int
    }
}
