import Foundation

enum LeaseParser {
    static func parseLeases() throws -> [Lease] {
        let fileName = "/var/db/dhcpd_leases"
        let leasesString = try String(contentsOfFile: fileName)
        let leases = leasesString.split(separator: "}\n")
        return leases.compactMap { Lease(from: String($0)) }
    }

    static func leaseForMacAddress(mac: String) throws -> Lease {
        guard let lease = try parseLeases().first(where: { $0.hwAddress == mac }) else {
            throw Error.leaseNotFound(mac: mac)
        }
        return lease
    }

    struct Lease {
        let name: String
        let ipAddress: String
        let hwAddress: String

        init?(from string: String) {
            let entry = string
                .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .reduce(into: [String: String](), { dictionary, element in
                    let keyVal = element.split(separator: "=").map(String.init)
                    guard keyVal.count == 2 else { return }
                    dictionary[keyVal[0]] = keyVal[1]
                })
            guard let name = entry["name"],
                  let ip = entry["ip_address"],
                  let hwAddress = entry["hw_address"] else { return nil }
            let splitMac = hwAddress.split(separator: ",")
            guard splitMac.count == 2, Int32(splitMac[0]) == ARPHRD_ETHER else { return nil }

            let macAddress = splitMac[1]
                .components(separatedBy: ":")
                .compactMap { UInt8($0, radix: 16) }
                .map { String(format: "%02x", $0) }
                .joined(separator: ":")

            self.name = name
            self.ipAddress = ip
            self.hwAddress = macAddress
        }
    }

    enum Error: Swift.Error, LocalizedError {
        case leaseNotFound(mac: String)

        var errorDescription: String? {
            switch self {
            case let .leaseNotFound(mac):
                return "Could not find lease for mac address \(mac)"
            }
        }
    }
}

struct MACAddress: Equatable, Hashable, CustomStringConvertible {
    var mac: [UInt8] = Array(repeating: 0, count: 6)

    init?(fromString: String) {
        let components = fromString.components(separatedBy: ":")

        if components.count != 6 {
            return nil
        }

        for (index, component) in components.enumerated() {
            mac[index] = UInt8(component, radix: 16)!
        }
    }

    var description: String {
        String(format: "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5])
    }
}
