import Foundation
import SwiftJWT

struct GitHubAppAuthHelper {
    struct GHClaims: Claims {
        /// Issuer: The App ID should be used
        let iss: String
        /// Issuance date
        let iat: Date
        /// Expiration date
        let exp: Date
    }

    static func generateJWTToken(pemPath: String, appId: Int) throws -> String {
        let now = Date().timeIntervalSince1970
        let floored = floor(now)
        let date = Date(timeIntervalSince1970: floored)
        let myClaims = GHClaims(
            iss: String(appId),
            iat: date.addingTimeInterval(-10),
            exp: date.addingTimeInterval(60)
        )
        var myJWT = JWT(claims: myClaims)
        let privateKeyPath = URL(fileURLWithPath: pemPath)
        let privateKey: Data = try Data(contentsOf: privateKeyPath, options: .alwaysMapped)

        let jwtSigner = JWTSigner.rs256(privateKey: privateKey)
        return try myJWT.sign(using: jwtSigner)
    }
}
