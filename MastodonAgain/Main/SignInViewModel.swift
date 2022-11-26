//
//  SignInViewModel.swift
//  Mastodon
//
//  Created by Andy Qua on 19/11/2022.
//

import AuthenticationServices
import Mastodon

@MainActor
class SignInViewModel: NSObject, ObservableObject {
    private let scopes = "read+write+follow+push"
    private let redirectURI = "mastodonagain://oauth"
    private let callbackScheme = "mastodonagain"

    @Published var host: String?

    @Published var authorization: Authorization = .unauthorized

    enum SignInError: Swift.Error {
        case cancelled
        case authenticationSessionError(Swift.Error)
        case noAuthorizationCode
        case noHost

        var localizedDescription: String {
            switch self {
            case .cancelled:
                return "Login Cancelled"
            case .authenticationSessionError(let error):
                return error.localizedDescription
            case .noAuthorizationCode:
                return "No authorization code"
            case .noHost:
                return "No host set"
            }
        }
    }

    func register(applicationName: String, applicationWebsite: String) async throws {
        guard let host else { throw SignInError.noHost }

        // TODO: Finish
//        let r = MastodonAPI.Apps.Create(baseURL: URL(string: "https://\(host)")!, clientName: applicationName, redirectURIs: redirectURI, scopes: scopes, website: applicationWebsite)
//        URLSession.shared.perform(request: r, response: r.response)

        let url = URL(string: "https://\(host)/api/v1/apps")!
        let request = URLRequest(url: url, formParameters: [
            "client_name": applicationName,
            "redirect_uris": redirectURI,
            "scopes": scopes,
            "website": applicationWebsite,
        ])

        let (application, _) = try await URLSession.shared.json(RegisteredApplication.self, for: request)

        authorization = .registered(application)
    }

    func signIn(clientID: String) async throws -> String {
        guard let host else { throw SignInError.noHost }

        let url = URL(string: "https://\(host)/oauth/authorize")!

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        let authUrl = components.url!

        return try await withCheckedThrowingContinuation({ continuation in
            let authSession = ASWebAuthenticationSession(
                url: authUrl, callbackURLScheme:
                callbackScheme
            ) { url, error in
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        continuation.resume(throwing: SignInError.cancelled)
                    }
                    else {
                        continuation.resume(throwing: SignInError.authenticationSessionError(error))
                    }
                }
                else if let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let item = components.queryItems?.first(where: { $0.name == "code" }), let code = item.value {
                    print("Have access code - \(code)")
                    continuation.resume(returning: code)
                }
                else {
                    continuation.resume(throwing: SignInError.noAuthorizationCode)
                }
            }

            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            authSession.start()
        })
    }

    func exchangeCodeForToken(application: RegisteredApplication, authorisationCode: String) async throws {
        guard let host else { throw SignInError.noHost }

        let url = URL(string: "https://\(host)/oauth/token")!
        let formParams: [String: String] = [
            "client_id": application.clientID,
            "client_secret": application.clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code": authorisationCode,
            "scope": scopes,
        ]
        let request = URLRequest(url: url, formParameters: formParams)
        let (token, _) = try await URLSession.shared.json(Token.self, for: request)
        authorization = Authorization.authorized(application, token)
    }

    func getAccountDetails() async throws -> SignIn {
        guard let host else { throw SignInError.noHost }

        let service = try Service(host: host, authorization: authorization)
        let account = try await service.perform { baseURL, token in
            MastodonAPI.Accounts.Verify(baseURL: baseURL, token: token)
        }
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: account.avatar))
        let signin = SignIn(host: host, authorization: authorization, account: account, avatar: try .init(source: .data(data)))

        return signin
    }
}

extension SignInViewModel: ASWebAuthenticationPresentationContextProviding {
    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
