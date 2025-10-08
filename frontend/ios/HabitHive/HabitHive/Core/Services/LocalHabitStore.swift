import Foundation

actor LocalHabitStore {
    enum SyncStatus: String, Codable {
        case pending
        case synced
        case deleted
    }

    struct HabitRecord: Codable {
        var id: String
        var name: String
        var emoji: String?
        var colorHex: String
        var typeRaw: String
        var targetPerDay: Int
        var scheduleDaily: Bool
        var scheduleWeekmask: Int
        var reminderEnabled: Bool
        var reminderTime: String?
        var isActive: Bool
        var createdAt: Date
        var updatedAt: Date
        var remoteId: String?
        var syncStatus: SyncStatus
        var logs: [LogRecord]

        mutating func touch() {
            updatedAt = Date()
        }
    }

    struct LogRecord: Codable {
        var id: String
        var habitId: String
        var logDate: String
        var value: Int
        var createdAt: Date
        var remoteId: String?
        var syncStatus: SyncStatus
    }

    struct PersistedState: Codable {
        var habits: [HabitRecord]
    }

    static let shared = LocalHabitStore()

    private let storageURL: URL
    private var state = PersistedState(habits: [])
    private var hasLoaded = false
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        storageURL = directory.appendingPathComponent("habithive_local_habits.json")

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    }

    // MARK: - Public API

    func fetchHabits() async throws -> [Habit] {
        try await loadIfNeeded()
        return state.habits
            .filter { $0.syncStatus != .deleted }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.asHabit() }
    }

    func createHabit(from request: CreateHabitRequest) async throws -> Habit {
        try await loadIfNeeded()
        let now = Date()
        var record = HabitRecord(
            id: UUID().uuidString,
            name: request.name,
            emoji: request.emoji,
            colorHex: request.colorHex,
            typeRaw: request.type.rawValue,
            targetPerDay: request.targetPerDay,
            scheduleDaily: request.scheduleDaily,
            scheduleWeekmask: request.scheduleWeekmask,
            reminderEnabled: request.reminderEnabled,
            reminderTime: request.reminderTime,
            isActive: true,
            createdAt: now,
            updatedAt: now,
            remoteId: nil,
            syncStatus: .pending,
            logs: []
        )
        state.habits.insert(record, at: 0)
        try await persist()
        return record.asHabit()
    }

    func deleteHabit(id: String) async throws {
        try await loadIfNeeded()
        guard let index = state.habits.firstIndex(where: { $0.id == id }) else { return }
        state.habits.remove(at: index)
        try await persist()
    }

    func logHabit(habitId: String, value: Int, on date: Date = Date()) async throws -> HabitLog {
        try await loadIfNeeded()
        guard let index = state.habits.firstIndex(where: { $0.id == habitId }) else {
            throw LocalStoreError.habitNotFound
        }

        let dayKey = LocalHabitStore.dayFormatter.string(from: date)
        var habit = state.habits[index]

        if let logIndex = habit.logs.firstIndex(where: { $0.logDate == dayKey }) {
            var log = habit.logs[logIndex]
            log.value = value
            log.createdAt = date
            log.syncStatus = .pending
            habit.logs[logIndex] = log
            habit.touch()
            state.habits[index] = habit
            try await persist()
            return log.asHabitLog(userId: LocalHabitStore.localUserId)
        } else {
            let log = LogRecord(
                id: UUID().uuidString,
                habitId: habitId,
                logDate: dayKey,
                value: value,
                createdAt: date,
                remoteId: nil,
                syncStatus: .pending
            )
            habit.logs.append(log)
            habit.touch()
            state.habits[index] = habit
            try await persist()
            return log.asHabitLog(userId: LocalHabitStore.localUserId)
        }
    }

    func deleteHabitLog(habitId: String, logDate: String) async throws {
        try await loadIfNeeded()
        guard let habitIndex = state.habits.firstIndex(where: { $0.id == habitId }) else { return }
        var habit = state.habits[habitIndex]

        guard let logIndex = habit.logs.firstIndex(where: { $0.logDate == logDate }) else { return }
        habit.logs.remove(at: logIndex)
        habit.touch()
        state.habits[habitIndex] = habit
        try await persist()
    }

    func upsertHabitRemoteMapping(localId: String, remoteId: String) async throws {
        try await loadIfNeeded()
        guard let index = state.habits.firstIndex(where: { $0.id == localId }) else { return }
        state.habits[index].remoteId = remoteId
        state.habits[index].syncStatus = .synced
        try await persist()
    }

    func upsertLogRemoteMapping(localId: String, remoteId: String) async throws {
        try await loadIfNeeded()
        guard let habitIndex = state.habits.firstIndex(where: { $0.logs.contains(where: { $0.id == localId }) }) else { return }
        guard let logIndex = state.habits[habitIndex].logs.firstIndex(where: { $0.id == localId }) else { return }
        state.habits[habitIndex].logs[logIndex].remoteId = remoteId
        state.habits[habitIndex].logs[logIndex].syncStatus = .synced
        try await persist()
    }

    func habit(for id: String) async throws -> Habit? {
        try await loadIfNeeded()
        return state.habits.first(where: { $0.id == id })?.asHabit()
    }

    func pendingHabits() async throws -> [HabitRecord] {
        try await loadIfNeeded()
        return state.habits.filter { $0.syncStatus == .pending }
    }

    func pendingLogs() async throws -> [LogRecord] {
        try await loadIfNeeded()
        return state.habits.flatMap { habit in
            habit.logs.filter { $0.syncStatus == .pending }
        }
    }

    func remoteHabitId(for localId: String) async throws -> String? {
        try await loadIfNeeded()
        return state.habits.first(where: { $0.id == localId })?.remoteId
    }

    // MARK: - Private helpers

    private func loadIfNeeded() async throws {
        guard !hasLoaded else { return }
        defer { hasLoaded = true }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: storageURL.path) {
            state = PersistedState(habits: [])
            return
        }

        let data = try Data(contentsOf: storageURL)
        state = try decoder.decode(PersistedState.self, from: data)
    }

    private func persist() async throws {
        let data = try encoder.encode(state)
        let fileManager = FileManager.default
        let directory = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: storageURL, options: [.atomic])
    }

    // MARK: - Static helpers

    private static let localUserId = "local-user"

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Conversions

