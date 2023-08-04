import SwiftUI
import Yams
@main
struct CiliconApp: App {
    @State private var vmSource: String = ""

    var body: some Scene {
        Window("Cilicon", id: "cihost") {
            if ConfigManager.fileExists {
                switch Result(catching: { try ConfigManager().config }) {
                case let .success(config):
                    let contentView = ContentView(config: config)
                    AnyView(contentView)
                case let .failure(error):
                    Text(String(describing: error))
                }

            } else {
                Text("No Config found.\n\nTo create one, enter the path or an OCI image starting with oci:// below and press return")
                    .multilineTextAlignment(.center)
                TextField(
                    "VM Source. Enter the VM path or an OCI image starting with oci://",
                    text: $vmSource
                )
                .frame(width: 500)
                .onSubmit {
                    guard let source = VMSource(string: vmSource) else {
                        return
                    }
                    let scriptConfig = ScriptProvisionerConfig(run: "echo Hello World && sleep 10 && echo Shutting down")
                    let config = Config(
                        provisioner: .script(scriptConfig),
                        hardware: .init(
                            ramGigabytes: 8,
                            display: .default,
                            connectsToAudioDevice: false
                        ),
                        directoryMounts: [],
                        source: source,
                        vmClonePath: URL(filePath: NSHomeDirectory()).appending(component: "vmclone").path,
                        editorMode: false,
                        retryDelay: 3,
                        sshCredentials: .init(username: "admin", password: "admin")
                    )

                    try? YAMLEncoder().encode(config).write(toFile: ConfigManager.configPaths[0], atomically: true, encoding: .utf8)
                    restart()
                }
            }
        }
    }
}

extension App {
    func restart() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }
}
