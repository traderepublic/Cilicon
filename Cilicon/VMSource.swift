import Foundation

enum VMSource: Codable {
    case OCI(OCIURL)
    case local(URL)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let parsed = VMSource(string: string) else {
            throw VMSourceError.invalidPath
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .OCI(url):
            try container.encode(url)
        case let .local(url):
            try container.encode(url.path)
        }
    }

    init?(string: String) {
        guard let components = URLComponents(string: string), let url = components.url else {
            return nil
        }
        switch components.scheme {
        case "oci":
            guard let ociURL = OCIURL(urlComponents: components) else {
                return nil
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

    var uiRepresentation: String {
        switch self {
        case let .local(url):
            return url.relativePath
        case let .OCI(url):
            return "oci://\(url.registry)\(url.repository):\(url.tag)"
        }
    }

    enum VMSourceError: LocalizedError {
        case invalidPath

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
