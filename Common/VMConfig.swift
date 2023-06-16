import Foundation
import Virtualization

struct VMConfig: Codable {
    internal init(arch: VMConfig.Arch, os: VMConfig.OS, hardwareModel: VZMacHardwareModel, ecid: VZMacMachineIdentifier, macAddress: VZMACAddress) {
        self.arch = arch
        self.os = os
        self.hardwareModel = hardwareModel
        self.ecid = ecid
        self.macAddress = macAddress
    }

    let arch: Arch
    let os: OS
    let hardwareModel: VZMacHardwareModel
    let ecid: VZMacMachineIdentifier
    let macAddress: VZMACAddress

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.arch = try container.decode(Arch.self, forKey: .arch)
        self.os = try container.decode(OS.self, forKey: .os)
        let encodedHardwareModel = try container.decode(String.self, forKey: .hardwareModel)
        guard let data = Data(base64Encoded: encodedHardwareModel) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hardwareModel,
                in: container,
                debugDescription: "Failed to parse Base64 String into Data"
            )
        }
        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hardwareModel,
                in: container,
                debugDescription: "Failed to init VZMacHardwareModel from Data"
            )
        }
        self.hardwareModel = hardwareModel

        let encodedECID = try container.decode(String.self, forKey: .ecid)
        guard let data = Data(base64Encoded: encodedECID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .ecid,
                in: container,
                debugDescription: "Failed to parse Base64 String into Data"
            )
        }
        guard let ecid = VZMacMachineIdentifier(dataRepresentation: data) else {
            throw DecodingError.dataCorruptedError(
                forKey: .ecid,
                in: container,
                debugDescription: "Failed to init VZMacMachineIdentifier from Data"
            )
        }
        self.ecid = ecid
        let macAddressString = try container.decode(String.self, forKey: .macAddress)
        guard let macAddress = VZMACAddress(string: macAddressString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .macAddress,
                in: container,
                debugDescription: "Failed to init VZMACAddress from String"
            )
        }
        self.macAddress = macAddress
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(arch, forKey: .arch)
        try container.encode(os, forKey: .os)
        try container.encode(macAddress.string, forKey: .macAddress)
        try container.encode(ecid.dataRepresentation.base64EncodedString(), forKey: .ecid)
        try container.encode(hardwareModel.dataRepresentation.base64EncodedString(), forKey: .hardwareModel)
    }

    enum CodingKeys: CodingKey {
        case arch
        case os
        case hardwareModel
        case ecid
        case macAddress
    }

    enum Arch: String, Codable {
        case arm64
    }

    enum OS: String, Codable {
        case darwin
    }
}
