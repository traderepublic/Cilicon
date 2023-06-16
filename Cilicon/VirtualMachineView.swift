import SwiftUI
import Virtualization

struct VirtualMachineView: NSViewRepresentable {
    var virtualMachine: VZVirtualMachine?

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.capturesSystemKeys = true
        return view
    }

    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        nsView.virtualMachine = virtualMachine
        nsView.window?.makeFirstResponder(nsView)
    }
}
