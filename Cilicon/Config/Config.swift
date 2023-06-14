import Foundation

struct Config: Codable {
    internal init(provisioner: ProvisionerConfig, hardware: HardwareConfig, directoryMounts: [DirectoryMountConfig], source: VMSource, vmClonePath: String, numberOfRunsUntilHostReboot: Int? = nil, runnerName: String? = nil, editorMode: Bool, autoTransferImageVolume: String? = nil, retryDelay: Int, sshCredentials: SSHCredentials, preRun: String? = nil, postRun: String? = nil) {
        self.provisioner = provisioner
        self.hardware = hardware
        self.directoryMounts = directoryMounts
        self.source = source
        self.vmClonePath = vmClonePath
        self.numberOfRunsUntilHostReboot = numberOfRunsUntilHostReboot
        self.runnerName = runnerName
        self.editorMode = editorMode
        self.autoTransferImageVolume = autoTransferImageVolume
        self.retryDelay = retryDelay
        self.sshCredentials = sshCredentials
        self.preRun = preRun
        self.postRun = postRun
    }
    
    /// Provisioner Configuration.
    let provisioner: ProvisionerConfig
    /// Hardware Configuration.
    let hardware: HardwareConfig
    /// Directories to mount on the Guest OS.
    let directoryMounts: [DirectoryMountConfig]
    /// The path where the VM bundle is located.
    let source: VMSource
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
    
    let sshCredentials: SSHCredentials
    
    let preRun: String?
    let postRun: String?
    
    enum CodingKeys: CodingKey {
        case provisioner
        case hardware
        case directoryMounts
        case source
        case vmClonePath
        case numberOfRunsUntilHostReboot
        case runnerName
        case editorMode
        case autoTransferImageVolume
        case retryDelay
        case sshCredentials
        case preRun
        case postRun
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.provisioner = try container.decode(ProvisionerConfig.self, forKey: .provisioner)
        self.hardware = try container.decodeIfPresent(HardwareConfig.self, forKey: .hardware) ?? .default
        self.directoryMounts = try container.decodeIfPresent([DirectoryMountConfig].self, forKey: .directoryMounts) ?? []
        self.source = try container.decode(VMSource.self, forKey: .source)
        self.vmClonePath = (try container.decodeIfPresent(String.self, forKey: .vmClonePath).map { ($0 as NSString).standardizingPath }) ?? URL(filePath: NSHomeDirectory()).appending(component: "vmclone").path
        self.numberOfRunsUntilHostReboot = try container.decodeIfPresent(Int.self, forKey: .numberOfRunsUntilHostReboot)
        self.runnerName = try container.decodeIfPresent(String.self, forKey: .runnerName)
        self.editorMode = try container.decodeIfPresent(Bool.self, forKey: .editorMode) ?? false
        self.autoTransferImageVolume = try container.decodeIfPresent(String.self, forKey: .autoTransferImageVolume)
        self.retryDelay = try container.decodeIfPresent(Int.self, forKey: .retryDelay) ?? 5
        self.sshCredentials = try container.decodeIfPresent(SSHCredentials.self, forKey: .sshCredentials) ?? .default
        self.preRun = try container.decodeIfPresent(String.self, forKey: .preRun)
        self.postRun = try container.decodeIfPresent(String.self, forKey: .postRun)
    }
}

struct SSHCredentials: Codable {
    static var `default` = Self.init(username: "admin", password: "admin")
    let username: String
    let password: String
}

