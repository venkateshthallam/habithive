import SwiftUI
import Contacts
import UserNotifications

struct ProfileSetupFlowView: View {
    private enum Step: Int, CaseIterable {
        case name, phone, notifications, contacts

        var title: String {
            switch self {
            case .name: return "Your name"
            case .phone: return "Your phone"
            case .notifications: return "Stay motivated"
            case .contacts: return "Find friends"
            }
        }
    }

    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var apiClient = FastAPIClient.shared
    @State private var step: Step = .name
    @State private var displayName: String
    @State private var phoneNumber: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var contactsUploaded = false
    @State private var hasRequestedContacts = false
    @State private var notificationsEnabled = false
    @State private var hasRequestedNotifications = false
    @State private var hasAutoCompleted = false

    init() {
        let currentUser = FastAPIClient.shared.currentUser
        _displayName = State(initialValue: currentUser?.displayName ?? "")
        _phoneNumber = State(initialValue: currentUser?.phone ?? "")

        if let currentUser {
            let needsName = currentUser.displayName.isDefaultHiveDisplayName
            let needsPhone = currentUser.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if needsName {
                _step = State(initialValue: .name)
            } else if needsPhone {
                _step = State(initialValue: .phone)
            } else {
                _step = State(initialValue: .notifications)
            }
        }
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: HiveSpacing.xl) {
                header

                VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                    switch step {
                    case .name:
                        NameStepView(name: $displayName)
                    case .phone:
                        PhoneStepView(phoneNumber: $phoneNumber)
                    case .notifications:
                        NotificationsStepView(notificationsEnabled: $notificationsEnabled, onRequest: requestNotifications)
                    case .contacts:
                        ContactsStepView(contactsUploaded: $contactsUploaded, onImport: uploadContacts)
                    }
                }

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(HiveTypography.caption)
                        .foregroundColor(HiveColors.error)
                        .transition(.opacity)
                }

                primaryButton
            }
            .padding(.horizontal, HiveSpacing.lg)
            .padding(.vertical, HiveSpacing.xl)
        }
        .overlay(alignment: .topTrailing) {
            if isSubmitting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: HiveColors.honeyGradientEnd))
                    .padding(HiveSpacing.lg)
            }
        }
        .onAppear {
            maybeCompleteIfProfileReady()
        }
        .onChange(of: apiClient.currentUser?.id) { _ in
            syncStateWithCurrentUser()
            maybeCompleteIfProfileReady()
        }
        .onChange(of: apiClient.currentUser?.displayName) { _ in
            syncStateWithCurrentUser()
            maybeCompleteIfProfileReady()
        }
        .onChange(of: apiClient.currentUser?.phone) { _ in
            syncStateWithCurrentUser()
            maybeCompleteIfProfileReady()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            HStack {
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                Spacer()
            }

            Text(step.title)
                .font(HiveTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
        }
    }

    private var primaryButton: some View {
        Button(action: handlePrimaryAction) {
            Text(step == .contacts ? "Finish" : "Continue")
                .font(HiveTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                        .fill(themeManager.currentTheme.primaryGradient)
                )
                .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 16, x: 0, y: 8)
        }
        .disabled(isSubmitting)
    }

    private func handlePrimaryAction() {
        Task {
            do {
                errorMessage = nil
                isSubmitting = true
                switch step {
                case .name:
                    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        errorMessage = "Please enter a name you want friends to see."
                        isSubmitting = false
                        return
                    }
                    _ = try await FastAPIClient.shared.updateProfile(ProfileUpdate(displayName: trimmed))
                    step = .phone
                case .phone:
                    let normalized = normalizePhone(phoneNumber)
                    guard !normalized.isEmpty else {
                        errorMessage = "Enter a valid phone number so friends can find you."
                        isSubmitting = false
                        return
                    }
                    try await FastAPIClient.shared.updatePhoneNumber(normalized)
                    step = .notifications
                case .notifications:
                    if !notificationsEnabled && !hasRequestedNotifications {
                        await requestNotifications()
                    }
                    step = .contacts
                case .contacts:
                    if !contactsUploaded && !hasRequestedContacts {
                        await requestContactsAndUpload()
                    }
                    FastAPIClient.shared.markProfileSetupComplete()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func requestNotifications() async {
        hasRequestedNotifications = true
        let granted = await NotificationManager.shared.requestPermissionAndRegister()
        notificationsEnabled = granted
    }

    private func requestContactsAndUpload() async {
        hasRequestedContacts = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ContactsManager.shared.requestAccess { granted in
                continuation.resume(returning: ())
                if granted {
                    Task { await uploadContacts() }
                } else {
                    contactsUploaded = true
                }
            }
        }
    }

    @MainActor
    private func uploadContacts() async {
        guard let userId = FastAPIClient.shared.currentUser?.id else { return }
        let hashes = ContactsManager.shared.fetchPhoneHashes(pepper: SupabaseConfiguration.contactPepper)
        guard !hashes.isEmpty else {
            contactsUploaded = true
            return
        }
        let payloads = hashes.map { ContactHashPayload(user_id: userId, contact_hash: $0, display_name: nil) }
        do {
            try await FastAPIClient.shared.uploadContacts(payloads)
            contactsUploaded = true
        } catch {
            errorMessage = "Could not upload contacts: \(error.localizedDescription)"
        }
    }

    private func normalizePhone(_ input: String) -> String {
        let digits = input.filter { "0123456789".contains($0) }
        if digits.count == 10 {
            return "+1" + digits
        }
        if digits.hasPrefix("1") && digits.count == 11 {
            return "+" + digits
        }
        if input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") {
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return digits
    }

    private func syncStateWithCurrentUser() {
        guard let user = apiClient.currentUser else { return }

        if displayName.isEmpty {
            displayName = user.displayName
        }

        if phoneNumber.isEmpty {
            phoneNumber = user.phone
        }

        if !hasAutoCompleted {
            let needsName = user.displayName.isDefaultHiveDisplayName
            let needsPhone = user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if needsName {
                step = .name
            } else if needsPhone {
                step = .phone
            }
        }
    }

    private func maybeCompleteIfProfileReady() {
        guard !hasAutoCompleted else { return }
        guard let user = apiClient.currentUser else { return }

        let hasName = !user.displayName.isDefaultHiveDisplayName
        let hasPhone = !user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasName && hasPhone {
            hasAutoCompleted = true
            apiClient.markProfileSetupComplete()
        }
    }
}

private struct NameStepView: View {
    @Binding var name: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("What should we call you?")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)

            TextField("Bee Wonder", text: $name)
                .textInputAutocapitalization(.words)
                .foregroundColor(.black)
                .font(HiveTypography.body)
                .padding(HiveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(Color.white)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
    }
}

