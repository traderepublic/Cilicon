import Foundation

struct VMBundle: BundleType {
    let url: URL
    
    var resourcesURL: URL {
        url.appending(component: "Resources/")
    }
    
    var editorResourcesURL: URL {
        url.appending(component: "Editor Resources/")
    }
    
    var diskImageURL: URL {
        url.appending(component: "Disk.img")
    }
    
    var auxiliaryStorageURL: URL {
        url.appending(component: "AuxiliaryStorage")
    }
    
    var machineIdentifierURL: URL {
        url.appending(component: "MachineIdentifier")
    }
    
    var hardwareModelURL: URL {
        url.appending(component: "HardwareModel")
    }
}
