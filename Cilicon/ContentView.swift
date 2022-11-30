import SwiftUI
import Virtualization

struct ContentView: View {
    @ObservedObject
    var vmManager: VMManager
    let title: String
    let config: Config
    
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
        HStack {
            switch vmManager.vmState {
            case .running(let vm):
                VirtualMachineView(virtualMachine: vm).onAppear {
                    Task.retrying(maxRetryCount: 5, retryDelay: 5) {
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
        }
        .navigationTitle(title)
        .onAppear {
            Task.retrying(maxRetryCount: 5, retryDelay: 5) {
                await vmManager.onAppear()
            }
        }
    }
}
