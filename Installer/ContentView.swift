import SwiftUI
import UniformTypeIdentifiers

let ipswType = UTType("com.apple.itunes.ipsw")!

struct ContentView: View {
    @ObservedObject
    var installer = Installer()
    @State
    private var diskSize: String = "64"
    @State
    private var bundlePath: String = NSHomeDirectory() + "/VM.bundle"
    @State
    private var selectingIPSW: Bool = false

    let progressFormatter: NumberFormatter = {
        let numFormatter = NumberFormatter()
        numFormatter.numberStyle = .percent
        return numFormatter
    }()

    let throughputFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.minimumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        VStack(spacing: 20) {
            switch installer.state {
            case .idle:
                Form {
                    TextField(text: $diskSize) {
                        Text("Disk Space (GB)")
                    }
                    TextField(text: $bundlePath) {
                        Text("Bundle Path")
                    }
                }
                HStack {
                    Button(action: { selectingIPSW = true }) {
                        Text("Install from IPSW file")
                    }.fileImporter(
                        isPresented: $selectingIPSW,
                        allowedContentTypes: [ipswType],
                        allowsMultipleSelection: false
                    ) { result in
                        selectingIPSW = false
                        if case let .success(fileURLs) = result, let fileURL = fileURLs.first {
                            handleInstall(ipswURL: fileURL)
                        }
                    }
                    Button(action: handleDownload) {
                        Text("Download latest Image")
                    }
                }
            case .done:
                Text("Successfully installed image 🥳")
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                }
            case let .error(error):
                Text("🧐 \(error)")
                Button(action: { installer.state = .idle }) {
                    Text("Back")
                }
            case let .downloading(version, progress):
                let formattedProgress = progressFormatter.string(from: progress as NSNumber)!
                ProgressView(value: progress) {
                    Text("Downloading image \(version): \(formattedProgress)")
                }
            case let .installing(progress):
                let formattedProgress = progressFormatter.string(from: progress as NSNumber)!
                ProgressView(value: progress) {
                    Text("Installing image: \(formattedProgress)")
                }
            }
        }
        .padding(.all, 20)
        .frame(width: 400, height: 150, alignment: .center)
    }

    func handleDownload() {
        let mode: InstallMode = .downloadAndInstall(downloadFolder: URL(filePath: NSHomeDirectory() + "/Downloads"))
        startInstaller(mode: mode)
    }

    func handleInstall(ipswURL: URL) {
        let mode: InstallMode = .installFromImage(restoreImage: ipswURL)
        startInstaller(mode: mode)
    }

    func startInstaller(mode: InstallMode) {
        let bundle = VMBundle(url: URL(filePath: bundlePath))
        installer.run(mode: mode, bundle: bundle, diskSize: Int64(diskSize)!)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
