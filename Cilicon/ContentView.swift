import SwiftUI
import AppKit
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
        if config.editorMode {
            self.title = "Cilicon (Editor Mode) - \(config.source.localPath)"
        } else {
            self.title = "Cilicon"
        }
    }
    
    var body: some View {
        VStack {
            switch vmManager.vmState {
            case .running(let vm):
                VirtualMachineView(virtualMachine: vm).onAppear {
                    Task.detached {
                        try await vmManager.start(vm: vm)
                    }
                }
                if !config.editorMode {
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
                }
            case .failed(let errorDescription):
                Text(errorDescription)
            case .initializing:
                Text("Initializing")
            case .copying:
                Text("Copying Image")
            case .provisioning:
                Text("Provisioning Image")
            case .copyingFromVolume:
                Text("Copying image from external volume")
            case .downloading(let text, let progress):
                let fProgress = self.progressFormatter.string(from: NSNumber(value: progress))!
                VStack {
                    Text("Downloading \(text) - \(fProgress)")
                    ProgressView(value: progress).frame(width: 500, alignment: .center)
                }
                
            }
            
        }
        .navigationTitle(title)
        .onAppear(perform: onAppear)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { [vmManager] _ in
            try? vmManager.cleanup()
        })
    }
    
    func onAppear() {
        Task.detached {
            try await vmManager.setupAndRunVM()
        }
    }
}
