import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HabitsHomeView: View {
    @StateObject private var viewModel = HabitsViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showCreateHabit = false
    @State private var selectedHabit: Habit?
    @State private var showHoneyPour = false
    @State private var honeyPourHabitId: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.habits.isEmpty {
                        emptyStateView
                    } else {
                        VStack(spacing: 0) {
                            // Header
                            headerView

                            LazyVStack(spacing: HiveSpacing.lg) {
                                ForEach(viewModel.habits) { habit in
                                    HabitCardView(
                                        habit: habit,
                                        theme: themeManager.currentTheme,
                                        onLog: {
                                            handleBeeButtonTap(habit)
                                        },
                                        onOpen: {
                                            selectedHabit = habit
                                        },
                                        onLongPress: {
                                            handleHabitLongPress(habit)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, HiveSpacing.lg)
                            .padding(.bottom, HiveSpacing.xxl)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshHabits()
                }
                
                
                // Honey Pour Animation Overlay
                if showHoneyPour, let habitId = honeyPourHabitId,
                   let habit = viewModel.habits.first(where: { $0.id == habitId }) {
                    HoneyPourAnimationView(
                        habit: habit,
                        onComplete: {
                            showHoneyPour = false
                            honeyPourHabitId = nil
                            Task {
                                await viewModel.refreshHabits()
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showCreateHabit) {
            CreateHabitView { newHabit in
                viewModel.addHabitOptimistically(newHabit)
            }
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit)
        }
        .onAppear {
            viewModel.loadHabits()
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            HStack(alignment: .center) {
                HStack(spacing: HiveSpacing.xs) {
                    Text("Habit")
                        .font(HiveTypography.largeTitle)
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    Text("Hive")
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(themeManager.currentTheme.primaryGradient)
                }

                Spacer()

                Button(action: {
                    showCreateHabit = true
                }) {
                    HStack(spacing: HiveSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("New Habit")
                            .font(HiveTypography.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.modal)
                            .fill(themeManager.currentTheme.primaryGradient)
                    )
                    .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }

            Text("Tap the bee to pour honey on today")
                .font(HiveTypography.caption)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
        }
        .padding(.horizontal, HiveSpacing.lg)
        .padding(.top, HiveSpacing.lg)
        .padding(.bottom, HiveSpacing.lg)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: HiveSpacing.xl) {
            Spacer()

            // Dashed border container with bee
            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                .frame(width: 200, height: 200)
                .overlay(
                    Text("🐝")
                        .font(.system(size: 64))
                )

            VStack(spacing: HiveSpacing.sm) {
                Text("No habits yet – tap the + to start your hive!")
                    .font(HiveTypography.body)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HiveSpacing.xl)

                Button(action: {
                    showCreateHabit = true
                }) {
                    Text("Add First Habit")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, HiveSpacing.xl)
                        .padding(.vertical, HiveSpacing.md)
                        .background(themeManager.currentTheme.primaryGradient)
                        .cornerRadius(HiveRadius.xlarge)
                }
                .padding(.top, HiveSpacing.md)
            }

            Spacer()
        }
        .padding(HiveSpacing.lg)
    }

    private var loadingView: some View {
        VStack(spacing: HiveSpacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your hive...")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func handleBeeButtonTap(_ habit: Habit) {
        let todayLog = viewModel.todayLog(for: habit.id)
        if let log = todayLog {
            let removed = viewModel.optimisticToggle(habit: habit, value: log.value, adding: false)
            if removed {
                viewModel.deleteHabitLog(habitId: habit.id, logDateString: log.logDate)
            }
        } else {
            let value = habit.type == .counter ? habit.targetPerDay : 1
            let added = viewModel.optimisticToggle(habit: habit, value: value, adding: true)
            if added {
                viewModel.logHabit(habitId: habit.id, value: value)
                honeyPourHabitId = habit.id
                showHoneyPour = true
            }
        }
    }

    private func handleHabitLongPress(_ habit: Habit) {
        selectedHabit = habit
    }
    
}

// MARK: - Habit Card View
struct HabitCardView: View {
    let habit: Habit
    let theme: AppTheme
    let onLog: () -> Void
    let onOpen: () -> Void
    let onLongPress: () -> Void

    private var todayString: String {
        DateFormatter.hiveDayFormatter.string(from: Date())
    }

    private var todaysLog: HabitLog? {
        habit.recentLogs?.first(where: { $0.logDate == todayString })
    }

    private var isCompletedToday: Bool {
        todaysLog != nil && (habit.type == .checkbox || (todaysLog?.value ?? 0) >= habit.targetPerDay)
    }

    private var streakText: String? {
        guard let streak = habit.currentStreak, streak > 0 else { return nil }
        return "\(streak) day streak"
    }

    private var subtitleText: String {
        if let streak = streakText {
            return streak
        }

        if habit.type == .counter {
            return "Target \(habit.targetPerDay) / day"
        }

        return habit.scheduleDaily ? "Every day" : "Custom cadence"
    }

    private var completionText: String? {
        guard let completion = habit.completionRate else { return nil }
        return String(format: "%.0f%% overall", completion)
    }

    private var todayCountText: String {
        let value = todaysLog?.value ?? 0
        if habit.type == .counter {
            return "Today \(value)/\(habit.targetPerDay)"
        }
        return value > 0 ? "Logged" : "Not yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack(alignment: .top, spacing: HiveSpacing.md) {
                HabitGlyph(emoji: habit.emoji, accentColor: habit.color, theme: theme)

                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    Text(habit.name)
                        .font(HiveTypography.title3)
                        .foregroundColor(theme.primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitleText)
                        .font(HiveTypography.caption)
                        .foregroundColor(streakText != nil ? HiveColors.honeyGradientEnd : theme.secondaryTextColor)
                }

                Spacer()

                BeeButton(
                    isComplete: isCompletedToday,
                    accentColor: habit.color,
                    theme: theme,
                    action: onLog
                )
            }

            HoneycombGridView(
                logs: habit.recentLogs ?? [],
                habitColor: habit.color,
                target: habit.targetPerDay,
                type: habit.type,
                theme: theme
            )

            HStack(spacing: HiveSpacing.md) {
                Label {
                    Text(todayCountText)
                } icon: {
                    Image(systemName: "drop.fill")
                        .foregroundColor(habit.color)
                }
                .font(HiveTypography.caption)
                .foregroundColor(theme.secondaryTextColor)

                Spacer()

                if let completionText {
                    Text(completionText)
                        .font(HiveTypography.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.08), radius: 18, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .stroke(theme == .night ? Color.white.opacity(0.08) : HiveColors.borderColor.opacity(0.6), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.large))
        .onTapGesture { onOpen() }
        .onLongPressGesture(minimumDuration: 0.4) {
            onLongPress()
        }
    }
}

// MARK: - Bee Button
struct BeeButton: View {
    let isComplete: Bool
    let accentColor: Color
    let theme: AppTheme
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    isPressed = false
                }
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Group {
                            if isComplete {
                                theme.primaryGradient
                            } else {
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(theme == .night ? 0.5 : 0.25),
                                        accentColor.opacity(theme == .night ? 0.25 : 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                        .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(isComplete ? Color.white.opacity(0.5) : accentColor.opacity(theme == .night ? 0.4 : 0.25), lineWidth: 1.5)
                    )
                    .shadow(color: isComplete ? HiveColors.honeyGradientEnd.opacity(0.35) : Color.black.opacity(theme == .night ? 0.35 : 0.1), radius: 10, x: 0, y: 6)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale)
                } else {
                    Text("🐝")
                        .font(.system(size: 22))
                        .transition(.scale)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .accessibilityLabel(isComplete ? "Habit logged for today" : "Log habit")
    }
}

// MARK: - Honeycomb Grid
struct HoneycombGridView: View {
    private let weeksToShow: Int
    private let grid: [[HoneycombCellData]]
    private let theme: AppTheme
    private let accentColor: Color

    init(
        logs: [HabitLog],
        habitColor: Color,
        target: Int,
        type: HabitType,
        theme: AppTheme,
        weeksToShow: Int = 8
    ) {
        self.weeksToShow = weeksToShow
        self.theme = theme
        self.accentColor = habitColor
        self.grid = HoneycombGridView.makeGrid(
            logs: logs,
            target: target,
            type: type,
            weeksToShow: weeksToShow
        )
    }

    var body: some View {
        let cellSize: CGFloat = 16
        let horizontalSpacing: CGFloat = 6
        let verticalSpacing: CGFloat = 6

        VStack(alignment: .leading, spacing: verticalSpacing) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(0..<weeksToShow, id: \.self) { column in
                        let cell = grid[column][row]
                        HoneycombCellView(
                            cell: cell,
                            accentColor: accentColor,
                            theme: theme
                        )
                        .frame(width: cellSize, height: cellSize)
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : (cellSize + horizontalSpacing) / 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func makeGrid(
        logs: [HabitLog],
        target: Int,
        type: HabitType,
        weeksToShow: Int
    ) -> [[HoneycombCellData]] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let todayWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let endOfThisWeek = calendar.date(from: todayWeekComponents) ?? today
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: endOfThisWeek) else {
            return Array(repeating: Array(repeating: HoneycombCellData(date: today, state: .future, isToday: false), count: 7), count: weeksToShow)
        }

        let lookup = logs.reduce(into: [String: HabitLog]()) { partial, log in
            partial[log.logDate] = log
        }

        return (0..<weeksToShow).map { weekIndex in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startDate) else {
                return Array(repeating: HoneycombCellData(date: today, state: .future, isToday: false), count: 7)
            }

            return (0..<7).compactMap { dayOffset -> HoneycombCellData? in
                guard let cellDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return nil }
                let dayKey = DateFormatter.hiveDayFormatter.string(from: cellDate)
                let log = lookup[dayKey]
                let state: HoneycombCellState

                if cellDate > today {
                    state = .future
                } else if let log {
                    switch type {
                    case .checkbox:
                        state = .full
                    case .counter:
                        if log.value >= target {
                            state = .full
                        } else if log.value > 0 {
                            state = .partial
                        } else {
                            state = .empty
                        }
                    }
                } else {
                    state = .empty
                }

                return HoneycombCellData(
                    date: cellDate,
                    state: state,
                    isToday: calendar.isDate(cellDate, inSameDayAs: today)
                )
            }
        }
    }
}

