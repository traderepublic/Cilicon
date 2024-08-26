import SwiftUI
import Virtualization

struct VMDisplayView: View {
    var coreApp: CiliconCoreApp

    let vmId: VMRunner.ID

    var vmRunner: VMRunner? {
        coreApp.vmRunners.first(where: { $0.id == vmId })
    }

    var virtualMachine: VZVirtualMachine? {
        if case let .running(vm, _) = vmRunner?.state {
            return vm
        }
        return nil
    }

    var body: some View {
        VirtualMachineView(virtualMachine: virtualMachine).navigationTitle("Display - \(vmRunner?.machineConfig.id ?? "")")
    }
}
