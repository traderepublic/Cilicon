import Foundation

struct VMBundle {
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
    
    var configuration: VMConfig {
        let tartConfigData = try! Data(contentsOf: configURL)
        return try! JSONDecoder().decode(VMConfig.self, from: tartConfigData)
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

extension URL {
    func createIfNotExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.relativePath) {
            try fileManager.createDirectory(at: self, withIntermediateDirectories: true)
        }
    }
}
