import Foundation

struct TartBundle: BundleType {
    let url: URL
    
    var resourcesURL: URL {
        url.appending(component: "Resources/")
    }
    
    var editorResourcesURL: URL {
        url.appending(component: "Editor Resources/")
    }
    
    var diskImageURL: URL {
        url.appending(component: "disk.img")
    }
    
    var auxiliaryStorageURL: URL {
        url.appending(component: "nvram.bin")
    }
    
    var configURL: URL {
        url.appending(component: "config.json")
    }
}

protocol BundleType {
    var url: URL { get }
    var resourcesURL: URL { get }
    var editorResourcesURL: URL { get }
    var diskImageURL: URL { get }
    var auxiliaryStorageURL: URL { get }
    init(url: URL)
}

enum Bundle {
    case tart(TartBundle)
    case cilicon(VMBundle)
    
    var common: BundleType {
        switch self {
        case .tart(let bundle):
            return bundle
        case .cilicon(let bundle):
            return bundle
        }
    }
    
    
}

extension URL {
    func createIfNotExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.relativePath) {
            try fileManager.createDirectory(at: self, withIntermediateDirectories: true)
        }
    }
}
