import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                Spacer()

                // App Logo and Title
                VStack(spacing: HiveSpacing.md) {
                    BeeLogoView()
                        .frame(width: 200, height: 200)

                    VStack(spacing: HiveSpacing.xs) {
                        Text("HabitHive")
                            .font(HiveTypography.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        Text("Pour honey on better habits with your hive")
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                }

                Spacer()

                // Auth Options
                VStack(spacing: HiveSpacing.lg) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(HiveTypography.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, HiveSpacing.lg)
                            .transition(.opacity)
                    }

                    VStack(spacing: HiveSpacing.md) {
                        // Apple Sign In Button
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.nonce = sha256(nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 375)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(HiveRadius.xlarge)
                        .disabled(isProcessing)
                    }
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            errorMessage = nil
            isProcessing = true

            do {
                switch result {
                case .success(let authorization):
                    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let identityToken = appleIDCredential.identityToken,
                          let idTokenString = String(data: identityToken, encoding: .utf8) else {
                        throw AppleSignInError.invalidCredentials
                    }

                    // Use the real Apple ID token to create/authenticate user
                    try await FastAPIClient.shared.signInWithApple(idToken: idTokenString, nonce: currentNonce)

                case .failure(let error):
                    throw error
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

import CryptoKit

enum AppleSignInError: LocalizedError {
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Failed to get valid credentials from Apple"
        }
    }
}
