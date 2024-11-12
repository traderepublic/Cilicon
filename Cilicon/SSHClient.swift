import Citadel

enum SSHClientCommandOutput {
    case stdout(String)
    case stderr(String)
}

protocol SSHClient {
    func connect(ip: String, username: String, password: String) async throws
    func close() async throws
    func executeCommandStream(
        _ command: String
    ) async throws -> AsyncThrowingStream<SSHClientCommandOutput, Error>
}

class BinarySSHClient: SSHClient {
    struct ConnectInfo {
        let ip: String
        let username: String
        let password: String
    }
    var connectInfo: ConnectInfo?

    func connect(ip: String, username: String, password: String) async throws {
        connectInfo = ConnectInfo(ip: ip, username: username, password: password)
    }

    func close() async throws {
        connectInfo = nil
    }

    func executeCommandStream(
        _ command: String
    ) async throws -> AsyncThrowingStream<SSHClientCommandOutput, Error> {
        guard let connectInfo else {
            fatalError("BinarySSHClient missing connectInfo")
        }

        let task = Process()
        let pipe = Pipe()
        let inputPipe = Pipe()

        task.standardInput = inputPipe
        task.standardOutput = pipe
        task.standardError = pipe
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "/opt/homebrew/bin/sshpass -p \(connectInfo.password) ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=300 -o ServerAliveCountMax=2 \(connectInfo.username)@\(connectInfo.ip) 'bash -l'"]
        task.launch()

        inputPipe.fileHandleForWriting.write(command.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()

        return AsyncThrowingStream { continuation in
            Task {
                for try await line in pipe.fileHandleForReading.bytes.lines {
                    // TODO distingish stdout vs stderr
                    continuation.yield(.stdout(line + "\n"))
                }
                continuation.onTermination = { _ in
                    task.terminate()
                }
                continuation.finish()
            }
        }
    }
}

class CitadelSSHClient: SSHClient {
    enum Error: Swift.Error {
        case clientNotPresent
    }

    var client: Citadel.SSHClient?

    func connect(ip: String, username: String, password: String) async throws {
        client = try await Citadel.SSHClient.connect(
            host: ip,
            authenticationMethod: .passwordBased(
                username: username,
                password: password
            ),
            hostKeyValidator: .acceptAnything(),
            reconnect: .always
        )
    }

    func close() async throws {
        try await client?.close()
        client = nil
    }

    func executeCommandStream(
        _ command: String
    ) async throws -> AsyncThrowingStream<SSHClientCommandOutput, Swift.Error> {
        guard let client else {
            fatalError("CitadelSSHClient missing client")
        }

        return AsyncThrowingStream { continuation in
            Task {
                for try await output in try await client.executeCommandStream(command, inShell: true) {
                    switch output {
                    case let .stdout(buffer):
                        continuation.yield(.stdout(String(buffer: buffer)))
                    case let .stderr(buffer):
                        continuation.yield(.stderr(String(buffer: buffer)))
                    }
                }
                continuation.finish()
            }
        }
    }
}
