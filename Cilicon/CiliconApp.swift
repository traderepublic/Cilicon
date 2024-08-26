import Combine
import Semaphore
import SwiftUI
import Yams

@main
struct CiliconApp: App {
    var coreApp = CiliconCoreApp()

    var body: some Scene {
        Window("Cilicon", id: "cilicon-main") {
            if case let .failed(descr) = coreApp.appState {
                Text(descr)
            }
            List {
                ForEach(coreApp.vmRunners) {
                    VMListItem(vmRunner: $0)
                }
            }
            .toolbar {
                Text("Runs: \(coreApp.runCounter)")
                Button(coreApp.restartScheduled ? "Restart Scheduled" : "Schedule Restart") {
                    coreApp.restartScheduled.toggle()
                }.disabled(coreApp.restartScheduled)
            }
            .frame(minWidth: 500, minHeight: 225)
            if case let .downloading(_, prog) = coreApp.sourceManager.state {
                ProgressView(coreApp.sourceManager.state.localizedDescription, value: prog)
                    .padding()
            }
        }

        WindowGroup("Display", id: "display-window", for: VMRunner.ID.self) { $id in
            if let id, coreApp.vmRunners.contains(where: { $0.id == id }) {
                VMDisplayView(coreApp: coreApp, vmId: id)
            }
        }

        WindowGroup("Log", id: "log-window", for: VMRunner.ID.self) { $id in
            if let id, coreApp.vmRunners.contains(where: { $0.id == id }) {
                VMLogView(coreApp: coreApp, vmId: id)
            }
        }
    }
}

@Observable
class CiliconCoreApp {
    let title: String = "Cilicon"
    var runCounter = 0
    var appState: CoreAppState
    let sourceManager = SourceManager.shared
    var vmRunners: [VMRunner]
    var restartScheduled = false

    init() {
        do {
            let conf = try ConfigManager().config
            self.appState = .running(conf)
            self.vmRunners = conf.machines.map {
                VMRunner(config: conf, vmConfig: VMRunnerConfig(machineConfig: $0))
            }

        } catch {
            self.appState = .failed(error.localizedDescription)
            self.vmRunners = []
        }

        Task.detached { @MainActor in
            try await self.startCycle()
        }
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])

        _ = NoSleep.disableSleep()
    }

    @MainActor
    func incrementRunCount() {
        runCounter += 1
    }

    func startCycle() async throws {
        guard case .running = appState else {
            return
        }

        await withThrowingTaskGroup(of: Void.self) { [weak self] group in
            guard let weakSelf = self else { return }
            for runner in weakSelf.vmRunners {
                group.addTask(priority: .background) {
                    while weakSelf.runCounter < .max, !weakSelf.restartScheduled {
                        do {
                            try await runner.start()
                            await weakSelf.incrementRunCount()
                        } catch {
                            // wait before trying again TODO: Replace with configurable delay
                            try await Task.sleep(for: .seconds(2))
                        }
                    }
                    weakSelf.restartScheduled = true
                }
            }
        }
        if restartScheduled {
            print("TODO: restart")
        }
    }

    func doRunnerUnit(path: URL) { }

    enum CoreAppState {
        case running(Config)
        case failed(String)
    }
}

enum OCIDownloaderError: Error {
    case configNotFound
    case nvramNotFound
    case failedToCreateDiskFile
}

@Observable
class SourceManager {
    static let shared = SourceManager()
    var state: State = .idle
    let downloader = OCIDownloader()
    let fileManager = FileManager()
    let downloadSemaphore = AsyncSemaphore(value: 1)

    @MainActor
    func setState(state: State) {
        self.state = state
    }

    enum State {
        case idle
        case downloading(url: OCIURL, progress: Double)

        var isIdle: Bool {
            switch self {
            case .idle:
                return true
            default:
                return false
            }
        }

        var localizedDescription: String {
            switch self {
            case let .downloading(url, progress):
                let numFormatter = NumberFormatter()
                numFormatter.numberStyle = .percent
                numFormatter.maximumFractionDigits = 0
                let formattedProgress = numFormatter.string(from: progress as NSNumber)!
                return "Downloading \(url.repository):\(url.tag)  (\(formattedProgress))"
            case .idle:
                return "Idle"
            }
        }
    }

    func validImageExists(ociURL: OCIURL) -> Bool {
        return fileManager.fileExists(atPath: ociURL.localPath) &&
            !fileManager.fileExists(atPath: VMBundle(url: URL(filePath: ociURL.localPath)).unfinishedURL.path)
    }

