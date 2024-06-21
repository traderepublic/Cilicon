import Citadel
import Foundation

class GithubActionsProvisioner: Provisioner {
    let config: Config
    let githubConfig: GithubProvisionerConfig
    let service: GithubService
    let fileManager: FileManager

    init(config: Config, githubConfig: GithubProvisionerConfig, fileManager: FileManager = .default) {
        self.config = config
        self.githubConfig = githubConfig
        self.service = GithubService(config: githubConfig)
        self.fileManager = fileManager
    }

    var runnerName: String {
        config.runnerName ?? Host.current().localizedName ?? "no-name"
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        await SSHLogger.shared.log(string: "[1;35mFetching Github Runner Token[0m\n")

        let authToken = try await service.getAuthToken()
        let runnerToken = try await service.createRunnerToken(token: authToken)
        var command = ""
        if githubConfig.downloadLatest {
            let downloadURLs = try await service.getRunnerDownloadURLs(authToken: authToken)
            guard let macURL = downloadURLs.first(where: { $0.os == "osx" && $0.architecture == "arm64" }) else {
                throw GithubActionsProvisionerError.couldNotFindRunnerDownloadURL
            }

            let downloadCommands = [
                "curl -o actions-runner.tar.gz -L \(macURL.downloadUrl.absoluteString)",
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

        if let group = githubConfig.runnerGroup {
            configCommandComponents.append("--runnergroup '\(group)'")
        }

        if let labels = githubConfig.extraLabels {
            configCommandComponents.append("--labels \(labels.joined(separator: ","))")
        }

        if let workFolder = githubConfig.workFolder {
            configCommandComponents.append("--work '\(workFolder)'")
        }

        let configCommand = configCommandComponents.joined(separator: " ")
        let runCommand = "~/actions-runner/run.sh"
        command += [configCommand, runCommand].joined(separator: " && ")

        let streamOutput = try await sshClient.executeCommandStream(command, inShell: true)

        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                await SSHLogger.shared.log(string: String(buffer: stdout))
            case let .stderr(stderr):
                await SSHLogger.shared.log(string: String(buffer: stderr))
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
