import Foundation

struct GitlabProvisionerConfig: Decodable {
    /// The name by which the runner can be identified
    let name: String
    /// The url to register the runner at. In a self-hosted environment, this is probably your main GitLab URL, e.g. https://gitlab.yourdomain.net/
    let url: URL
    /// The runner registration token, can be obtained in the GitLab runner UI
    let registrationToken: String
    /// A list of tags to apply to the runner, comma-separated
    let tagList: String
}
