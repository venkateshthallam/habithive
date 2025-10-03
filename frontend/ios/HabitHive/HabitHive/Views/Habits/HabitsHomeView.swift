import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HabitsHomeView: View {
    @StateObject private var viewModel = HabitsViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showCreateHabit = false
    @State private var selectedHabit: Habit?
    // Inline animation now lives inside BeeButton + Hex cells

    private var backgroundColor: Color {
        themeManager.currentTheme == .night ? themeManager.currentTheme.backgroundColor : HiveColors.creamBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor
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
                                        todayKey: viewModel.currentDayKey,
                                        theme: themeManager.currentTheme,
                                        userTimezone: viewModel.userTimezone,
                                        dayStartHour: viewModel.dayStartHour,
                                        onLog: {
                                            handleBeeButtonTap(habit)
                                        },
                                        onIncrement: {
                                            handleCounterIncrement(habit)
                                        },
                                        onDecrement: {
                                            handleCounterDecrement(habit)
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
        .onReceive(NotificationCenter.default.publisher(for: .habitDeleted)) { notification in
            if let habitId = notification.object as? String {
                viewModel.removeHabitOptimistically(habitId: habitId)
            }
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
            // Remove existing log
            let removed = viewModel.optimisticToggle(habit: habit, value: log.value, adding: false)
            if removed {
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
                viewModel.deleteHabitLog(habitId: habit.id, logDateString: log.logDate)
            }
        } else {
            // Add new log
            let value = habit.type == .counter ? habit.targetPerDay : 1
#if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
#endif
            // Always perform optimistic update and API call
            viewModel.optimisticToggle(habit: habit, value: value, adding: true)
            viewModel.logHabit(habitId: habit.id, value: value)
            // Inline animation handled by BeeButton + HexCellView
        }
    }

    private func handleHabitLongPress(_ habit: Habit) {
        selectedHabit = habit
    }

    private func handleCounterIncrement(_ habit: Habit) {
        guard habit.type == .counter else { return }
        let todayLog = viewModel.todayLog(for: habit.id)
        let currentValue = todayLog?.value ?? 0
        let newValue = min(currentValue + 1, habit.targetPerDay)

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        viewModel.optimisticToggle(habit: habit, value: newValue, adding: true)
        viewModel.logHabit(habitId: habit.id, value: newValue)
    }

    private func handleCounterDecrement(_ habit: Habit) {
        guard habit.type == .counter else { return }
        let todayLog = viewModel.todayLog(for: habit.id)
        let currentValue = todayLog?.value ?? 0

        guard currentValue > 0 else { return }

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        let newValue = currentValue - 1

        if newValue == 0 {
            // Delete the log if value reaches 0
            let removed = viewModel.optimisticToggle(habit: habit, value: newValue, adding: false)
            if removed {
                viewModel.deleteHabitLog(habitId: habit.id, logDateString: todayLog!.logDate)
            }
        } else {
            // Update with new value
            viewModel.optimisticToggle(habit: habit, value: newValue, adding: true)
            viewModel.logHabit(habitId: habit.id, value: newValue)
        }
    }

}

// MARK: - Habit Card View
struct HabitCardView: View {
    let habit: Habit
    let todayKey: String
    let theme: AppTheme
    let userTimezone: TimeZone
    let dayStartHour: Int
    let onLog: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onOpen: () -> Void
    let onLongPress: () -> Void

    private var todaysLog: HabitLog? {
        let log = habit.recentLogs?.first(where: { $0.logDate == todayKey })
        return log
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
                    habitType: habit.type,
                    currentValue: todaysLog?.value ?? 0,
                    targetValue: habit.targetPerDay,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                    action: onLog
                )
            }

            HoneycombGridView(
                logs: habit.recentLogs ?? [],
                habitColor: habit.color,
                target: habit.targetPerDay,
                type: habit.type,
                theme: theme,
                userTimezone: userTimezone,
                dayStartHour: dayStartHour
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
            RoundedRectangle(cornerRadius: HiveRadius.card)
                .fill(theme.cardBackgroundColor)
                .shadow(color: HiveShadow.card.color, radius: HiveShadow.card.radius, x: HiveShadow.card.x, y: HiveShadow.card.y)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.card)
                .stroke(theme == .night ? Color.white.opacity(0.05) : HiveColors.borderColor.opacity(0.4), lineWidth: 0.5)
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
    let habitType: HabitType
    let currentValue: Int
    let targetValue: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onToggle: () -> Void

    @State private var isPressed = false
    @State private var showStepper = false
    @State private var tapEffectTrigger: Int = 0

    init(
        isComplete: Bool,
        accentColor: Color,
        theme: AppTheme,
        habitType: HabitType = .checkbox,
        currentValue: Int = 0,
        targetValue: Int = 1,
        onIncrement: @escaping () -> Void = {},
        onDecrement: @escaping () -> Void = {},
        action: @escaping () -> Void
    ) {
        self.isComplete = isComplete
        self.accentColor = accentColor
        self.theme = theme
        self.habitType = habitType
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onToggle = action
    }

    var body: some View {
        Group {
            if habitType == .counter && showStepper {
                CounterStepperView(
                    currentValue: currentValue,
                    targetValue: targetValue,
                    accentColor: accentColor,
                    theme: theme,
                    onIncrement: {
                        onIncrement()
                    },
                    onDecrement: {
                        onDecrement()
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showStepper = false
                        }
                    }
                )
            } else {
                checkboxButton
            }
        }
    }

    private var checkboxButton: some View {
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

            if habitType == .counter {
                withAnimation(.easeIn(duration: 0.2)) {
                    showStepper = true
                }
            } else {
                onToggle()
                // Fire inline honey tap effect
                tapEffectTrigger += 1
            }
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

                // Inline honey confetti + fill wave
                HoneyTapEffectView(accentColor: accentColor, size: 54, trigger: $tapEffectTrigger)

                if isComplete && habitType == .checkbox {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale)
                } else if habitType == .counter {
                    VStack(spacing: 2) {
                        Text("\(currentValue)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isComplete ? .white : accentColor)
                        Text("/\(targetValue)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isComplete ? .white.opacity(0.8) : accentColor.opacity(0.7))
                    }
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

// MARK: - Counter Stepper View
struct CounterStepperView: View {
    let currentValue: Int
    let targetValue: Int
    let accentColor: Color
    let theme: AppTheme
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Decrement Button
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onDecrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        currentValue > 0 ? accentColor : theme.secondaryTextColor.opacity(0.3)
                    )
            }
            .disabled(currentValue <= 0)
            .buttonStyle(.plain)

            // Value Display
            Text("\(currentValue)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryTextColor)
                .frame(minWidth: 24)

            Text("/")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))

            Text("\(targetValue)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryTextColor)

            // Increment Button
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onIncrement()
            } label: {
                Group {
                    if currentValue < targetValue {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(theme.primaryGradient)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.3))
                    }
                }
            }
            .disabled(currentValue >= targetValue)
            .buttonStyle(.plain)

            // Done Button
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
                onDismiss()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: HiveShadow.card.color, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Honeycomb Grid (Staggered Hive Layout)
