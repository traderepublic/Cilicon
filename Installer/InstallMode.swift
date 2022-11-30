import Foundation

enum InstallMode {
    case downloadAndInstall(downloadFolder: URL)
    case installFromImage(restoreImage: URL)
}
