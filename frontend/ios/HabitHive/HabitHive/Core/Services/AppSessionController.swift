import Foundation
import Combine

@MainActor
final class AppSessionController: ObservableObject {
    enum Mode: Equatable {
        case welcome
        case guest
        case authenticated
        case authenticatedNeedsProfile
    }

    static let shared = AppSessionController()

    @Published private(set) var mode: Mode
    @Published private(set) var requiresProfileSetup: Bool
    @Published private(set) var isAuthenticated: Bool

    private let apiClient = FastAPIClient.shared
    private var cancellables: Set<AnyCancellable> = []
    private let guestPreferenceKey = "appsession.guestModeSelected"

    private var guestModeSelected: Bool {
        didSet {
            UserDefaults.standard.set(guestModeSelected, forKey: guestPreferenceKey)
        }
    }

    private init() {
        let storedGuestPreference = UserDefaults.standard.bool(forKey: guestPreferenceKey)
        self.guestModeSelected = storedGuestPreference
        self.mode = .welcome
        self.requiresProfileSetup = apiClient.requiresProfileSetup
        self.isAuthenticated = apiClient.isAuthenticated

        setupBindings()
        updateMode(isAuthenticated: apiClient.isAuthenticated,
                   requiresProfile: apiClient.requiresProfileSetup)
    }

    func enterGuestMode() {
        if !guestModeSelected {
            guestModeSelected = true
        }
        mode = .guest
    }

    func requestAuthentication() {
        guestModeSelected = false
        if !apiClient.isAuthenticated {
            mode = .welcome
        }
    }

    private func setupBindings() {
        apiClient.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                self.isAuthenticated = isAuthenticated
                self.updateMode(isAuthenticated: isAuthenticated,
                                requiresProfile: self.apiClient.requiresProfileSetup)
            }
            .store(in: &cancellables)

        apiClient.$requiresProfileSetup
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requiresProfile in
                guard let self else { return }
                self.requiresProfileSetup = requiresProfile
                self.updateMode(isAuthenticated: self.apiClient.isAuthenticated,
                                requiresProfile: requiresProfile)
            }
            .store(in: &cancellables)
    }

    private func updateMode(isAuthenticated: Bool, requiresProfile: Bool) {
        let previousMode = mode
        let newMode: Mode

        if isAuthenticated {
            if guestModeSelected {
                guestModeSelected = false
            }
            newMode = requiresProfile ? .authenticatedNeedsProfile : .authenticated
        } else {
            newMode = guestModeSelected ? .guest : .welcome
        }

        guard previousMode != newMode else { return }

        mode = newMode

        if let migrationTask = SyncCoordinator.shared.handleTransition(from: previousMode, to: newMode) {
            Task {
                await migrationTask.value
                print("✅ Guest data migration completed")
            }
        }
    }
}
