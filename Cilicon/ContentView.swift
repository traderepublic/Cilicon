import AppKit
import SwiftUI
import Virtualization

struct ContentView: View {
    @ObservedObject
    var vmManager: VMManager
    let title: String
    let config: Config
    let progressFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.minimumFractionDigits = 2
        return numberFormatter
    }()

    @ObservedObject
    var logger = SSHLogger.shared

    init(config: Config) {
        self.vmManager = VMManager(config: config)
        self.config = config
        self.title = "Cilicon"
    }

    var body: some View {
        VStack {
            switch vmManager.vmState {
            case let .running(vm):
                VirtualMachineView(virtualMachine: vm).onAppear {
                    Task.detached {
                        try await vmManager.start(vm: vm)
                    }
                }
                ScrollViewReader { scrollViewProxy in
                    ScrollView(.vertical) {
                        LazyVStack {
                            ForEach([logger], id: \.combinedLog) {
                                Text($0.attributedLog)
                                    .frame(width: 800, alignment: .leading)
                            }
                        }
                        .textSelection(.enabled)
                        .onReceive(logger.log.publisher) { _ in
                            scrollViewProxy.scrollTo(logger.combinedLog, anchor: .bottom)
                        }
                    }
                }
            case let .failed(errorDescription):
                Text(errorDescription)
            case .initializing:
                Text("Initializing")
            case .copying:
                Text("Copying Image")
            case .provisioning:
                Text("Provisioning Image")
            case .copyingFromVolume:
                Text("Copying image from external volume")
            case let .downloading(text, progress):
                let fProgress = self.progressFormatter.string(from: NSNumber(value: progress))!
                VStack {
                    Text("Downloading \(text) - \(fProgress)")
                    ProgressView(value: progress).frame(width: 500, alignment: .center)
                }
            case .legacyWarning:
                Text("The Bundle you have selected is in the legacy format. Do you want to convert it?")
                Button("Yes Please", action: vmManager.upgradeImageFromLegacy)
            case .legacyUpgradeFailed:
                Text("Upgrade from legacy VM failed")
            }
        }
        .navigationTitle(title + " - " + vmManager.ip)
        .onAppear(perform: start)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { [vmManager] _ in
            try? vmManager.cleanup()
        })
    }

    func start() {
        Task.detached {
            try await vmManager.setupAndRunVM()
        }
    }
}
