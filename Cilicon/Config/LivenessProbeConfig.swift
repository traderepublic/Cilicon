import Foundation

/// Configuration for liveness probe that monitors VM health
struct LivenessProbeConfig: Decodable {
    private static let defaultInterval: TimeInterval = 30
    private static let defaultDelay: TimeInterval = 60

    /// Shell command to execute for health check
    let command: String
    /// Interval  between probe checks
    let interval: TimeInterval
    /// Initial delay before starting probes
    let delay: TimeInterval

    enum CodingKeys: CodingKey {
        case command
        case interval
        case delay
    }

    init(
        command: String,
        interval: TimeInterval = Self.defaultInterval,
        delay: TimeInterval = Self.defaultDelay
    ) {
        self.command = command
        self.interval = interval
        self.delay = delay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.command = try container.decode(String.self, forKey: .command)
        self.interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? Self.defaultInterval
        self.delay = try container.decodeIfPresent(TimeInterval.self, forKey: .delay) ?? Self.defaultDelay
    }
}
