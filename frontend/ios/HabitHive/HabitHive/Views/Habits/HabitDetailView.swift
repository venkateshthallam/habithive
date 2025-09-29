import SwiftUI

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HabitDetailViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedMonth = Date()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var currentHabit: Habit

    init(habit: Habit) {
        self.habit = habit
        _currentHabit = State(initialValue: habit)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: HiveSpacing.lg) {
                        // Header Card
                        headerCard
                        
                        // Stats Cards
                        statsSection
                        
                        // Month Calendar
                        monthCalendarSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding(HiveSpacing.md)
                }
            }
            .navigationTitle(currentHabit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showEditSheet = true
                    }) {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(with: habit)
            viewModel.loadHabitDetails(habitId: habit.id)
        }
        .refreshable {
            viewModel.loadHabitDetails(habitId: habit.id)
        }
        .onReceive(viewModel.$habit.compactMap { $0 }) { updated in
            currentHabit = updated
        }
        .alert("Delete Habit", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteHabit(habitId: currentHabit.id) {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this habit? This action cannot be undone.")
        }
    }
    
    // MARK: - Components
    
    private var headerCard: some View {
        VStack(spacing: HiveSpacing.md) {
            // Emoji & Progress
            ZStack {
                Circle()
                    .fill(currentHabit.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if currentHabit.type == .counter {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: viewModel.todayProgress)
                            .stroke(currentHabit.color, lineWidth: 6)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: viewModel.todayProgress)
                    }
                    .frame(width: 100, height: 100)
                }
                
                Text(currentHabit.emoji ?? "🎯")
                    .font(.system(size: 50))
            }
            
            // Today's Status
            if currentHabit.type == .counter {
                VStack(spacing: HiveSpacing.xs) {
                    Text("\(viewModel.todayValue) / \(currentHabit.targetPerDay)")
                        .font(HiveTypography.title2)
                        .foregroundColor(HiveColors.slateText)
                    
                    Text("Today")
                        .font(HiveTypography.caption)
                        .foregroundColor(HiveColors.slateText.opacity(0.7))
                }
            } else {
                HStack(spacing: HiveSpacing.sm) {
                    Image(systemName: viewModel.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.isCompletedToday ? HiveColors.mintSuccess : Color.gray.opacity(0.5))
                    
                    Text(viewModel.isCompletedToday ? "Completed" : "Not completed")
                        .font(HiveTypography.headline)
                        .foregroundColor(HiveColors.slateText)
                }
            }
            
            // Log Button
            Button(action: {
                viewModel.toggleToday(for: currentHabit)
            }) {
                HStack {
                    Image(systemName: viewModel.isCompletedToday ? "arrow.uturn.backward" : (currentHabit.type == .checkbox ? "checkmark" : "drop.fill"))
                    Text(viewModel.isCompletedToday ? "Unmark Today" : (currentHabit.type == .checkbox ? "Mark Complete" : "Add +\(currentHabit.targetPerDay)"))
                }
                .font(HiveTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.sm)
                .background(themeManager.currentTheme.primaryGradient)
                .cornerRadius(HiveRadius.medium)
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }
    
    private var statsSection: some View {
        HStack(spacing: HiveSpacing.sm) {
            StatCard(
                title: "Current Streak",
                value: "\(currentHabit.currentStreak ?? 0)",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Completion",
                value: "\(Int(currentHabit.completionRate ?? 0))%",
                icon: "chart.pie.fill",
                color: currentHabit.color
            )
            
            StatCard(
                title: "Total Days",
                value: "\(viewModel.totalDays)",
                icon: "calendar",
                color: HiveColors.skyAccent
            )
        }
    }
    
    private var monthCalendarSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            // Month selector
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(HiveColors.slateText)
                }
                
                Spacer()
                
                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(HiveTypography.headline)
                    .foregroundColor(HiveColors.slateText)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(HiveColors.slateText)
                        .opacity(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
                }
                .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }
            
            // Calendar grid
            MonthCalendarView(
                month: selectedMonth,
                habit: habit,
                logs: viewModel.logs
            )
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: HiveSpacing.sm) {
            // Convert to Hive
            Button(action: {
                viewModel.convertToHive(habitId: currentHabit.id)
            }) {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Create a Hive")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(HiveTypography.callout)
                .foregroundColor(HiveColors.slateText)
                .padding(HiveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 3)
                )
            }
            
            // Delete Habit
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Habit")
                    Spacer()
                }
                .font(HiveTypography.callout)
                .foregroundColor(HiveColors.error)
                .padding(HiveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                        .fill(HiveColors.error.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: HiveSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(HiveTypography.title3)
                .foregroundColor(HiveColors.slateText)
            
            Text(title)
                .font(HiveTypography.caption2)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(HiveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 3)
        )
    }
}

// MARK: - Month Calendar View
struct MonthCalendarView: View {
    let month: Date
    let habit: Habit
    let logs: [HabitLog]
    
