import Foundation
import Virtualization

class Installer: ObservableObject {
    @Published
    var state: InstallerState = .idle

    func run(mode: InstallMode, bundle: VMBundle, diskSize: Int64) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                switch mode {
                case let .downloadAndInstall(downloadPath):
                    let path = try await self.download(targetPath: downloadPath)
                    self.run(
                        mode: .installFromImage(restoreImage: path),
                        bundle: bundle,
                        diskSize: diskSize
                    )
                case let .installFromImage(restoreImagePath):
                    try await self.install(
                        imagePath: restoreImagePath,
                        bundle: bundle,
                        diskSize: diskSize
                    )
                    NSSound.submarine?.play()
                }
            } catch {
                self.updateState(to: .error(error.localizedDescription))
                NSSound.sosumi?.play()
            }
        }
    }

    // MARK: Download

    private func download(targetPath: URL) async throws -> URL {
        let latestSupported = try await withCheckedThrowingContinuation { cont in
            VZMacOSRestoreImage.fetchLatestSupported(completionHandler: cont.resume(with:))
        }
        let ver = latestSupported.operatingSystemVersion
        let versionString = [ver.majorVersion, ver.minorVersion, ver.patchVersion]
            .map(String.init)
            .joined(separator: ".")
        let fileName = "UniversalMac_\(versionString)_\(latestSupported.buildVersion)_Restore.ipsw"
        let restoreImageURL = URL(fileURLWithPath: targetPath.relativePath + "/" + fileName)
        if FileManager.default.fileExists(atPath: restoreImageURL.relativePath) {
            throw InstallerError.restoreImageAlreadyExists(restoreImageURL.relativePath)
        }

        var downloadObserver: NSKeyValueObservation?
        let versionBuildString = "\(versionString) (\(latestSupported.buildVersion))"
        // Progress formatter
        let progressFormatter = NumberFormatter()
        progressFormatter.numberStyle = .percent

        let localURL: URL = try await withCheckedThrowingContinuation { cont in
            let downloadTask = URLSession.shared.downloadTask(with: latestSupported.url) { localURL, response, error in
                if let error {
                    return cont.resume(with: .failure(error))
                } else if let localURL {
                    return cont.resume(with: .success(localURL))
                }
            }
            // Move to another line for sticky printing
            downloadObserver = downloadTask.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, change in
                guard let progValue = change.newValue else { return }
                self?.updateState(to: .downloading(version: versionBuildString, progress: progValue))
            }
            downloadTask.resume()
        }
        downloadObserver?.invalidate()
        try FileManager.default.moveItem(at: localURL, to: restoreImageURL)
        return restoreImageURL
    }

    // MARK: Install

    @MainActor
    private func install(imagePath: URL, bundle: VMBundle, diskSize: Int64) async throws {
        // Load the image
        let restoreImage = try await withCheckedThrowingContinuation { cont in
            VZMacOSRestoreImage.load(from: imagePath, completionHandler: cont.resume(with:))
        }
        guard let macOSConfiguration = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw InstallerError.genericError("No supported configuration available.")
        }
        if !macOSConfiguration.hardwareModel.isSupported {
            throw InstallerError.genericError("macOSConfiguration configuration isn't supported on the current host.")
        }

        try createVMBundle(bundle: bundle)
        try createDiskImage(bundle: bundle, size: diskSize)

        let configHelper = VMConfigHelper(vmBundle: bundle)
        let vmConfiguration = try configHelper.computeInstallConfiguration(macOSConfiguration: macOSConfiguration)
        let virtualMachine = VZVirtualMachine(configuration: vmConfiguration)
        let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: imagePath)

        print("Starting installation.")
        // Progress formatter
        let progressFormatter = NumberFormatter()
        progressFormatter.numberStyle = .percent
        // Move to another line for sticky printing
        let installationObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, change in
            guard let progValue = change.newValue else { return }
            self?.updateState(to: .installing(progress: progValue))
        }

        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                installer.install(completionHandler: { (result: Result<Void, Error>) in
                    continuation.resume(with: result)
                })
            }
        }
        print("\nmacOS installed successfully.")
        installationObserver.invalidate()
        updateState(to: .done)
    }

    private func createVMBundle(bundle: VMBundle) throws {
        if FileManager.default.fileExists(atPath: bundle.url.relativePath) {
            throw InstallerError.bundleAlreadyExists(bundle.url.relativePath)
        }
        let bundleFolders = [bundle.url]
        for bundleFolder in bundleFolders {
            try FileManager.default.createDirectory(at: bundleFolder, withIntermediateDirectories: true)
        }
    }

    private func createDiskImage(bundle: VMBundle, size: Int64) throws {
        let diskFd = open(bundle.diskImageURL.relativePath, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskFd == -1 {
            throw InstallerError.genericError("Cannot create disk image.")
        }
        var result = ftruncate(diskFd, size * 1024 * 1024 * 1024)
        if result != 0 {
            throw InstallerError.genericError("Expanding disk file failed.")
        }
        result = close(diskFd)
        if result != 0 {
            throw InstallerError.genericError("Failed to close the disk image.")
        }
    }

    func updateState(to newState: InstallerState) {
        DispatchQueue.main.async {
            self.state = newState
        }
    }
}

enum InstallerError: LocalizedError {
    case restoreImageAlreadyExists(String)
    case bundleAlreadyExists(String)
    case failedCreatingDummyStartFile(String)
    case genericError(String)

    var errorDescription: String? {
        switch self {
        case let .restoreImageAlreadyExists(path):
            return "Restore image already exists at \(path)."
        case let .bundleAlreadyExists(path):
            return "VM bundle already exists at \(path)."
        case let .failedCreatingDummyStartFile(path):
            return "Failed creating dummy start.command file at \(path)"
        case let .genericError(errorText):
            return errorText
        }
    }
}

enum InstallerState {
    case done
    case idle
    case error(String)
    case downloading(version: String, progress: Double)
    case installing(progress: Double)
}
