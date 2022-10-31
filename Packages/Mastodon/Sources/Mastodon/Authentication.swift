import Foundation
import Everything

public struct RegisteredApplication: Identifiable, Codable, Hashable {
    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case website
        case redirectURI = "redirect_uri"
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case vapidKey = "vapid_key"
    }

    public let id: Tagged<RegisteredApplication, String>
    public let name: String
    public let website: String
    public let redirectURI: String
    public let clientID: String
    public let clientSecret: String
    public let vapidKey: String
}

public struct Token: Codable, Hashable {
    public enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case created = "created_at"
    }

    public let accessToken: String
    public let tokenType: String
    public let scope: String
    public let created: Date
}