    private let weekDays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        let days = getDaysInMonth()
        VStack(spacing: HiveSpacing.xs) {
            // Week day headers
            HStack(spacing: HiveSpacing.xs) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(HiveTypography.caption2)
                        .foregroundColor(HiveColors.slateText.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HiveSpacing.xs), count: 7), spacing: HiveSpacing.xs) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            habit: habit,
                            isCompleted: isDateCompleted(date),
                            value: getValueForDate(date)
                        )
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let numberOfDays = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining cells
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func isDateCompleted(_ date: Date) -> Bool {
        let dateString = DateFormatter.hiveDayFormatter.string(from: date)
        return logs.contains { $0.logDate == dateString }
    }
    
    private func getValueForDate(_ date: Date) -> Int {
        let dateString = DateFormatter.hiveDayFormatter.string(from: date)
        return logs.first { $0.logDate == dateString }?.value ?? 0
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let habit: Habit
    let isCompleted: Bool
    let value: Int
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveRadius.small)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.small)
                        .stroke(isToday ? habit.color : Color.clear, lineWidth: 2)
                )
            
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(HiveTypography.caption)
                    .foregroundColor(textColor)
                
                if habit.type == .counter && isCompleted {
                    Text("\(value)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(habit.color)
                }
            }
        }
        .frame(height: 40)
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return habit.color.opacity(0.8)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        if isCompleted {
            return .white
        } else if isToday {
            return habit.color
        } else {
            return HiveColors.slateText
        }
    }
}

// MARK: - View Model
class HabitDetailViewModel: ObservableObject {
    @Published var habit: Habit?
    @Published var logs: [HabitLog] = []
    @Published var todayValue = 0
    @Published var isCompletedToday = false
    @Published var totalDays = 0
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let apiClient = FastAPIClient.shared

    var todayProgress: CGFloat {
        guard let habit else { return isCompletedToday ? 1 : 0 }
        guard habit.type == .counter else { return isCompletedToday ? 1 : 0 }
        let target = max(habit.targetPerDay, 1)
        return CGFloat(min(todayValue, target)) / CGFloat(target)
    }

    @MainActor
    func configure(with habit: Habit) {
        self.habit = habit
        self.logs = habit.recentLogs ?? []
        calculateStats(for: habit)
    }

    func loadHabitDetails(habitId: String) {
        Task { await loadHabitDetailsAsync(habitId: habitId) }
    }

    @MainActor
    private func loadHabitDetailsAsync(habitId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let habit = try await apiClient.getHabit(habitId: habitId, includeLogs: true)
            self.habit = habit
            self.logs = habit.recentLogs ?? []
            self.calculateStats(for: habit)
            let history = try await fetchLogs(habitId: habitId)
            self.logs = history.sorted { $0.logDate < $1.logDate }
            self.calculateStats(for: habit)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func fetchLogs(habitId: String) async throws -> [HabitLog] {
        let startDate = Calendar.current.date(byAdding: .month, value: -12, to: Date())
        return try await apiClient.getHabitLogs(habitId: habitId, startDate: startDate, endDate: nil)
    }

    private func calculateStats(for habit: Habit) {
        let today = DateFormatter.hiveDayFormatter.string(from: Date())
        print("🔍 Detail view calculateStats - today: \(today), logs: \(logs.map { $0.logDate })")
        if let todayLog = logs.first(where: { $0.logDate == today }) {
            todayValue = todayLog.value
            let threshold = habit.type == .counter ? habit.targetPerDay : 1
            isCompletedToday = todayLog.value >= max(threshold, 1)
            print("🔍 Detail view - found today's log, isCompleted: \(isCompletedToday)")
        } else {
            todayValue = 0
            isCompletedToday = false
            print("🔍 Detail view - no log found for today, isCompleted: false")
        }

        totalDays = Set(logs.map { $0.logDate }).count
    }

    func toggleToday(for habit: Habit) {
        let todayString = DateFormatter.hiveDayFormatter.string(from: Date())

        if let existingIndex = logs.firstIndex(where: { $0.logDate == todayString }) {
            let removedLog = logs.remove(at: existingIndex)
            calculateStats(for: habit)

            let logDate = DateFormatter.hiveDayFormatter.date(from: removedLog.logDate)
            Task {
                do {
#if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
                    try await apiClient.deleteHabitLog(habitId: habit.id, logDate: logDate)
                    await loadHabitDetailsAsync(habitId: habit.id)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        } else {
            let value = habit.type == .counter ? habit.targetPerDay : 1
            let provisionalLog = HabitLog(
                id: UUID().uuidString,
                habitId: habit.id,
                userId: habit.userId,
                logDate: todayString,
                value: value,
                source: "manual",
                createdAt: Date()
            )
            logs.append(provisionalLog)
            logs.sort { $0.logDate < $1.logDate }
            calculateStats(for: habit)

            Task {
                do {
#if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
#endif
                    _ = try await apiClient.logHabit(habitId: habit.id, value: value)
                    await loadHabitDetailsAsync(habitId: habit.id)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        }
    }

    func deleteHabit(habitId: String, completion: @escaping () -> Void) {
        Task {
            do {
                try await apiClient.deleteHabit(habitId: habitId)
                await MainActor.run { completion() }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func convertToHive(habitId: String) {
        Task {
            do {
                let hive = try await apiClient.createHiveFromHabit(habitId: habitId, name: nil, backfillDays: 30)
                print("Created hive: \(hive.id)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
}

#Preview {
    HabitDetailView(
        habit: Habit(
            id: "1",
            userId: "1",
            name: "Drink Water",
            emoji: "💧",
            colorHex: "#34C8ED",
            type: .counter,
            targetPerDay: 8,
            scheduleDaily: true,
            scheduleWeekmask: 127,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
