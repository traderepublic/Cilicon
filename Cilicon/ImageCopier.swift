import Foundation
import AppKit

class ImageCopier {
    let config: Config
    let fileManager: FileManager = .default
    var isCopying: Bool = false
    var observer: Any?
    
    init(config: Config) {
        self.config = config
        guard let transferPath = config.autoTransferImageVolume, !config.editorMode else {
            return
        }
        
        observer = NSWorkspace.shared.notificationCenter
            .addObserver(forName: NSWorkspace.didMountNotification,
                         object: nil,
                         queue:  nil)
        { [weak self] notification in
            guard let strongSelf = self else { return }
            if let userInfo = notification.userInfo,
               let devicePath = userInfo["NSDevicePath"] as? String,
               devicePath == (transferPath as NSString).standardizingPath {
                let bundlePath = devicePath.appending("/VM.bundle/")
                if strongSelf.fileManager.fileExists(atPath: bundlePath) {
                    NSSound.funk?.play()
                    let targetPath = config.source.localPath
                    print("Found VM Bundle on \(transferPath). Copying over to \(targetPath)")
                    DispatchQueue.global(qos:.background).async {
                        strongSelf.isCopying = true
                        switch Result(catching: {
                            try strongSelf.fileManager.removeItem(atPath: targetPath)
                            try strongSelf.fileManager.copyItem(atPath: bundlePath, toPath: targetPath)
                            try NSWorkspace.shared.unmountAndEjectDevice(at: URL(filePath: devicePath))
                        }) {
                        case .success:
                            NSSound.submarine?.play()
                            print("Successfully copied bundle from Volume")
                        case .failure(let err):
                            print(err)
                        }
                        strongSelf.isCopying = false
                    }
                }
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
}