struct HoneycombGridView: View {
    private let hexDays: [HexDay]
    private let theme: AppTheme
    private let accentColor: Color
    private let userTimezone: TimeZone
    private let dayStartHour: Int
    private let onTap: ((Date) -> Void)?

    // Hex dimensions (slightly increased from 12 to 14)
    private let hexSide: CGFloat = 14
    private let gap: CGFloat = 2

    private var hexWidth: CGFloat { sqrt(3) * hexSide }
    private var hexHeight: CGFloat { 2 * hexSide }
    private var dx: CGFloat { hexWidth + gap }
    private var dy: CGFloat { 1.5 * hexSide + gap }

    init(
        logs: [HabitLog],
        habitColor: Color,
        target: Int,
        type: HabitType,
        theme: AppTheme,
        userTimezone: TimeZone = .current,
        dayStartHour: Int = 0,
        weeksToShow: Int = 5,
        onTap: ((Date) -> Void)? = nil
    ) {
        self.theme = theme
        self.accentColor = habitColor
        self.userTimezone = userTimezone
        self.dayStartHour = dayStartHour
        self.onTap = onTap
        self.hexDays = HoneycombGridView.makeHexDays(
            logs: logs,
            target: target,
            type: type,
            userTimezone: userTimezone,
            dayStartHour: dayStartHour,
            weeksToShow: weeksToShow
        )
    }

