import Foundation
import OCI

enum VMSource: Decodable {
    case OCI(OCIURL)
    case local(URL)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let components = URLComponents(string: string), let url = components.url else {
            throw VMSourceError.invalidURL
        }
        switch components.scheme {
        case "oci":
            guard let ociURL = OCIURL(urlComponents: components) else {
                throw VMSourceError.invalidURL
            }
            self = .OCI(ociURL)
        default:
            self = .local(url)
        }
    }
    
    var localPath: String {
        switch self {
        case let .local(url):
            let path = ((url.path.trimmingPrefix("/") as NSString).expandingTildeInPath as NSString).resolvingSymlinksInPath
            return path
        case let .OCI(ociURL):
            return ociURL.localPath
        }
    }
    
    enum VMSourceError: LocalizedError {
        case invalidURL
        
        
        var errorDescription: String? {
            return "Invalid URL. Make sure it starts with a `oci://` or `file://` scheme"
        }
    }
}

extension OCIURL {
    var localPath: String {
        let path = ("~/.tart/cache/OCIs/\(registry)\(repository)/\(tag)" as NSString).resolvingSymlinksInPath
        return path
    }
}
