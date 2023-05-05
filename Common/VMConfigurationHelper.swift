import Foundation
import Virtualization

class VMConfigHelper {
    let vmBundle: VMBundle
    init(vmBundle: VMBundle) {
        self.vmBundle = vmBundle
    }
    
    func computeInstallConfiguration(macOSConfiguration: VZMacOSConfigurationRequirements) throws -> VZVirtualMachineConfiguration {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()
        
        virtualMachineConfiguration.platform = try createMacPlatform(macOSConfiguration: macOSConfiguration)
        virtualMachineConfiguration.cpuCount = computeCPUCount()
        if virtualMachineConfiguration.cpuCount < macOSConfiguration.minimumSupportedCPUCount {
            throw VMConfigHelperError.error("CPUCount isn't supported by the macOS configuration.")
        }
        
        virtualMachineConfiguration.memorySize = computeMemorySize()
        if virtualMachineConfiguration.memorySize < macOSConfiguration.minimumSupportedMemorySize {
            throw VMConfigHelperError.error("memorySize isn't supported by the macOS configuration.")
        }
        
        virtualMachineConfiguration.bootLoader = VZMacOSBootLoader()
        virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration(width: 1080, height: 920, ppi: 80)]
        
        virtualMachineConfiguration.storageDevices = [try createBlockDeviceConfiguration()]
        
        
        virtualMachineConfiguration.networkDevices = [createNetworkDeviceConfiguration(mac: vmBundle.configuration.macAddress)]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        virtualMachineConfiguration.audioDevices = [createAudioDeviceConfiguration()]
        
        try virtualMachineConfiguration.validate()
        return virtualMachineConfiguration
    }
    
    
    func createMacPlatform(macOSConfiguration: VZMacOSConfigurationRequirements) throws -> VZMacPlatformConfiguration {
        fatalError()
//        guard case .cilicon(let ciliconBundle) = vmBundle else {
//            throw VMConfigHelperError.error("Tried to create a bundle of type other than cilicon")
//        }
//        let macPlatformConfiguration = VZMacPlatformConfiguration()
//
//        let auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: ciliconBundle.auxiliaryStorageURL,
//                                                         hardwareModel: macOSConfiguration.hardwareModel,
//                                                         options: [])
//        macPlatformConfiguration.auxiliaryStorage = auxiliaryStorage
//        macPlatformConfiguration.hardwareModel = macOSConfiguration.hardwareModel
//        macPlatformConfiguration.machineIdentifier = VZMacMachineIdentifier()
//
//        // Store the hardware model and machine identifier to disk so that we
//        // can retrieve them for subsequent boots.
//
//        try! macPlatformConfiguration.hardwareModel.dataRepresentation.write(to: ciliconBundle.hardwareModelURL)
//        try! macPlatformConfiguration.machineIdentifier.dataRepresentation.write(to: ciliconBundle.machineIdentifierURL)
//
//        return macPlatformConfiguration
    }
    
    func parseMacPlatform() throws -> VZMacPlatformConfiguration {
        let macPlatform = VZMacPlatformConfiguration()
        let auxiliaryStorage = VZMacAuxiliaryStorage(contentsOf: vmBundle.auxiliaryStorageURL)
        macPlatform.auxiliaryStorage = auxiliaryStorage
        
        let hardwareModel = vmBundle.configuration.hardwareModel
        if !hardwareModel.isSupported {
            throw VMConfigHelperError.error("The hardware model isn't supported on the current host")
        }
        macPlatform.hardwareModel = hardwareModel
        macPlatform.machineIdentifier = vmBundle.configuration.ecid
        
        return macPlatform
    }
    
    
    func computeCPUCount(cpuCount: Int? = nil) -> Int {
        var virtualCPUCount = cpuCount ?? ProcessInfo.processInfo.processorCount
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)
        return virtualCPUCount
    }
    
    func computeMemorySize(desiredRam: UInt64 = 4) -> UInt64 {
        var memorySize = (desiredRam * 1024 * 1024 * 1024) as UInt64
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)
        return memorySize
    }
    
    func createGraphicsDeviceConfiguration(width: Int, height: Int, ppi: Int) -> VZMacGraphicsDeviceConfiguration {
        let graphicsConfiguration = VZMacGraphicsDeviceConfiguration()
        graphicsConfiguration.displays = [
            VZMacGraphicsDisplayConfiguration(widthInPixels: width, heightInPixels: height, pixelsPerInch: ppi)
        ]
        return graphicsConfiguration
    }
    
    func createBlockDeviceConfiguration() throws -> VZVirtioBlockDeviceConfiguration {
        let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(url: vmBundle.diskImageURL, readOnly: false)
        let disk = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
        return disk
    }
    
    func createNetworkDeviceConfiguration(mac: VZMACAddress?) -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        
        let networkAttachment = VZNATNetworkDeviceAttachment()
        networkDevice.attachment = networkAttachment
        if let mac = mac {
            networkDevice.macAddress = mac
        }
        return networkDevice
    }
    
    func createAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let audioConfiguration = VZVirtioSoundDeviceConfiguration()
        
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        
        audioConfiguration.streams = [inputStream, outputStream]
        return audioConfiguration
    }
}

enum VMConfigHelperError: LocalizedError {
    case error(String)
    
    var errorDescription: String? {
        switch self {
        case .error(let errorText):
            return errorText
        }
    }
}