    var body: some View {
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        let gridWidth = 7 * dx + hexWidth / 2  // Total width of 7 columns

        VStack(spacing: 6) {
            // Weekday headers - align each header to its column center in row 0
            GeometryReader { geometry in
                let leadingOffset = (geometry.size.width - gridWidth) / 2

                ZStack(alignment: .topLeading) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { col, day in
                        Text(day)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                            .position(
                                x: leadingOffset + CGFloat(col) * dx + hexWidth / 2,
                                y: 8
                            )
                    }
                }
            }
            .frame(height: 16)

            // Staggered hex grid
            GeometryReader { geometry in
                let leadingOffset = (geometry.size.width - gridWidth) / 2

                ZStack(alignment: .topLeading) {
                    // Streak connectors (drawn first, under hexes)
                    ForEach(hexDays.filter { $0.hasStreakConnection }) { hexDay in
                        StreakConnectorView(
                            hexDay: hexDay,
                            allDays: hexDays,
                            hexWidth: hexWidth,
                            hexHeight: hexHeight,
                            dx: dx,
                            dy: dy,
                            color: accentColor,
                            theme: theme,
                            leadingOffset: leadingOffset
                        )
                    }

                    // Hexagons
                    ForEach(hexDays) { hexDay in
                        HexCellView(
                            hexDay: hexDay,
                            accentColor: accentColor,
                            theme: theme,
                            hexSide: hexSide,
                            onTap: onTap
                        )
                        .position(
                            x: hexPosition(hexDay, leadingOffset: leadingOffset).x,
                            y: hexPosition(hexDay, leadingOffset: leadingOffset).y
                        )
                    }
                }
            }
            .frame(height: calculateGridHeight())
        }
    }

    private func hexPosition(_ hexDay: HexDay, leadingOffset: CGFloat = 0) -> CGPoint {
        let row = hexDay.weekIndex
        let col = hexDay.weekDay

        let rowOffset = (row % 2 == 1) ? hexWidth / 2 : 0
        let x = leadingOffset + CGFloat(col) * dx + rowOffset + hexWidth / 2
        let y = CGFloat(row) * dy + hexHeight / 2 + 4

        return CGPoint(x: x, y: y)
    }

    private func calculateGridHeight() -> CGFloat {
        let maxWeek = hexDays.map { $0.weekIndex }.max() ?? 0
        return CGFloat(maxWeek + 1) * dy + hexHeight + 8
    }

    private static func makeHexDays(
        logs: [HabitLog],
        target: Int,
        type: HabitType,
        userTimezone: TimeZone,
        dayStartHour: Int,
        weeksToShow: Int
    ) -> [HexDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = userTimezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()
        let adjustedNow = calendar.date(byAdding: .hour, value: -dayStartHour, to: now) ?? now
        let today = calendar.startOfDay(for: adjustedNow)

        // Get start of current week
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let weekStart = calendar.date(from: weekComponents) else { return [] }

        // Go back to cover weeksToShow
        guard let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: weekStart) else {
            return []
        }

        let lookup = logs.reduce(into: [String: HabitLog]()) { partial, log in
            partial[log.logDate] = log
        }

        var hexDays: [HexDay] = []

        for weekIndex in 0..<weeksToShow {
            for weekDay in 0..<7 {
                let dayOffset = weekIndex * 7 + weekDay
                guard let cellDate = calendar.date(byAdding: .day, value: dayOffset, to: gridStart) else {
                    continue
                }

                let dayKey = DateFormatter.hiveDayFormatter.string(from: cellDate)
                let log = lookup[dayKey]

                let intensity = calculateIntensity(log: log, target: target, type: type)
                let isFuture = cellDate > today

                hexDays.append(HexDay(
                    id: dayKey,
                    date: cellDate,
                    weekIndex: weekIndex,
                    weekDay: weekDay,
                    intensity: isFuture ? 0 : intensity,
                    isToday: calendar.isDate(cellDate, inSameDayAs: today),
                    isFuture: isFuture,
                    value: log?.value ?? 0,
                    hasLog: log != nil
                ))
            }
        }

        // Calculate streak connections
        return addStreakConnections(hexDays: hexDays, calendar: calendar)
    }

    private static func calculateIntensity(log: HabitLog?, target: Int, type: HabitType) -> Int {
        guard let log else { return 0 }

        switch type {
        case .checkbox:
            return log.value > 0 ? 4 : 0
        case .counter:
            let ratio = Double(log.value) / Double(max(target, 1))
            if ratio >= 1.0 { return 4 }
            if ratio >= 0.75 { return 3 }
            if ratio >= 0.5 { return 2 }
            if ratio > 0 { return 1 }
            return 0
        }
    }

    private static func addStreakConnections(hexDays: [HexDay], calendar: Calendar) -> [HexDay] {
        var updatedDays = hexDays
        let dayMap = Dictionary(uniqueKeysWithValues: hexDays.map { ($0.id, $0) })

        for i in 0..<updatedDays.count {
            guard updatedDays[i].hasLog && !updatedDays[i].isFuture else { continue }

            let currentDate = updatedDays[i].date

            // Check adjacent days for streaks (E, W, NE, NW, SE, SW)
            let neighbors = getHexNeighbors(
                weekIndex: updatedDays[i].weekIndex,
                weekDay: updatedDays[i].weekDay,
                date: currentDate,
                calendar: calendar
            )

            for (direction, neighborDate) in neighbors {
                let neighborKey = DateFormatter.hiveDayFormatter.string(from: neighborDate)
                if let neighbor = dayMap[neighborKey], neighbor.hasLog && !neighbor.isFuture {
                    updatedDays[i].streakDirections.insert(direction)
                }
            }
        }

        return updatedDays
    }

    private static func getHexNeighbors(
        weekIndex: Int,
        weekDay: Int,
        date: Date,
        calendar: Calendar
    ) -> [(HexDirection, Date)] {
        var neighbors: [(HexDirection, Date)] = []

        // East (next day in week)
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
            neighbors.append((.east, nextDay))
        }

        // West (previous day in week)
        if let prevDay = calendar.date(byAdding: .day, value: -1, to: date) {
            neighbors.append((.west, prevDay))
        }

        return neighbors
    }
}

