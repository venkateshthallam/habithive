import Foundation

protocol LocalHabitStoreProtocol: AnyObject {
    func pendingHabits() async throws -> [LocalHabitStore.HabitRecord]
    func pendingLogs() async throws -> [LocalHabitStore.LogRecord]
    func upsertHabitRemoteMapping(localId: String, remoteId: String) async throws
    func remoteHabitId(for localId: String) async throws -> String?
    func upsertLogRemoteMapping(localId: String, remoteId: String) async throws
}

protocol HabitSyncingClient {
    func createHabit(_ habit: CreateHabitRequest) async throws -> Habit
    func logHabit(habitId: String, value: Int, on date: Date?) async throws -> HabitLog
}

extension LocalHabitStore: LocalHabitStoreProtocol {}
extension FastAPIClient: HabitSyncingClient {}

@MainActor
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    private let localStore: LocalHabitStoreProtocol
    private let apiClient: HabitSyncingClient
    private var isMigrating = false
    private var pendingGuestMigration = false

    init(
        localStore: LocalHabitStoreProtocol = LocalHabitStore.shared,
        apiClient: HabitSyncingClient = FastAPIClient.shared
    ) {
        self.localStore = localStore
        self.apiClient = apiClient
    }

    @discardableResult
    func handleTransition(from oldMode: AppSessionController.Mode, to newMode: AppSessionController.Mode) -> Task<Void, Never>? {
        if oldMode == .guest || newMode == .guest {
            pendingGuestMigration = true
        }

        guard newMode == .authenticated || newMode == .authenticatedNeedsProfile else { return nil }
        guard pendingGuestMigration else { return nil }

        pendingGuestMigration = false
        print("🔄 Triggering migration from \(oldMode) to \(newMode)")
        return Task { await migrateGuestData() }
    }

    private func migrateGuestData() async {
        guard !isMigrating else {
            print("⚠️ Migration already in progress, skipping")
            return
        }
        isMigrating = true
        defer { isMigrating = false }

        print("🔄 Starting guest data migration...")

        do {
            var localToRemote: [String: String] = [:]

            let pendingHabits = try await localStore.pendingHabits()
            print("📋 Found \(pendingHabits.count) pending habits to migrate")

            for record in pendingHabits {
                print("🔄 Migrating habit: \(record.name)")
                let request = record.createRequest()
                let remote = try await apiClient.createHabit(request)
                try await localStore.upsertHabitRemoteMapping(localId: record.id, remoteId: remote.id)
                localToRemote[record.id] = remote.id
                print("✅ Migrated habit: \(record.name) -> \(remote.id)")
            }

            let pendingLogs = try await localStore.pendingLogs()
            print("📋 Found \(pendingLogs.count) pending logs to migrate")
            let formatter = LocalHabitStore.dayFormatter

            for log in pendingLogs {
                let remoteHabitId: String
                if let mapped = localToRemote[log.habitId] {
                    remoteHabitId = mapped
                } else if let existing = try await localStore.remoteHabitId(for: log.habitId) {
                    remoteHabitId = existing
                    localToRemote[log.habitId] = existing
                } else {
                    print("⚠️ Skipping log \(log.id): no remote habit found for \(log.habitId)")
                    continue
                }

                let date = formatter.date(from: log.logDate) ?? Date()
                let remoteLog = try await apiClient.logHabit(habitId: remoteHabitId, value: log.value, on: date)
                try await localStore.upsertLogRemoteMapping(localId: log.id, remoteId: remoteLog.id)
                print("✅ Migrated log for habit \(remoteHabitId) on \(log.logDate)")
            }

            print("✅ Migration completed successfully: \(pendingHabits.count) habits, \(pendingLogs.count) logs")
        } catch {
            print("⚠️ SyncCoordinator migration failed: \(error)")
            pendingGuestMigration = true
        }
    }
}
