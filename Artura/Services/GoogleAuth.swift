import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// Google sign-in without an external library: OAuth 2 with PKCE, in the system authentication window.
/// As with Apple, the account identifier is only stored on the device.
enum GoogleAuth {
    /// OAuth client ID of type "iOS", created in Google Cloud Console
    /// (of the form "1234-abcd.apps.googleusercontent.com"). Empty: Google sign-in not configured.
    static let clientID = "518521814725-t3imoo775i27ph159fc2fs0dlbciaboh.apps.googleusercontent.com"

    static var isConfigured: Bool { !clientID.isEmpty }

    struct Account {
        let userID: String
        let firstName: String?
        /// Identity token, exchanged for a Supabase session.
        let idToken: String
    }

    enum Failure: Error {
        case notConfigured
        case cancelled
        case invalidResponse
    }

    /// Callback scheme Google expects for an iOS app: the client ID reversed.
    private static var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    /// Opens Google sign-in and returns the account identifier.
    @MainActor
    static func signIn(using session: WebAuthenticationSession) async throws -> Account {
        guard isConfigured else { throw Failure.notConfigured }

        let verifier = randomToken()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let redirect = "\(callbackScheme):/oauth2redirect"

        var authorize = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        authorize?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authorizeURL = authorize?.url else { throw Failure.invalidResponse }

        let callback: URL
        do {
            callback = try await session.authenticate(using: authorizeURL, callbackURLScheme: callbackScheme)
        } catch {
            throw Failure.cancelled
        }
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw Failure.invalidResponse
        }

        // Exchange the code for an identity token.
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else { throw Failure.invalidResponse }
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirect)
        ]
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let payload = payload(of: idToken),
              let userID = payload["sub"] as? String else {
            throw Failure.invalidResponse
        }
        return Account(userID: userID, firstName: payload["given_name"] as? String, idToken: idToken)
    }

    /// Payload of a JWT (the middle part, base64url-encoded).
    private static func payload(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while encoded.count % 4 != 0 { encoded += "=" }
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