    func getPath(source: VMSource) async throws -> URL {
        switch source {
        case let .local(url):
            return url
        case let .OCI(oci):
            do {
                if validImageExists(ociURL: oci) {
                    return URL(filePath: oci.localPath)
                }
                await downloadSemaphore.wait()
                // Check again once we've waited for our turn and there's max 2 VMs (TODO: Find a more elegant solution which theoretically works with
                // infinite number of parallel VMs)
                if validImageExists(ociURL: oci) {
                    return URL(filePath: oci.localPath)
                }

                let progress = Progress()
                let progCanc = progress.publisher(for: \.fractionCompleted)
                    .prepend(0)
                    .receive(on: RunLoop.main)
                    .sink(receiveValue: { [weak self] in
                        self?.state = .downloading(url: oci, progress: $0)
                    })
                try await downloader.downloadOCI(url: oci, progress: progress)
                progCanc.cancel()
                await setState(state: .idle)
                downloadSemaphore.signal()
                return URL(filePath: oci.localPath)
            } catch {
                try fileManager.removeItem(atPath: oci.localPath)
                throw error
            }
        }
    }
//    func isBundleComplete() throws -> Bool {
//        let filesExist = [
//            masterBundle.diskImageURL,
//            masterBundle.configURL,
//            masterBundle.auxiliaryStorageURL
//        ]
//            .map { $0.resolvingSymlinksInPath() }
//            .reduce(into: false) { $0 = fileManager.fileExists(atPath: $1.path) }
//        let notUnfinished = !fileManager.fileExists(atPath: masterBundle.unfinishedURL.path)
//
//        return filesExist && notUnfinished
//    }
}

class OCIDownloader {
    private let fileManager = FileManager()

    func getAvailableSpace(at url: URL) throws -> Int64? {
        let results = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return results?.volumeAvailableCapacityForImportantUsage
    }

    func downloadOCI(url: OCIURL, progress: Progress) async throws {
        let client = OCI(url: url)
        let (digest, manifest) = try await client.fetchManifest()

        let path = URL(filePath: url.localPath).deletingLastPathComponent().appending(path: digest)
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.localPath) {
            try fileManager.createSymbolicLink(at: URL(filePath: url.localPath), withDestinationURL: path)
        }
        let bundleForPaths = VMBundle(url: path)
        fileManager.createFile(atPath: bundleForPaths.unfinishedURL.path, contents: nil)
        let diskURL = bundleForPaths.diskImageURL

        if fileManager.fileExists(atPath: diskURL.path) {
            try fileManager.removeItem(at: diskURL)
        }
        // Available Disk size check
        let totalDecompressedSize = try manifest.layers.getTotalDecompressedSize()
        let available = try getAvailableSpace(at: path)
        if let available, available < totalDecompressedSize {
            print("not enough disk space")
        }

        if !fileManager.createFile(atPath: diskURL.path, contents: nil) {
            throw OCIDownloaderError.failedToCreateDiskFile
        }

        guard let configLayer = manifest.layers.first(where: { $0.mediaType == "application/vnd.cirruslabs.tart.config.v1" }) else {
            throw OCIDownloaderError.configNotFound
        }
        let configData = try await client.pullBlobData(digest: configLayer.digest)
        try configData.write(to: bundleForPaths.configURL)
        // Fetching images

        let totalSize = manifest.layers.map(\.size).reduce(into: Int64(0), +=)
        progress.totalUnitCount = totalSize
        let imgLayers = manifest.layers.filter { $0.mediaType.starts(with: "application/vnd.cirruslabs.tart.disk.") }

        let isV2Disk = imgLayers.allSatisfy({ $0.mediaType == "application/vnd.cirruslabs.tart.disk.v2" })

        if isV2Disk {
            try await LayerV2Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                progress: progress,
                maxConcurrency: 4
            )
        } else {
            try await LayerV1Downloader.pull(
                registry: client,
                diskLayers: imgLayers,
                diskURL: diskURL,
                progress: progress
            )
        }
        guard let nvramLayer = manifest.layers.first(where: { $0.mediaType == "application/vnd.cirruslabs.tart.nvram.v1" }) else {
            throw OCIDownloaderError.nvramNotFound
        }
        let nvramData = try await client.pullBlobData(digest: nvramLayer.digest)
        try nvramData.write(to: bundleForPaths.auxiliaryStorageURL)

        try fileManager.removeItem(atPath: bundleForPaths.unfinishedURL.path)
    }
}

/// An action to be scheduled after all VMs have stopped. Scheduling an action will interrupt the restart loop.
enum ScheduledAction {
    case restart
    case reboot
    case close
    case shutdown
    case none
}

import IOKit.pwr_mgt

enum NoSleep {
    private static var assertionID: IOPMAssertionID = 0
    private static var success: IOReturn?

    static func disableSleep() -> Bool? {
        guard success == nil else { return nil }
        success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "String with reason for preventing sleep" as CFString,
            &assertionID
        )
        return success == kIOReturnSuccess
    }

    static func enableSleep() -> Bool {
        if success != nil {
            success = IOPMAssertionRelease(assertionID)
            success = nil
            return true
        }
        return false
    }
}
