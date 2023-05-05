import Foundation
import Citadel

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
        guard let installation = try await service.getInstallations().first(where: { $0.account.login == gitHubConfig.organization }) else {
            throw GitHubActionsProvisionerError.githubAppNotInstalled(appID: appId, org: org)
        }
        let authToken = try await service.getInstallationToken(installation: installation)
        let token = try await service.createRunnerToken(token: authToken.token)
        
        var configCommandComponents = [
            "~/actions-runner/config.sh",
            "--url \(gitHubConfig.organizationURL)",
            "--name \(runnerName)",
            "--token \(token.token)",
            "--replace",
            "--ephemeral",
            "--work _work",
            "--unattended",
        ]
        
        if let group = gitHubConfig.runnerGroup {
            configCommandComponents.append("--runnergroup \(group)")
        }
        
        if let labels = gitHubConfig.extraLabels {
            configCommandComponents.append("--labels \(labels.joined(separator: ","))")
        }
        
        let configCommand = configCommandComponents.joined(separator: " ")
        let runCommand = "~/actions-runner/run.sh"
        let command = [configCommand, runCommand].joined(separator: " && ")
        
        let streams = try await sshClient.executeCommandStream(command)
        var asyncStreams = streams.makeAsyncIterator()
        
        while let blob = try await asyncStreams.next() {
            switch blob {
            case .stdout(let stdout):
                await SSHLogger.shared.log(string: String(buffer: stdout))
            case .stderr(let stderr):
                await SSHLogger.shared.log(string: String(buffer: stderr))
            }
        }
    }
    
    private func setRegistrationToken(bundle: VMBundle, authToken: AccessToken) async throws {
        
        let actionsToken = try await service.createRunnerToken(token: authToken.token)
        
        let runnerToken = actionsToken.token.data(using: .utf8)
        let tokenPath = bundle.runnerTokenURL.relativePath
        guard fileManager.createFile(atPath: tokenPath, contents: runnerToken) else {
            throw GitHubActionsProvisionerError.couldNotCreateRunnerTokenFile(path: tokenPath)
        }
    }
    
    private func setRunnerName(bundle: VMBundle) throws {
        let namePath = bundle.runnerNameURL.relativePath
        guard fileManager.createFile(atPath: namePath, contents: runnerName.data(using: .utf8)!) else {
            throw GitHubActionsProvisionerError.couldNotCreateRunnerNameFile(path: namePath)
        }
    }
    
    private func setRunnerLabels(bundle: VMBundle) throws {
        let labels = [
            runnerName,
            "\(config.hardware.ramGigabytes)-gb-ram",
            "\(config.hardware.cpuCores ?? ProcessInfo.processInfo.processorCount)-cores"
        ] + (gitHubConfig.extraLabels ?? [])
        let labelsPath = bundle.runnerLabelsURL.relativePath
        let joinedLabels = labels.joined(separator: ",")
        guard fileManager.createFile(atPath: labelsPath, contents: joinedLabels.data(using: .utf8)!) else {
            throw GitHubActionsProvisionerError.couldNotCreateLabelsFile(path: labelsPath)
        }
    }
    
    private func setRunnerDownloadURL(bundle: VMBundle, authToken: AccessToken) async throws {
        let downloadURLs = try await service.getRunnerDownloadURLs(authToken: authToken)
        guard let macURL = downloadURLs.first(where: { $0.os == "osx" && $0.architecture == "arm64" }) else {
            throw GitHubActionsProvisionerError.couldNotFindRunnerDownloadURL
        }
        let downloadURLPath = bundle.runnerDownloadURL.relativePath
        guard fileManager.createFile(atPath: downloadURLPath, contents: macURL.downloadUrl.absoluteString.data(using: .utf8)!) else {
            throw GitHubActionsProvisionerError.couldNotCreateRunnerURLFile(path: downloadURLPath)
        }
    }
}

enum GitHubActionsProvisionerError: Error {
    case githubAppNotInstalled(appID: Int, org: String)
    case couldNotCreateRunnerTokenFile(path: String)
    case couldNotCreateRunnerNameFile(path: String)
    case couldNotCreateLabelsFile(path: String)
    case couldNotCreateRunnerURLFile(path: String)
    case couldNotFindRunnerDownloadURL
}

extension GitHubActionsProvisionerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .githubAppNotInstalled(appId, org):
            return "No installations found for \(appId) on \(org) organization"
        case let .couldNotCreateRunnerTokenFile(path):
            return "Could not create Runner Token File at \(path)"
        case let .couldNotCreateRunnerNameFile(path):
            return "Could not create Runner Name File at \(path)"
        case let .couldNotCreateLabelsFile(path):
            return "Could not create Labels Name File at \(path)"
        case let .couldNotCreateRunnerURLFile(path):
            return "Could not create Runner URL File at \(path)"
        case .couldNotFindRunnerDownloadURL:
            return "Could not find runner download URL"
        }
    }
}

fileprivate extension VMBundle {
    var runnerNameURL: URL {
        resourcesURL.appending(component: "RUNNER_NAME")
    }
    
    var runnerTokenURL: URL {
        resourcesURL.appending(component: "RUNNER_TOKEN")
    }
    
    var runnerLabelsURL: URL {
        resourcesURL.appending(component: "RUNNER_LABELS")
    }
    
    var runnerDownloadURL: URL {
        resourcesURL.appending(component: "RUNNER_DOWNLOAD_URL")
    }
}
