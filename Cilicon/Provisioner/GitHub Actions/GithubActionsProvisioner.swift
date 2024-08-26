import Citadel
import Foundation

class GithubActionsProvisioner: Provisioner {
    let githubConfig: GithubProvisionerConfig
    let service: GithubService
    let fileManager: FileManager
    let runnerName: String
    let config: MachineConfig

    init(config: MachineConfig, githubConfig: GithubProvisionerConfig, fileManager: FileManager = .default) {
        self.githubConfig = githubConfig
        self.service = GithubService(config: githubConfig)
        self.fileManager = fileManager
        self.config = config
        self.runnerName = githubConfig.runnerName ?? Host.current().localizedName ?? "" + "-\(config.id)"
    }

    func provision(sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        let authToken = try await service.getAuthToken()
        let runnerToken = try await service.createRunnerToken(token: authToken)
        var command = ""
        if githubConfig.downloadLatest {
            let downloadURLs = try await service.getRunnerDownloadURLs(authToken: authToken)
            guard let macURL = downloadURLs.first(where: { $0.os == "osx" && $0.architecture == "arm64" }) else {
                throw GithubActionsProvisionerError.couldNotFindRunnerDownloadURL
            }

            let downloadCommands = [
                "echo 'Downloading Actions Runner'",
                "curl -so actions-runner.tar.gz -L \(macURL.downloadUrl.absoluteString)",
                "rm -rf ~/actions-runner",
                "mkdir ~/actions-runner",
                "tar xzf ./actions-runner.tar.gz --directory ~/actions-runner"
            ]
            command += downloadCommands.joined(separator: " && ") + " && "
        }

        var configCommandComponents = [
            "~/actions-runner/config.sh",
            "--url \(githubConfig.url)",
            "--name '\(runnerName)'",
            "--token \(runnerToken.token)",
            "--replace",
            "--ephemeral",
            "--unattended"
        ]
        // Runner Group
        if let group = githubConfig.runnerGroup {
            configCommandComponents.append("--runnergroup '\(group)'")
        }

        // Labels
        var labels = [String]()
        if let version = Bundle
            .main
            .infoDictionary?["CFBundleShortVersionString"] as? String {
            labels.append("cilicon-\(version)")
        }
        if case let .OCI(oci) = config.source {
            labels.append("\(oci.repository):\(oci.tag)")
        }
        labels += githubConfig.extraLabels ?? []
        configCommandComponents.append("--labels \(labels.joined(separator: ","))")

        // Work Folder
        if let workFolder = githubConfig.workFolder {
            configCommandComponents.append("--work '\(workFolder)'")
        }

        // Config
        let configCommand = configCommandComponents.joined(separator: " ")
        let runCommand = "~/actions-runner/run.sh"
        command += [configCommand, runCommand].joined(separator: " && ")

        let streamOutput = try await sshClient.executeCommandStream(command, inShell: true)

        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                sshLogger.log(string: String(buffer: stdout))
            case let .stderr(stderr):
                sshLogger.log(string: String(buffer: stderr))
            }
        }
    }
}

enum GithubActionsProvisionerError: Error {
    case githubAppNotInstalled(appID: Int, org: String)
    case couldNotFindRunnerDownloadURL
}

extension GithubActionsProvisionerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .githubAppNotInstalled(appId, org):
            return "No installations found for \(appId) on \(org) organization"
        case .couldNotFindRunnerDownloadURL:
            return "Could not find runner download URL"
        }
    }
}

struct GithubJitPayload: Encodable {
    let name: String?
    let runnerGroupId: Int?
    let labels: [String]?
    let workFolder: String?
}
