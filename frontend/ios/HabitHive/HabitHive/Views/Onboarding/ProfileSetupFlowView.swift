import SwiftUI
import Contacts
import UserNotifications

struct ProfileSetupFlowView: View {
    private enum Step: Int, CaseIterable {
        case name, phone, notifications, contacts, habitTemplates

        var title: String {
            switch self {
            case .name: return "Your name"
            case .phone: return "Your phone"
            case .notifications: return "Stay motivated"
            case .contacts: return "Find friends"
            case .habitTemplates: return "Your first habits"
            }
        }
    }

    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var apiClient = FastAPIClient.shared
    @State private var step: Step = .name
    @State private var completedSteps: Set<Step> = []
    @State private var displayName: String
    @State private var phoneNumber: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var contactsUploaded = false
    @State private var hasRequestedContacts = false
    @State private var notificationsEnabled = false
    @State private var hasRequestedNotifications = false
    @State private var hasAutoCompleted = false
    @State private var showTemplateSelection = false

    init() {
        let currentUser = FastAPIClient.shared.currentUser
        _displayName = State(initialValue: currentUser?.displayName ?? "")
        _phoneNumber = State(initialValue: currentUser?.phone ?? "")

        var initialCompleted: Set<Step> = []

        if let currentUser {
            let needsName = currentUser.displayName.isDefaultHiveDisplayName
            let needsPhone = currentUser.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if !needsName {
                initialCompleted.insert(.name)
            }
            if !needsPhone {
                initialCompleted.insert(.phone)
            }

            if needsName {
                _step = State(initialValue: .name)
            } else if needsPhone {
                _step = State(initialValue: .phone)
            } else {
                _step = State(initialValue: .notifications)
            }
        } else {
            _step = State(initialValue: .name)
        }

        _completedSteps = State(initialValue: initialCompleted)
    }

    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.top, HiveSpacing.xl)

                Spacer()

                VStack(spacing: HiveSpacing.lg) {
                    switch step {
                    case .name:
                        NameStepView(name: $displayName)
                    case .phone:
                        PhoneStepView(phoneNumber: $phoneNumber)
                    case .notifications:
                        NotificationsStepView(notificationsEnabled: $notificationsEnabled, onRequest: requestNotifications)
                    case .contacts:
                        ContactsStepView(contactsUploaded: $contactsUploaded, onImport: uploadContacts)
                    case .habitTemplates:
                        EmptyView() // Template selection is shown as full screen
                    }
                }
                .padding(.horizontal, HiveSpacing.lg)

                Spacer()

                VStack(spacing: HiveSpacing.md) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(HiveTypography.caption)
                            .foregroundColor(HiveColors.error)
                            .transition(.opacity)
                    }

                    primaryButton
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
            }
        }
        .fullScreenCover(isPresented: $showTemplateSelection) {
            HabitTemplateSelectionView(
                onComplete: { templates in
                    Task {
                        await createHabitsFromTemplates(templates)
                        showTemplateSelection = false
                        completedSteps.insert(.habitTemplates)
                        FastAPIClient.shared.markProfileSetupComplete()
                    }
                },
                onSkip: {
                    showTemplateSelection = false
                    completedSteps.insert(.habitTemplates)
                    FastAPIClient.shared.markProfileSetupComplete()
                }
            )
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
            Text(buttonText)
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
        .opacity(step == .habitTemplates ? 0 : 1)
    }

    private var buttonText: String {
        switch step {
        case .habitTemplates:
            return "Continue"
        case .contacts:
            return "Continue"
        default:
            return "Continue"
        }
    }

    private func handlePrimaryAction() {
        Task { @MainActor in
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
                    completedSteps.insert(.name)
                    step = .phone
                case .phone:
                    let normalized = normalizePhone(phoneNumber)
                    guard !normalized.isEmpty else {
                        errorMessage = "Enter a valid phone number so friends can find you."
                        isSubmitting = false
                        return
                    }
                    try await FastAPIClient.shared.updatePhoneNumber(normalized)
                    completedSteps.insert(.phone)
                    step = .notifications
                case .notifications:
                    // Notifications are auto-requested on appear, just move to next step
                    completedSteps.insert(.notifications)
                    step = .contacts
                case .contacts:
                    // Contacts are auto-requested on appear, move to habit templates
                    completedSteps.insert(.contacts)
                    step = .habitTemplates
                    showTemplateSelection = true
                case .habitTemplates:
                    // This is handled by the template selection view
                    break
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

    @MainActor
    private func createHabitsFromTemplates(_ templates: [HabitTemplate]) async {
        for template in templates {
            let habitRequest = CreateHabitRequest(
                name: template.name,
                emoji: template.emoji,
                colorHex: template.colorHex,
                type: .checkbox,
                targetPerDay: 1,
                scheduleDaily: true,
                scheduleWeekmask: 127, // All days of the week
                reminderEnabled: false,
                reminderTime: nil
            )

            do {
                _ = try await FastAPIClient.shared.createHabit(habitRequest)
            } catch {
                print("Failed to create habit from template: \(template.name), error: \(error)")
            }
        }
    }

    private func syncStateWithCurrentUser() {
        guard let user = apiClient.currentUser else { return }

        if displayName.isEmpty {
            displayName = user.displayName
        }

        if phoneNumber.isEmpty {
            phoneNumber = user.phone
        }

        let needsName = user.displayName.isDefaultHiveDisplayName
        let needsPhone = user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if !needsName {
            completedSteps.insert(.name)
        }
        if !needsPhone {
            completedSteps.insert(.phone)
        }

        if !hasAutoCompleted {
            if needsName && !completedSteps.contains(.name) {
                step = .name
            } else if needsPhone && !completedSteps.contains(.phone) {
                step = .phone
            } else if step.rawValue < Step.notifications.rawValue {
                step = .notifications
            }
        }
    }

    private func maybeCompleteIfProfileReady() {
        guard !hasAutoCompleted else { return }
        guard let user = apiClient.currentUser else { return }

        let hasName = !user.displayName.isDefaultHiveDisplayName
        let hasPhone = !user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasName {
            completedSteps.insert(.name)
        }
        if hasPhone {
            completedSteps.insert(.phone)
        }

        // Don't auto-complete - let user go through all steps including notifications, contacts, and habit templates
        // The onboarding will complete only when user explicitly goes through all steps
    }
}

private struct NameStepView: View {
    @Binding var name: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: HiveSpacing.md) {
            Text("What should we call you?")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)

            TextField("Bee Wonder", text: $name)
                .textInputAutocapitalization(.words)
                .foregroundColor(.black)
                .font(HiveTypography.body)
                .multilineTextAlignment(.center)
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
        VStack(spacing: HiveSpacing.md) {
            Text("Add your phone number")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
            TextField("(555) 123-4567", text: $phoneNumber)
                .keyboardType(.phonePad)
                .focused($isFocused)
                .foregroundColor(.black)
                .font(HiveTypography.body)
                .multilineTextAlignment(.center)
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
    @State private var hasRequestedAutomatically = false

    var body: some View {
        VStack(spacing: HiveSpacing.md) {
            Text("Upload contacts to find your hive")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)

            VStack(spacing: HiveSpacing.md) {
                HStack(spacing: HiveSpacing.sm) {
                    Image(systemName: "person.2.fill")
                    Text(contactsUploaded ? "Contacts Added" : "Requesting Permissions...")
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

                Text("We'll only store salted hashes—never the raw numbers.")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            if !hasRequestedAutomatically && !contactsUploaded {
                hasRequestedAutomatically = true
                Task {
                    await onImport()
                }
            }
        }
    }
}

private struct NotificationsStepView: View {
    @Binding var notificationsEnabled: Bool
    let onRequest: () async -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var hasRequestedAutomatically = false

    var body: some View {
        VStack(spacing: HiveSpacing.md) {
            Text("Get reminders to stay on track")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)

            VStack(spacing: HiveSpacing.md) {
                HStack(spacing: HiveSpacing.sm) {
                    Image(systemName: notificationsEnabled ? "bell.fill" : "bell")
                    Text(notificationsEnabled ? "Notifications Enabled" : "Requesting Permissions...")
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

                Text("We'll send gentle reminders to help you stay consistent.")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            if !hasRequestedAutomatically && !notificationsEnabled {
                hasRequestedAutomatically = true
                Task {
                    await onRequest()
                }
            }
        }
    }
}
