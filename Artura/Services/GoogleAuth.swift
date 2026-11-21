import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// Connexion Google sans bibliothèque externe : OAuth 2 avec PKCE, dans la fenêtre d'authentification du système.
/// Comme pour Apple, l'identifiant du compte est seulement mémorisé sur l'appareil.
enum GoogleAuth {
    /// Identifiant client OAuth de type « iOS », créé dans Google Cloud Console
    /// (de la forme "1234-abcd.apps.googleusercontent.com"). Vide : connexion Google non configurée.
    static let clientID = ""

    static var isConfigured: Bool { !clientID.isEmpty }

    struct Account {
        let userID: String
        let firstName: String?
    }

    enum Failure: Error {
        case notConfigured
        case cancelled
        case invalidResponse
    }

    /// Schéma de retour attendu par Google pour une appli iOS : l'identifiant client à l'envers.
    private static var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    /// Ouvre la connexion Google et retourne l'identifiant du compte.
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

        // Échange du code contre un jeton d'identité.
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
        return Account(userID: userID, firstName: payload["given_name"] as? String)
    }

    /// Contenu d'un jeton JWT (la partie du milieu, encodée en base64 pour URL).
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
