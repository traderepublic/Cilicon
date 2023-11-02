import os.log

extension Logger {
    static let ciliconSubsystem = Bundle.main.bundleIdentifier ?? "com.traderepublic.cilicon"

    init(category: String) {
        self.init(subsystem: Logger.ciliconSubsystem, category: category)
    }
}
