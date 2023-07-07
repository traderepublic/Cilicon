import Foundation

struct WWWAuthenticate {
    let authMode: String
    let realm: String
    let service: String
    let scope: String

    init?(authenticateHeaderField header: String) {
        let components = header
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", maxSplits: 1)

        guard components.count == 2 else { return nil }
        self.authMode = String(components[0])
        let items = components[1].split(separator: ",")
        let dictionary = items.reduce(into: [String: String]()) {
            let keyVal = $1.split(separator: "=", maxSplits: 1)
            $0[String(keyVal[0])] = String(keyVal[1]).replacingOccurrences(of: "\"", with: "")
        }

        guard let realm = dictionary["realm"],
              let service = dictionary["service"],
              let scope = dictionary["scope"] else { return nil }
        self.realm = realm
        self.service = service
        self.scope = scope
    }

    init?(response: HTTPURLResponse) {
        guard let header = response.value(forHTTPHeaderField: "www-authenticate") else {
            return nil
        }
        self.init(authenticateHeaderField: header)
    }
}
