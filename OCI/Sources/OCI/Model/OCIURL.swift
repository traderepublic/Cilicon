import Foundation

public struct OCIURL {
    let scheme: String
    let registry: String
    let repository: String
    let tag: String?
    
    init?(string: String) {
        guard let urlComponents = URLComponents(string: string),
              let scheme = urlComponents.scheme,
              scheme == "oci",
              let host = urlComponents.host,
              let path = urlComponents.path.removingPercentEncoding,
              !path.isEmpty
        else {
            return nil
        }
        
        let components = path.split(separator: ":").map(String.init)
        guard components.count >= 2 else {
            return nil
        }
        
        self.scheme = scheme
        self.registry = host
        self.repository = components[0]
        
        if components.count >= 2 {
            self.tag = components[1]
        } else {
            self.tag = nil
        }
    }
}
