//
//  SyncCoordinatorTests.swift
//  HabitHiveTests
//
//  Created by AI Assistant on 10/30/23.
//

import Foundation
import Testing
@testable import HabitHive

@MainActor
struct SyncCoordinatorTests {

    @Test
    func migratesGuestHabitsAndLogsOnAuthentication() async throws {
        let habitRecord = LocalHabitStore.HabitRecord(
            id: "local-habit-1",
            name: "Morning Stretch",
            emoji: "🧘",
            colorHex: "#FF9F1C",
            typeRaw: HabitType.checkbox.rawValue,
            targetPerDay: 1,
            scheduleDaily: true,
            scheduleWeekmask: 127,
            reminderEnabled: false,
            reminderTime: nil,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            remoteId: nil,
            syncStatus: .pending,
            logs: []
        )

        let logRecord = LocalHabitStore.LogRecord(
            id: "local-log-1",
            habitId: "local-habit-1",
            logDate: "2024-01-01",
            value: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            remoteId: nil,
            syncStatus: .pending
        )

        let localStore = TestLocalHabitStore(habits: [habitRecord], logs: [logRecord])

        let remoteHabit = Habit(
            id: "remote-habit-1",
            userId: "user-123",
            name: habitRecord.name,
            emoji: habitRecord.emoji,
            colorHex: habitRecord.colorHex,
            type: HabitType(rawValue: habitRecord.typeRaw) ?? .checkbox,
            targetPerDay: habitRecord.targetPerDay,
            scheduleDaily: habitRecord.scheduleDaily,
            scheduleWeekmask: habitRecord.scheduleWeekmask,
            reminderEnabled: false,
            reminderTime: nil,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200),
            recentLogs: []
        )

        let remoteLog = HabitLog(
            id: "remote-log-1",
            habitId: remoteHabit.id,
            userId: remoteHabit.userId,
            logDate: logRecord.logDate,
            value: logRecord.value,
            source: "api",
            createdAt: Date(timeIntervalSince1970: 300)
        )

        let apiClient = TestHabitAPIClient(
            habitResponses: [remoteHabit],
            logResponses: [remoteLog]
        )

        let coordinator = SyncCoordinator(localStore: localStore, apiClient: apiClient)

        let task = coordinator.handleTransition(from: .guest, to: .authenticated)
        await task?.value

        let mappedHabitId = await localStore.habitRemoteMapping(for: "local-habit-1")
        #expect(mappedHabitId == "remote-habit-1")

        let mappedLogId = await localStore.logRemoteMapping(for: "local-log-1")
        #expect(mappedLogId == "remote-log-1")

        #expect(apiClient.createHabitRequests.count == 1)
        #expect(apiClient.createHabitRequests.first?.name == "Morning Stretch")
        #expect(apiClient.logHabitRequests.count == 1)
        #expect(apiClient.logHabitRequests.first?.habitId == "remote-habit-1")
    }

    @Test
    func doesNotRunMigrationForOtherTransitions() async throws {
        let localStore = TestLocalHabitStore(habits: [], logs: [])
        let apiClient = TestHabitAPIClient(habitResponses: [], logResponses: [])
        let coordinator = SyncCoordinator(localStore: localStore, apiClient: apiClient)

        let task = coordinator.handleTransition(from: .welcome, to: .guest)
        #expect(task == nil)
        #expect(apiClient.createHabitRequests.isEmpty)
        #expect(apiClient.logHabitRequests.isEmpty)
    }
}

// MARK: - Test doubles

private actor TestLocalHabitStore: LocalHabitStoreProtocol {
    private var habits: [LocalHabitStore.HabitRecord]
    private var logs: [LocalHabitStore.LogRecord]
    private var habitMappings: [String: String] = [:]
    private var logMappings: [String: String] = [:]

    init(habits: [LocalHabitStore.HabitRecord], logs: [LocalHabitStore.LogRecord]) {
        self.habits = habits
        self.logs = logs
    }

    func pendingHabits() async throws -> [LocalHabitStore.HabitRecord] {
        habits
    }

    func pendingLogs() async throws -> [LocalHabitStore.LogRecord] {
        logs
    }

    func upsertHabitRemoteMapping(localId: String, remoteId: String) async throws {
        habitMappings[localId] = remoteId
    }

    func remoteHabitId(for localId: String) async throws -> String? {
        habitMappings[localId]
    }

    func upsertLogRemoteMapping(localId: String, remoteId: String) async throws {
        logMappings[localId] = remoteId
    }

    func habitRemoteMapping(for id: String) async -> String? {
        habitMappings[id]
    }

    func logRemoteMapping(for id: String) async -> String? {
        logMappings[id]
    }
}

@MainActor
private final class TestHabitAPIClient: HabitSyncingClient {
    private(set) var createHabitRequests: [CreateHabitRequest] = []
    private(set) var logHabitRequests: [(habitId: String, value: Int, date: Date?)] = []

    private var habitResponses: [Habit]
    private var logResponses: [HabitLog]

    init(habitResponses: [Habit], logResponses: [HabitLog]) {
        self.habitResponses = habitResponses
        self.logResponses = logResponses
    }

    func createHabit(_ habit: CreateHabitRequest) async throws -> Habit {
        createHabitRequests.append(habit)
        guard !habitResponses.isEmpty else {
            fatalError("No stubbed habit response available.")
        }
        return habitResponses.removeFirst()
    }

    func logHabit(habitId: String, value: Int, on date: Date?) async throws -> HabitLog {
        logHabitRequests.append((habitId, value, date))
        guard !logResponses.isEmpty else {
            fatalError("No stubbed log response available.")
        }
        return logResponses.removeFirst()
    }
}
