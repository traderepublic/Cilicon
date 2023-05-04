import Foundation
import Virtualization

struct TartConfig: Decodable {
    let memorySize: UInt
    let arch: Arch
    let os: OS
    let hardwareModel: VZMacHardwareModel
    let ecid: VZMacMachineIdentifier
    
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.memorySize = try container.decode(UInt.self, forKey: .memorySize)
        self.arch = try container.decode(Arch.self, forKey: .arch)
        self.os = try container.decode(OS.self, forKey: .os)
        let encodedHardwareModel = try container.decode(String.self, forKey: .hardwareModel)
        guard let data = Data(base64Encoded: encodedHardwareModel) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel,
                                                   in: container,
                                                   debugDescription: "Failed to parse Base64 String into Data")
        }
        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(forKey: .hardwareModel,
                                                   in: container,
                                                   debugDescription: "Failed to init VZMacHardwareModel from Data")
        }
        self.hardwareModel = hardwareModel
        
        let encodedECID = try container.decode(String.self, forKey: .ecid)
        guard let data = Data(base64Encoded: encodedECID) else {
            throw DecodingError.dataCorruptedError(forKey: .ecid,
                                                   in: container,
                                                   debugDescription: "Failed to parse Base64 String into Data")
        }
        guard let ecid = VZMacMachineIdentifier(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(forKey: .ecid,
                                                   in: container,
                                                   debugDescription: "Failed to init VZMacMachineIdentifier from Data")
        }
        self.ecid = ecid
    }
    
    
    enum CodingKeys: CodingKey {
        case memorySize
        case arch
        case os
        case hardwareModel
        case ecid
    }
    
    enum Arch: String, Codable {
        case arm64
    }
    enum OS: String, Codable {
        case darwin
    }
}
