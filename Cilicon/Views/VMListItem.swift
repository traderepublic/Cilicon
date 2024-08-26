import SwiftUI

struct VMListItem: View {
    @Bindable
    var vmRunner: VMRunner
    @State
    var showingPopover = false
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        HStack(alignment: .center) {
            Circle().fill(vmRunner.state.color).frame(width: 10)
            if case let .running(vm, _) = vmRunner.state {
                VirtualMachineView(virtualMachine: vm)
                    .frame(width: 110, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            } else {
                Rectangle()
                    .fill(.black)
                    .frame(width: 110, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, content: {
                Text(vmRunner.machineConfig.id).font(.headline)
                Text(vmRunner.machineConfig.source.uiRepresentation).fontDesign(.monospaced)
                    .font(.subheadline)
                    .truncationMode(.middle)
                    .lineLimit(1)
                Text("Provisioner: \(vmRunner.machineConfig.provisioner.uiRepresentation)").font(.footnote)
                Text("Status: \(vmRunner.state.description)").font(.footnote)
            }).frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, content: {
                Button(action: {
                    vmRunner.forceStop()
                }) {
                    Image(systemName: "restart").frame(maxWidth: .infinity)
                }.disabled(!vmRunner.state.isRunning)
                Button(action: {
                    openWindow(id: "log-window", value: vmRunner.machineConfig.id)
                }) {
                    Image(systemName: "text.justify")
                        .frame(maxWidth: .infinity)
                }.disabled(!vmRunner.state.isRunning)
                Button(action: {
                    openWindow(id: "display-window", value: vmRunner.machineConfig.id)
                }) {
                    Image(systemName: "display")
                        .frame(maxWidth: .infinity)
                }.disabled(!vmRunner.state.isRunning)
            }).fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 100)
    }
}

extension VMRunner.State {
    var color: Color {
        switch self {
        case .idle, .cloning:
            return .red
        case .fetching:
            return .purple
        case let .running(_, inner):
            switch inner {
            case .connecting, .shutdown:
                return .orange
            default:
                return .green
            }
        default:
            return .red
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case let .running(_, inner):
            switch inner {
            case .provisioning:
                return "Running"
            case .preRun:
                return "Pre Run Script"
            case .connecting:
                return "Connecting"
            case .postRun:
                return "Post Run Script"
            case .shutdown:
                return "Shutting down"
            }
        case .fetching:
            return "Awaiting Image"
        case .cloning:
            return "Copying"
        case .cleanup:
            return "Cleanup"
        case let .failed(description):
            return description
        case .stopping:
            return "Stopping"
        case .canceled:
            return "Canceled"
        }
    }
}
