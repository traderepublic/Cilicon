import SwiftUI

@main
struct CiliconApp: App {
    let config = Result {
        try ConfigManager().config
    }
    
    var body: some Scene {
        Window("Cilicon", id: "cihost") {
            switch config {
            case .success(let config):
                let contentView = ContentView(config: config)
                AnyView(contentView)
            case .failure(let error):
                AnyView(Text(error.localizedDescription))
            }
        }
    }
}
