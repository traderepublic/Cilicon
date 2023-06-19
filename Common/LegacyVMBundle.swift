import Foundation
import Virtualization

struct LegacyVMBundle {
    let url: URL

    var diskImageURL: URL {
        url.appending(component: "Disk.img")
    }

    var auxiliaryStorageURL: URL {
        url.appending(component: "AuxiliaryStorage")
    }

    var machineIdentifierURL: URL {
        url.appending(component: "MachineIdentifier")
    }

    var hardwareModelURL: URL {
        url.appending(component: "HardwareModel")
    }

    func upgrade() throws {
        let fileManager = FileManager.default
        let newBundle = VMBundle(url: url)
        try fileManager.moveItem(at: diskImageURL, to: newBundle.diskImageURL)
        try fileManager.moveItem(at: auxiliaryStorageURL, to: newBundle.auxiliaryStorageURL)
        let hardwareModelData = try Data(contentsOf: hardwareModelURL)
        let machineIdentifierData = try Data(contentsOf: machineIdentifierURL)
        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            fatalError()
        }
        let config = VMConfig(
            arch: .arm64,
            os: .darwin,
            hardwareModel: hardwareModel,
            ecid: machineIdentifier,
            macAddress: VZMACAddress.randomLocallyAdministered()
        )
        try JSONEncoder().encode(config).write(to: newBundle.configURL)
    }
}
