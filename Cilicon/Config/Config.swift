import Foundation

struct Config: Decodable {
    /// Provisioner Configuration.
    let provisioner: ProvisionerConfig
    /// Hardware Configuration.
    let hardware: HardwareConfig
    /// Directories to mount on the Guest OS.
    let directoryMounts: [DirectoryMountConfig]
    /// The path where the VM bundle is located.
    let vmBundleType: VMBundleType
    let vmBundlePath: String
    /// The path where the cloned VM bundle for each run is located.
    /// This should be on the same APFS volume as `vmBundlePath`.
    /// Can be omitted, in which case it defaults to `~/EphemeralVM.bundle`.
    let vmClonePath: String
    /// Number of runs until the Host machine reboots.
    let numberOfRunsUntilHostReboot: Int?
    /// Overrides the runner name chosen by the provisioner.
    let runnerName: String?
    /// Does not copy the VM bundle and mounts the `Editor Resources` folder contained in the bundle on the guest machine.
    let editorMode: Bool
    /// A volume from which's root directory to transfer a `VM.bundle` to the `vmBundlePath` automatically.
    /// The volume is automatically unmounted after the copying process is complete.
    /// Start and End of the copying phase are signaled with system sounds.
    /// Must be the full path including `/Volumes/`.
    let autoTransferImageVolume: String?
    /// Delay in seconds before retrying to provision the image a failed cycle
    let retryDelay: Int
    
    enum CodingKeys: CodingKey {
        case provisioner
        case hardware
        case directoryMounts
        case vmBundleType
        case vmBundlePath
        case vmClonePath
        case numberOfRunsUntilHostReboot
        case runnerName
        case editorMode
        case autoTransferImageVolume
        case retryDelay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.provisioner = try container.decode(ProvisionerConfig.self, forKey: .provisioner)
        self.hardware = try container.decode(HardwareConfig.self, forKey: .hardware)
        self.directoryMounts = try container.decodeIfPresent([DirectoryMountConfig].self, forKey: .directoryMounts) ?? []
        self.vmBundleType = try container.decodeIfPresent(VMBundleType.self, forKey: .vmBundleType) ?? .cilicon
        self.vmBundlePath = (try container.decode(String.self, forKey: .vmBundlePath) as NSString).standardizingPath
        self.vmClonePath = (try container.decodeIfPresent(String.self, forKey: .vmClonePath).map { ($0 as NSString).standardizingPath }) ?? URL(filePath: NSHomeDirectory()).appending(component: "EphemeralVM.bundle").path
        self.numberOfRunsUntilHostReboot = try container.decodeIfPresent(Int.self, forKey: .numberOfRunsUntilHostReboot)
        self.runnerName = try container.decodeIfPresent(String.self, forKey: .runnerName)
        self.editorMode = try container.decodeIfPresent(Bool.self, forKey: .editorMode) ?? false
        self.autoTransferImageVolume = try container.decodeIfPresent(String.self, forKey: .autoTransferImageVolume)
        self.retryDelay = try container.decodeIfPresent(Int.self, forKey: .retryDelay) ?? 5
    }
}


enum VMBundleType: String, Decodable {
    case cilicon
    case tart
}
