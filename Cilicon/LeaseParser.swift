import Foundation

struct LeaseParser {
    static func parseLeases() -> [Lease] {
        let fileName = "/var/db/dhcpd_leases"
        let leasesString = try! String(contentsOfFile: fileName)
        let leases = leasesString.split(separator: "}\n")
        return leases.compactMap { Lease(from: String($0)) }
    }
    
    static func leaseForMacAddress(mac: String) -> Lease? {
        return parseLeases().first(where: { $0.hwAddress == mac })
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
                .reduce(into: Dictionary<String, String>(), { dictionary, element in
                    let keyVal = element.split(separator: "=").map(String.init)
                    guard keyVal.count == 2 else { return }
                    dictionary[keyVal[0]] = keyVal[1]
                })
            guard let name = entry["name"],
                  let ip = entry["ip_address"],
                  let hwAddress = entry["hw_address"] else { return nil }
            let splitMac = hwAddress.split(separator: ",")
            guard splitMac.count == 2, Int32(splitMac[0]) == ARPHRD_ETHER else { return nil }
            self.name = name
            self.ipAddress = ip
            self.hwAddress = String(splitMac[1])
        }
    }
}
