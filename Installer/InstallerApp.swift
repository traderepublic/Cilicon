import SwiftUI

@main
struct InstallerApp: App {
    var body: some Scene {
        Window("Cilicon Installer", id: "cinstaller") {
            ContentView()
        }.windowResizability(.contentSize)
    }
}