private struct PhoneStepView: View {
    @Binding var phoneNumber: String
    @StateObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Add your phone number")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            TextField("(555) 123-4567", text: $phoneNumber)
                .keyboardType(.phonePad)
                .focused($isFocused)
                .foregroundColor(.black)
                .font(HiveTypography.body)
                .padding(HiveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(Color.white)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
                .onAppear { isFocused = true }
        }
    }
}

private struct ContactsStepView: View {
    @Binding var contactsUploaded: Bool
    let onImport: () async -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Upload contacts to find your hive")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)

            VStack(spacing: HiveSpacing.md) {
                Button {
                    Task {
                        isProcessing = true
                        await onImport()
                        isProcessing = false
                    }
                } label: {
                    HStack(spacing: HiveSpacing.sm) {
                        Image(systemName: "person.2.fill")
                        Text(contactsUploaded ? "Contacts Added" : "Upload Contacts")
                    }
                    .font(HiveTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .fill(themeManager.currentTheme.primaryGradient)
                            .opacity(contactsUploaded ? 0.6 : 1)
                    )
                    .shadow(color: HiveColors.honeyGradientEnd.opacity(0.22), radius: 14, x: 0, y: 8)
                }
                .disabled(isProcessing || contactsUploaded)

                Text("We'll only store salted hashes—never the raw numbers.")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            }
        }
    }
}

private struct NotificationsStepView: View {
    @Binding var notificationsEnabled: Bool
    let onRequest: () async -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Get reminders to stay on track")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)

            VStack(spacing: HiveSpacing.md) {
                Button {
                    Task {
                        isProcessing = true
                        await onRequest()
                        isProcessing = false
                    }
                } label: {
                    HStack(spacing: HiveSpacing.sm) {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell")
                        Text(notificationsEnabled ? "Notifications Enabled" : "Enable Notifications")
                    }
                    .font(HiveTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .fill(themeManager.currentTheme.primaryGradient)
                            .opacity(notificationsEnabled ? 0.6 : 1)
                    )
                    .shadow(color: HiveColors.honeyGradientEnd.opacity(0.22), radius: 14, x: 0, y: 8)
                }
                .disabled(isProcessing || notificationsEnabled)

                Text("We'll send gentle reminders to help you stay consistent.")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            }
        }
    }
}