extension LocalHabitStore.HabitRecord {
    func asHabit() -> Habit {
        let logs = self.logs
            .filter { $0.syncStatus != .deleted }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.asHabitLog(userId: LocalHabitStore.localUserId) }

        return Habit(
            id: id,
            userId: LocalHabitStore.localUserId,
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            type: HabitType(rawValue: typeRaw) ?? .checkbox,
            targetPerDay: targetPerDay,
            scheduleDaily: scheduleDaily,
            scheduleWeekmask: scheduleWeekmask,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderTime,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recentLogs: logs,
            currentStreak: nil,
            completionRate: nil
        )
    }

    func createRequest() -> CreateHabitRequest {
        CreateHabitRequest(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            type: HabitType(rawValue: typeRaw) ?? .checkbox,
            targetPerDay: targetPerDay,
            scheduleDaily: scheduleDaily,
            scheduleWeekmask: scheduleWeekmask,
            reminderEnabled: reminderEnabled,
            reminderTime: reminderTime
        )
    }
}

private extension LocalHabitStore.LogRecord {
    func asHabitLog(userId: String) -> HabitLog {
        HabitLog(
            id: id,
            habitId: habitId,
            userId: userId,
            logDate: logDate,
            value: value,
            source: "local",
            createdAt: createdAt
        )
    }
}

enum LocalStoreError: LocalizedError {
    case habitNotFound

    var errorDescription: String? {
        switch self {
        case .habitNotFound:
            return "Habit not found in local store."
        }
    }
}
