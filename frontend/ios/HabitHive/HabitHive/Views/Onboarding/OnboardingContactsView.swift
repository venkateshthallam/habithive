import SwiftUI

struct OnboardingContactsView: View {
    var onUpload: ([String]) -> Void
    @State private var granted = false
    @State private var isUploading = false
    @StateObject private var themeManager = ThemeManager.shared
    private let pepper = "CHANGE_ME_SERVER_PEPPER" // TODO: fetch from server

    var body: some View {
        ZStack {
            // Background gradient like WelcomeView
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: HiveSpacing.xl) {
                Spacer()

                // Icon and title
                VStack(spacing: HiveSpacing.lg) {
                    // Contacts icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: HiveSpacing.md) {
                        Text("Find Friends")
                            .font(HiveTypography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("We'll match your contacts privately using phone hashes. Your contact information is securely hashed and never stored in readable form.")
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, HiveSpacing.lg)
                    }
                }

                Spacer()

                // Loading or Action Button
                VStack(spacing: HiveSpacing.md) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Finding friends...")
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Button(action: {
                            if granted {
                                isUploading = true
                                let hashes = ContactsManager.shared.fetchPhoneHashes(pepper: pepper)
                                onUpload(hashes)
                                isUploading = false
                            } else {
                                ContactsManager.shared.requestAccess { ok in granted = ok }
                            }
                        }) {
                            HStack {
                                Image(systemName: granted ? "icloud.and.arrow.up" : "person.crop.circle.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(granted ? "Upload Contacts" : "Allow Contacts")
                                    .font(HiveTypography.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HiveSpacing.md)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .background(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }

                        // Skip option
                        Button(action: {
                            onUpload([]) // Skip contacts upload
                        }) {
                            Text("Skip for now")
                                .font(HiveTypography.body)
                                .foregroundColor(.white.opacity(0.8))
                                .underline()
                        }
                        .padding(.top, HiveSpacing.sm)
                    }
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
    }
}
