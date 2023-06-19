import Citadel
import Foundation

class GitHubActionsProvisioner: Provisioner {
    let config: Config
    let gitHubConfig: GitHubProvisionerConfig
    let service: GitHubService
    let fileManager: FileManager

    init(config: Config, gitHubConfig: GitHubProvisionerConfig, fileManager: FileManager = .default) {
        self.config = config
        self.gitHubConfig = gitHubConfig
        self.service = GitHubService(config: gitHubConfig)
        self.fileManager = fileManager
    }

    var runnerName: String {
        config.runnerName ?? Host.current().localizedName ?? "no-name"
    }

    func provision(bundle: VMBundle, sshClient: SSHClient) async throws {
        let org = gitHubConfig.organization
        let appId = gitHubConfig.appId
        await SSHLogger.shared.log(string: "[1;35mFetching Github Runner Token[0m\n")
        guard let installation = try await service.getInstallations().first(where: { $0.account.login == gitHubConfig.organization }) else {
            throw GitHubActionsProvisionerError.githubAppNotInstalled(appID: appId, org: org)
        }
        let authToken = try await service.getInstallationToken(installation: installation)
        let token = try await service.createRunnerToken(token: authToken.token)

        var command = ""
        if gitHubConfig.downloadLatest {
            let downloadURLs = try await service.getRunnerDownloadURLs(authToken: authToken)
            guard let macURL = downloadURLs.first(where: { $0.os == "osx" && $0.architecture == "arm64" }) else {
                throw GitHubActionsProvisionerError.couldNotFindRunnerDownloadURL
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
            "--url \(gitHubConfig.organizationURL)",
            "--name '\(runnerName)'",
            "--token \(token.token)",
            "--replace",
            "--ephemeral",
            "--work _work",
            "--unattended",
        ]

        if let group = gitHubConfig.runnerGroup {
            configCommandComponents.append("--runnergroup '\(group)'")
        }

        if let labels = gitHubConfig.extraLabels {
            configCommandComponents.append("--labels \(labels.joined(separator: ","))")
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

enum GitHubActionsProvisionerError: Error {
    case githubAppNotInstalled(appID: Int, org: String)
    case couldNotFindRunnerDownloadURL
}

extension GitHubActionsProvisionerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .githubAppNotInstalled(appId, org):
            return "No installations found for \(appId) on \(org) organization"
        case .couldNotFindRunnerDownloadURL:
            return "Could not find runner download URL"
        }
    }
}
