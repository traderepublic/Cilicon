import SwiftUI
import Yams

@main
struct CiliconApp: App {
    var body: some Scene {
        Window("Cilicon", id: "cihost") {
            Group {
                switch Result(catching: { try ConfigManager().config }) {
                case let .success(config):
                    ContentView(config: config)
                case let .failure(error) where error is ConfigManagerError:
                    Text(
                        "No configuration file found.\n\n"
                            + "Please refer to the documentation on Github to create a configuration and restart the Cilicon.\n"
                            + "Try following: `open /Applications/Cilicon.app  --args -config-path User/<user>/cilicon.yml`"
                    )
                case let .failure(error):
                    Text(String(describing: error))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