// MARK: - Hex Cell View (with Honey Drop Animation)
struct HexCellView: View {
    let hexDay: HexDay
    let accentColor: Color
    let theme: AppTheme
    let hexSide: CGFloat
    let onTap: ((Date) -> Void)?

    @State private var showHoneyDrop = false
    @State private var fillProgress: CGFloat = 0
    @State private var hasLoggedPreviously: Bool = false

    private var heatColors: [Color] {
        if theme == .night {
            return [
                Color(hex: "#171719"), // 0 - empty
                Color(hex: "#4A3B0C"), // 1
                Color(hex: "#6B4F0D"), // 2
                Color(hex: "#9A6E10"), // 3
                Color(hex: "#C38812"), // 4
                Color(hex: "#F2A91A")  // 5 (full)
            ]
        } else {
            return [
                Color(hex: "#FFFFFF"), // 0 - empty
                Color(hex: "#FFEEC2"), // 1
                Color(hex: "#FFD778"), // 2
                Color(hex: "#FFC34D"), // 3
                Color(hex: "#FFB000"), // 4
                Color(hex: "#E69A00")  // 5 (full)
            ]
        }
    }

    private var fillColor: Color {
        if hexDay.isFuture {
            return theme == .night ? Color(hex: "#171719") : Color(hex: "#FFFFFF")
        }
        return heatColors[min(hexDay.intensity, heatColors.count - 1)]
    }

