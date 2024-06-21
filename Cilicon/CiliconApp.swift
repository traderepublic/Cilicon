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
                Text("No configuration file found.\n\nPlease refer to the documentation on Github to create a configuration and restart the Cilicon.")
                    .multilineTextAlignment(.center)
            }
        }
    }
}
