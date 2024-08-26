import Citadel
import Foundation

protocol Provisioner {
    func provision(sshClient: SSHClient, sshLogger: SSHLogger) async throws
}

extension Provisioner {
    func shutdown(sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        try await runCommand(cmd: "nohup \"shutdown -h now\" &", sshClient: sshClient, sshLogger: sshLogger)
    }

    func runCommand(cmd: String, sshClient: SSHClient, sshLogger: SSHLogger) async throws {
        try Task.checkCancellation()
        let streamOutput = try await sshClient.executeCommandStream(cmd, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                sshLogger.log(buffer: stdout)
            case let .stderr(stderr):
                sshLogger.log(buffer: stderr)
            }
        }
    }
}