    private var strokeColor: Color {
        if hexDay.isToday {
            return theme == .night ? Color(hex: "#F2A91A") : Color(hex: "#FFB000")
        }
        return theme == .night ? Color(hex: "#2B2B2E") : Color(hex: "#EDE7D9")
    }

    var body: some View {
        ZStack {
            // Main hexagon
            PointyHexagonShape()
                .fill(fillColor)
                .frame(width: hexSide * 2, height: hexSide * 2)
                .overlay(
                    PointyHexagonShape()
                        .stroke(strokeColor, lineWidth: hexDay.isToday ? 1.5 : 0.8)
                        .frame(width: hexSide * 2, height: hexSide * 2)
                )
                .shadow(
                    color: hexDay.intensity > 2 ? accentColor.opacity(0.2) : Color.clear,
                    radius: 3,
                    x: 0,
                    y: 2
                )
                .opacity(hexDay.isFuture ? 0.3 : 1.0)

            // Animated honey fill for today's cell
            if hexDay.isToday {
                PointyHexagonShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FFD778"), Color(hex: "#FFB000")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: hexSide * 2, height: hexSide * 2)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle().frame(height: (hexSide * 2) * fillProgress)
                        }
                    )
                    .allowsHitTesting(false)
                    .animation(.timingCurve(0.4, 0, 0.2, 1.0, duration: 0.6), value: fillProgress)
            }

            // Honey drop animation overlay
            if showHoneyDrop {
                HoneyDropletView(hexSide: hexSide)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onTapGesture {
            guard !hexDay.isFuture else { return }

            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif

            withAnimation(.easeOut(duration: 0.2)) {
                showHoneyDrop = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                showHoneyDrop = false
                onTap?(hexDay.date)
            }
        }
        .onAppear {
            // Initialize progress based on existing state for today
            hasLoggedPreviously = hexDay.hasLog
            fillProgress = (hexDay.isToday && hexDay.hasLog) ? 1 : 0
        }
        .onChange(of: hexDay.hasLog) { _, newValue in
            guard hexDay.isToday else { return }
            if newValue && !hasLoggedPreviously {
                // animate filling up
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
                withAnimation(.timingCurve(0.4, 0, 0.2, 1.0, duration: 0.6)) {
                    fillProgress = 1
                }
                hasLoggedPreviously = true
            } else if !newValue && hasLoggedPreviously {
                withAnimation(.easeOut(duration: 0.35)) { fillProgress = 0 }
                hasLoggedPreviously = false
            }
        }
    }
}

