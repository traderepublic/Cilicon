import Foundation
import Virtualization

extension VMConfigHelper {
    public func computeRunConfiguration(config: Config) throws -> VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        virtualMachineConfiguration.platform = try parseMacPlatform()
        virtualMachineConfiguration.bootLoader = VZMacOSBootLoader()
        virtualMachineConfiguration.cpuCount = computeCPUCount(cpuCount: config.hardware.cpuCores)
        virtualMachineConfiguration.memorySize = computeMemorySize(desiredRam: config.hardware.ramGigabytes)
        let dispConfig = config.hardware.display
        virtualMachineConfiguration.graphicsDevices = [
            createGraphicsDeviceConfiguration(
                width: dispConfig.width,
                height: dispConfig.height,
                ppi: dispConfig.pixelsPerInch
            )
        ]
        virtualMachineConfiguration.storageDevices = try [createBlockDeviceConfiguration()]
        virtualMachineConfiguration.networkDevices = [createNetworkDeviceConfiguration(mac: vmBundle.configuration.macAddress)]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        if config.hardware.connectsToAudioDevice {
            virtualMachineConfiguration.audioDevices = [createAudioDeviceConfiguration()]
        }
        virtualMachineConfiguration.directorySharingDevices = try [createDirectorySharingConfiguration(config: config)]

        for consoleDeviceConfig in config.consoleDevices {
            let consolePort = VZVirtioConsolePortConfiguration()
            consolePort.name = consoleDeviceConfig
            let consoleDevice = VZVirtioConsoleDeviceConfiguration()
            consoleDevice.ports[0] = consolePort
            virtualMachineConfiguration.consoleDevices.append(consoleDevice)
        }

        try virtualMachineConfiguration.validate()

        return virtualMachineConfiguration
    }

    private func createDirectorySharingConfiguration(config: Config) throws -> VZVirtioFileSystemDeviceConfiguration {
        var directoriesToShare = [String: VZSharedDirectory]()
        for mountConfig in config.directoryMounts {
            if !FileManager.default.fileExists(atPath: mountConfig.hostPath) {
                try FileManager.default.createDirectory(atPath: mountConfig.hostPath, withIntermediateDirectories: true)
            }
            let mountDirectory = VZSharedDirectory(
                url: URL(fileURLWithPath: mountConfig.hostPath),
                readOnly: mountConfig.readOnly
            )
            directoriesToShare[mountConfig.guestFolder] = mountDirectory
        }

        let multipleDirectoryShare = VZMultipleDirectoryShare(directories: directoriesToShare)

        // Assign the automount tag to this share. macOS shares automounted directories automatically under /Volumes in the guest.
        let sharingConfiguration = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
        sharingConfiguration.share = multipleDirectoryShare
        return sharingConfiguration
    }
}
