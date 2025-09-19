import SwiftUI
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var seedSelections: Set<String> = []
    @Published var dayStartHour: Int = 4
    @Published var timezone: String = TimeZone.current.identifier
    @Published var contactsUploaded = false
    @Published var step: Int = 0
    let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    // Theme fixed to honey; no-op

    func createSeedHabits(completion: @escaping () -> Void) {
        let seeds = seedSelections
        let publishers = seeds.map { name in
            api.createHabit(CreateHabitRequest(name: name, emoji: defaultEmoji(for: name), colorHex: "#FF9F1C", type: .checkbox, targetPerDay: 1, scheduleDaily: true, scheduleWeekmask: 127))
        }
        Publishers.MergeMany(publishers).collect().sink(receiveCompletion: { _ in completion() }, receiveValue: { _ in }).store(in: &cancellables)
    }

    func saveDayStart() {
        let update = ProfileUpdate(displayName: nil, avatarUrl: nil, timezone: timezone, dayStartHour: dayStartHour, theme: nil)
        _ = api.updateProfile(update).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    }

    func uploadContacts(hashes: [String]) {
        let payload = hashes.map { APIClient.ContactHash(contact_hash: $0, display_name: nil) }
        _ = api.uploadContacts(payload).sink(receiveCompletion: { _ in }, receiveValue: { _ in self.contactsUploaded = true })
    }

    private func defaultEmoji(for name: String) -> String? {
        switch name.lowercased() {
        case "drink water": return "💧"
        case "walk": return "🚶"
        case "read": return "📚"
        case "meditate": return "🧘"
        default: return "🍯"
        }
    }
}

struct OnboardingFlowView: View {
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        VStack {
            TabView(selection: $vm.step) {
                OnboardingSeedHabitsView(selections: $vm.seedSelections) {
                    vm.createSeedHabits { vm.step = 1 }
                }.tag(0)

                OnboardingNameView { name in
                    let update = ProfileUpdate(displayName: name)
                    _ = vm.api.updateProfile(update).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    vm.step = 2
                }.tag(1)

                OnboardingDayStartView(dayStartHour: $vm.dayStartHour, timezone: $vm.timezone) {
                    vm.saveDayStart(); vm.step = 3
                }.tag(2)

                OnboardingContactsView(onUpload: { hashes in vm.uploadContacts(hashes: hashes); vm.step = 4 }).tag(3)

                OnboardingAuthView().tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}