// MARK: - Honey Droplet Animation
struct HoneyDropletView: View {
    let hexSide: CGFloat
    @State private var offset: CGFloat = -8
    @State private var opacity: Double = 1

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#FFD778"), Color(hex: "#FFB000")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: hexSide * 0.4, height: hexSide * 0.4)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = 6
                }
                withAnimation(.easeIn(duration: 0.12).delay(0.2)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Streak Connector View
struct StreakConnectorView: View {
    let hexDay: HexDay
    let allDays: [HexDay]
    let hexWidth: CGFloat
    let hexHeight: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let color: Color
    let theme: AppTheme
    let leadingOffset: CGFloat

    var body: some View {
        ForEach(Array(hexDay.streakDirections), id: \.self) { direction in
            connectorPath(for: direction)
                .stroke(color.opacity(theme == .night ? 0.6 : 0.5), lineWidth: 1)
        }
    }

    private func connectorPath(for direction: HexDirection) -> Path {
        Path { path in
            let start = hexPosition(hexDay)

            switch direction {
            case .east:
                let end = CGPoint(x: start.x + dx / 2, y: start.y)
                path.move(to: start)
                path.addLine(to: end)
            case .west:
                let end = CGPoint(x: start.x - dx / 2, y: start.y)
                path.move(to: start)
                path.addLine(to: end)
            case .northEast, .northWest, .southEast, .southWest:
                // Not implemented yet
                break
            }
        }
    }

    private func hexPosition(_ hexDay: HexDay) -> CGPoint {
        let row = hexDay.weekIndex
        let col = hexDay.weekDay

        let rowOffset = (row % 2 == 1) ? hexWidth / 2 : 0
        let x = leadingOffset + CGFloat(col) * dx + rowOffset + hexWidth / 2
        let y = CGFloat(row) * dy + hexHeight / 2 + 4

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Supporting Models
struct HexDay: Identifiable {
    let id: String
    let date: Date
    let weekIndex: Int  // 0..5
    let weekDay: Int    // 0..6 (Sun..Sat)
    let intensity: Int  // 0..4
    let isToday: Bool
    let isFuture: Bool
    let value: Int
    let hasLog: Bool
    var streakDirections: Set<HexDirection> = []

    var hasStreakConnection: Bool {
        !streakDirections.isEmpty
    }
}

enum HexDirection: Hashable, CaseIterable {
    case east
    case west
    case northEast
    case northWest
    case southEast
    case southWest
}

// Legacy support
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

// MARK: - Pointy Hexagon Shape (Pointy-Top)
struct PointyHexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let width = rect.width
            let height = rect.height
            let centerX = width / 2
            let centerY = height / 2
            let radius = min(width, height) / 2

            // Pointy-top hexagon vertices
            let angle = CGFloat.pi / 3  // 60 degrees

            path.move(to: CGPoint(
                x: centerX + radius * cos(-CGFloat.pi / 2),
                y: centerY + radius * sin(-CGFloat.pi / 2)
            ))

            for i in 1...6 {
                let x = centerX + radius * cos(-CGFloat.pi / 2 + angle * CGFloat(i))
                let y = centerY + radius * sin(-CGFloat.pi / 2 + angle * CGFloat(i))
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.closeSubpath()
        }
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
        formatter.timeZone = TimeZone.current
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
    private var lastLoadedAt: Date?
    private let freshnessInterval: TimeInterval = 90

    @MainActor
    var completedToday: Int {
        let today = todayKey
        return habits.filter { habit in
            if let logs = habit.recentLogs {
                return logs.contains { $0.logDate == today }
            }
            return false
        }.count
    }

    var totalStreak: Int {
        habits.compactMap { $0.currentStreak }.max() ?? 0
    }

    @MainActor
    var currentDayKey: String { todayKey }

    @MainActor
    var userTimezone: TimeZone {
        guard let user = apiClient.currentUser else { return .current }
        return TimeZone(identifier: user.timezone) ?? .current
    }

    @MainActor
    var dayStartHour: Int {
        return apiClient.currentUser?.dayStartHour ?? 0
    }
    
    func loadHabits() {
        Task { await loadHabitsAsync(force: false) }
    }

    @MainActor
    @discardableResult
    func optimisticToggle(habit: Habit, value: Int, adding: Bool) -> Bool {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else {
            return false
        }

        var habitCopy = habits[idx]
        var logs = habitCopy.recentLogs ?? []
        let today = todayKey
        if let existingIndex = logs.firstIndex(where: { $0.logDate == today }) {
            if adding {
                // Update existing log with new value
                logs[existingIndex] = HabitLog(
                    id: logs[existingIndex].id,
                    habitId: habitCopy.id,
                    userId: habitCopy.userId,
                    logDate: today,
                    value: value,
                    source: "manual",
                    createdAt: logs[existingIndex].createdAt
                )
                habitCopy.recentLogs = logs
                habits[idx] = habitCopy
                return true
            } else {
                // Remove existing log
                logs.remove(at: existingIndex)
                habitCopy.recentLogs = logs
                habits[idx] = habitCopy
                return true
            }
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

    @MainActor
    func todayLog(for habitId: String) -> HabitLog? {
        guard let habit = habits.first(where: { $0.id == habitId }) else { return nil }
        let today = todayKey
        return habit.recentLogs?.first(where: { $0.logDate == today })
    }
    
    func refreshHabits() async {
        await loadHabitsAsync(force: true)
    }

    func addHabitOptimistically(_ habit: Habit) {
        // Add the habit to the beginning of the list for immediate display
        habits.insert(habit, at: 0)

        // Refresh the habits list to get the latest data from server
        Task {
            await loadHabitsAsync(force: true)
        }
    }

    @MainActor
    func removeHabitOptimistically(habitId: String) {
        // Optimistically remove the habit from the list
        habits.removeAll { $0.id == habitId }

        // Refresh to ensure consistency with server
        Task {
            await loadHabitsAsync(force: true)
        }
    }

    @MainActor
    private func loadHabitsAsync(force: Bool) async {
        if !force,
           let lastLoadedAt,
           Date().timeIntervalSince(lastLoadedAt) < freshnessInterval,
           !habits.isEmpty {
            return
        }

        isLoading = true

        do {
            let habits = try await apiClient.getHabits(includeLogs: true, days: 30)
            self.habits = habits
            lastLoadedAt = Date()
            errorMessage = ""
        } catch {
            self.errorMessage = error.localizedDescription
            lastLoadedAt = nil
        }

        isLoading = false
    }

    @MainActor
    private var todayKey: String {
        guard let user = apiClient.currentUser else {
            return DateFormatter.hiveDayFormatter.string(from: Date())
        }

        let timezone = TimeZone(identifier: user.timezone) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        let adjusted = calendar.date(byAdding: .hour, value: -user.dayStartHour, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: adjusted)
    }
    
    func logHabit(habitId: String, value: Int) {
        Task {
            do {
                let result = try await apiClient.logHabit(habitId: habitId, value: value)
                // Update only the specific habit with server response
                await MainActor.run {
                    if let idx = habits.firstIndex(where: { $0.id == habitId }) {
                        var habitCopy = habits[idx]
                        var logs = habitCopy.recentLogs ?? []
                        let today = todayKey

                        // Update or add the log with server data
                        if let existingIndex = logs.firstIndex(where: { $0.logDate == today }) {
                            logs[existingIndex] = HabitLog(
                                id: result.id,
                                habitId: habitId,
                                userId: habitCopy.userId,
                                logDate: result.logDate,
                                value: result.value,
                                source: result.source ?? "manual",
                                createdAt: result.createdAt
                            )
                        } else {
                            logs.append(HabitLog(
                                id: result.id,
                                habitId: habitId,
                                userId: habitCopy.userId,
                                logDate: result.logDate,
                                value: result.value,
                                source: result.source ?? "manual",
                                createdAt: result.createdAt
                            ))
                        }
                        habitCopy.recentLogs = logs
                        habits[idx] = habitCopy
                    }
                }

                // Silent background refresh to sync any streak/completion changes
                await silentRefresh()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    // Revert optimistic update on error
                    Task { await refreshHabits() }
                }
            }
        }
    }

    func deleteHabitLog(habitId: String, logDateString: String) {
        let logDate = DateFormatter.hiveDayFormatter.date(from: logDateString)
        Task {
            do {
                try await apiClient.deleteHabitLog(habitId: habitId, logDate: logDate)

                // Silent background refresh to sync any streak/completion changes
                await silentRefresh()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    // Revert optimistic update on error
                    Task { await refreshHabits() }
                }
            }
        }
    }

    private func silentRefresh() async {
        do {
            let freshHabits = try await apiClient.getHabits(includeLogs: true, days: 30)
            await MainActor.run {
                // Update habits while preserving UI state (no loading indicator)
                self.habits = freshHabits
                lastLoadedAt = Date()
            }
        } catch {
            // Silent fail - optimistic update already shown
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
