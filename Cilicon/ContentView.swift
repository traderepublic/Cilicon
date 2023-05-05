import SwiftUI
import AppKit
import Virtualization

struct ContentView: View {
    @ObservedObject
    var vmManager: VMManager
    let title: String
    let config: Config
    
    @ObservedObject
    var logger = SSHLogger.shared
    
    init(config: Config) {
        self.vmManager = VMManager(config: config)
        self.config = config
        if config.editorMode {
            self.title = "Cilicon (Editor Mode) - \(config.vmBundlePath)"
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
            }
            ScrollViewReader { scrollViewProxy in
                ScrollView(.vertical) {
                    LazyVStack {
                        ForEach(logger.log) {
                            Text($0.text)
                                .frame(width: 800, alignment: .leading)
                                .font(Font.custom("SF Mono", size: 11))
                        }
                    }
                    .onReceive(logger.log.publisher) { _ in
                        scrollViewProxy.scrollTo(logger.log.last!.id, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear(perform: onAppear)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { [vmManager] _ in
            try? vmManager.removeBundleIfExists()
        })
    }
    
    func onAppear() {
        Task.detached {
            try await vmManager.setupAndRunVM()
        }
    }
}