// MARK: - Honeycomb Cell View
struct HoneycombCellView: View {
    let cell: HoneycombCellData
    let accentColor: Color
    let theme: AppTheme

    private var fillColor: Color {
        switch cell.state {
        case .future:
            return theme == .night ? Color.white.opacity(0.04) : Color.white.opacity(0.6)
        case .empty:
            return theme == .night ? Color.white.opacity(0.08) : HiveColors.lightGray.opacity(0.7)
        case .partial:
            return accentColor.opacity(theme == .night ? 0.55 : 0.45)
        case .full:
            return accentColor.opacity(theme == .night ? 0.95 : 0.9)
        }
    }

    private var borderColor: Color {
        if cell.isToday {
            return HiveColors.honeyGradientEnd
        }
        return accentColor.opacity(theme == .night ? 0.4 : 0.25)
    }

    var body: some View {
        HexagonMiniShape()
            .fill(fillColor)
            .overlay(
                HexagonMiniShape()
                    .stroke(borderColor, lineWidth: cell.isToday ? 1.4 : 0.8)
            )
            .opacity(cell.state == .future ? 0.3 : 1.0)
            .shadow(color: cell.state == .full ? accentColor.opacity(0.25) : .clear, radius: 3, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

// MARK: - Supporting Models
struct HoneycombCellData {
    let date: Date
    let state: HoneycombCellState
    let isToday: Bool
}

enum HoneycombCellState {
    case empty
    case partial
    case full
    case future
}

struct HabitGlyph: View {
    let emoji: String?
    let accentColor: Color
    let theme: AppTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(accentColor.opacity(theme == .night ? 0.35 : 0.18))
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .stroke(accentColor.opacity(theme == .night ? 0.5 : 0.3), lineWidth: 1)
            Text(emoji ?? "🎯")
                .font(.system(size: 32))
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Hexagon Mini Shape
struct HexagonMiniShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2

        var path = Path()

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Date Formatter Helper
extension DateFormatter {
    static let hiveDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - View Model
class HabitsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let apiClient = FastAPIClient.shared
    
    var completedToday: Int {
        habits.filter { habit in
            if let logs = habit.recentLogs {
                let today = DateFormatter.hiveDayFormatter.string(from: Date())
                return logs.contains { $0.logDate == today }
            }
            return false
        }.count
    }
    
    var totalStreak: Int {
        habits.compactMap { $0.currentStreak }.max() ?? 0
    }
    
    func loadHabits() {
        Task { await loadHabitsAsync() }
    }

    @discardableResult
    func optimisticToggle(habit: Habit, value: Int, adding: Bool) -> Bool {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else {
            return false
        }

        var habitCopy = habits[idx]
        var logs = habitCopy.recentLogs ?? []
        let today = DateFormatter.hiveDayFormatter.string(from: Date())

        if let existingIndex = logs.firstIndex(where: { $0.logDate == today }) {
            if adding {
                // Already logged; do nothing
                return false
            }
            logs.remove(at: existingIndex)
            habitCopy.recentLogs = logs
            habits[idx] = habitCopy
            return true
        } else {
            guard adding else { return false }
            let newLog = HabitLog(
                id: UUID().uuidString,
                habitId: habitCopy.id,
                userId: habitCopy.userId,
                logDate: today,
                value: value,
                source: "manual",
                createdAt: Date()
            )
            logs.append(newLog)
            habitCopy.recentLogs = logs
            habits[idx] = habitCopy
            return true
        }
    }

    func todayLog(for habitId: String) -> HabitLog? {
        guard let habit = habits.first(where: { $0.id == habitId }) else { return nil }
        let today = DateFormatter.hiveDayFormatter.string(from: Date())
        return habit.recentLogs?.first(where: { $0.logDate == today })
    }
    
    func refreshHabits() async {
        await loadHabitsAsync()
    }

    func addHabitOptimistically(_ habit: Habit) {
        // Add the habit to the beginning of the list for immediate display
        habits.insert(habit, at: 0)

        // Refresh the habits list to get the latest data from server
        Task {
            await refreshHabits()
        }
    }

    @MainActor
    private func loadHabitsAsync() async {
        isLoading = true

        do {
            let habits = try await apiClient.getHabits(includeLogs: true, days: 30)
            self.habits = habits
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    func logHabit(habitId: String, value: Int) {
        Task {
            do {
                _ = try await apiClient.logHabit(habitId: habitId, value: value)
                await refreshHabits()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteHabitLog(habitId: String, logDateString: String) {
        let logDate = DateFormatter.hiveDayFormatter.date(from: logDateString)
        Task {
            do {
                try await apiClient.deleteHabitLog(habitId: habitId, logDate: logDate)
                await refreshHabits()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
    
    func deleteHabit(habitId: String) {
        Task {
            do {
                try await apiClient.deleteHabit(habitId: habitId)
                await refreshHabits()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
}

#Preview {
    HabitsHomeView()
}
