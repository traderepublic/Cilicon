import Foundation
import Virtualization

struct Config: Decodable {
    let machines: [MachineConfig]
    /// The path where the cloned VMs for each run are cloned to.
    /// To make use of instant cloning, this should be on the same APFS volume as the master image.
    /// Can be omitted, in which case it defaults to `~/cilicon-clones`.
    let clonePath: String?
    /// Number of runs until the Host machine reboots.
    let numberOfRunsUntilHostReboot: Int?
    /// Delay in seconds before retrying to provision the image a failed cycle.
//    let retryDelay: Int
    /// Timeout for the SSH connection.
//    let sshTimeout: Int
}

struct MachineConfig: Decodable {
    /// Unique ID of the VM
    let id: String
    /// Provisioner Configuration.
    let provisioner: ProvisionerConfig
    /// Hardware Configuration.
    let hardware: HardwareConfig
    /// Directories to mount on the Guest OS.
    let directoryMounts: [DirectoryMountConfig]
    /// The path where the VM bundle is located.
    let source: VMSource
    /// Credentials to be used when connecting via SSH.
    let sshCredentials: SSHCredentials
    /// A command to run before the provisioning commands are run.
    let preRun: String?
    /// A command to run after the provisioning commands are run.
    let postRun: String?

    enum CodingKeys: CodingKey {
        case id
        case provisioner
        case hardware
        case directoryMounts
        case source
        case runnerName
        case retryDelay
        case sshCredentials
        case preRun
        case postRun
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.provisioner = try container.decode(ProvisionerConfig.self, forKey: .provisioner)
        self.hardware = try container.decodeIfPresent(HardwareConfig.self, forKey: .hardware) ?? .default
        self.directoryMounts = try container.decodeIfPresent([DirectoryMountConfig].self, forKey: .directoryMounts) ?? []
        self.source = try container.decode(VMSource.self, forKey: .source)
        self.sshCredentials = try container.decodeIfPresent(SSHCredentials.self, forKey: .sshCredentials) ?? .default
        self.preRun = try container.decodeIfPresent(String.self, forKey: .preRun)
        self.postRun = try container.decodeIfPresent(String.self, forKey: .postRun)
    }
}

struct SSHCredentials: Codable {
    static var `default` = Self(username: "admin", password: "admin")
    let username: String
    let password: String
}
