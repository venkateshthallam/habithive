import SwiftUI
import Combine

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HabitDetailViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedMonth = Date()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
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
            .navigationTitle(habit.name)
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
            viewModel.loadHabitDetails(habitId: habit.id)
        }
        .alert("Delete Habit", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteHabit(habitId: habit.id) {
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
                    .fill(habit.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if habit.type == .counter {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: viewModel.todayProgress)
                            .stroke(habit.color, lineWidth: 6)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: viewModel.todayProgress)
                    }
                    .frame(width: 100, height: 100)
                }
                
                Text(habit.emoji ?? "🎯")
                    .font(.system(size: 50))
            }
            
            // Today's Status
            if habit.type == .counter {
                VStack(spacing: HiveSpacing.xs) {
                    Text("\(viewModel.todayValue) / \(habit.targetPerDay)")
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
                viewModel.logHabit(habitId: habit.id, value: 1)
            }) {
                HStack {
                    Image(systemName: habit.type == .checkbox ? "checkmark" : "plus")
                    Text(habit.type == .checkbox ? "Mark Complete" : "Add +1")
                }
                .font(HiveTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.sm)
                .background(
                    themeManager.currentTheme.primaryGradient
                        .opacity(viewModel.isCompletedToday && habit.type == .checkbox ? 0.5 : 1)
                )
                .cornerRadius(HiveRadius.medium)
            }
            .disabled(viewModel.isCompletedToday && habit.type == .checkbox)
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
                value: "\(habit.currentStreak ?? 0)",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Completion",
                value: "\(Int(habit.completionRate ?? 0))%",
                icon: "chart.pie.fill",
                color: habit.color
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
                viewModel.convertToHive(habitId: habit.id)
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
        VStack(spacing: HiveSpacing.xs) {
            // Week day headers
            HStack(spacing: HiveSpacing.xs) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(HiveTypography.caption2)
                        .foregroundColor(HiveColors.slateText.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HiveSpacing.xs), count: 7), spacing: HiveSpacing.xs) {
                ForEach(getDaysInMonth(), id: \.self) { date in
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
        let dateString = date.formatted(.dateTime.year().month().day())
        return logs.contains { $0.logDate == dateString }
    }
    
    private func getValueForDate(_ date: Date) -> Int {
        let dateString = date.formatted(.dateTime.year().month().day())
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
    @Published var logs: [HabitLog] = []
    @Published var todayValue = 0
    @Published var isCompletedToday = false
    @Published var totalDays = 0
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    var todayProgress: CGFloat {
        // For counter habits
        return CGFloat(todayValue) / 8.0 // Assuming target of 8
    }
    
    func loadHabitDetails(habitId: String) {
        isLoading = true
        
        apiClient.getHabits(includeLogs: true, days: 365)
            .sink(
                receiveCompletion: { _ in
                    self.isLoading = false
                },
                receiveValue: { habits in
                    if let habit = habits.first(where: { $0.id == habitId }) {
                        self.logs = habit.recentLogs ?? []
                        self.calculateStats()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func calculateStats() {
        let today = Date().formatted(.dateTime.year().month().day())
        
        if let todayLog = logs.first(where: { $0.logDate == today }) {
            todayValue = todayLog.value
            isCompletedToday = true
        }
        
        totalDays = logs.count
    }
    
    func logHabit(habitId: String, value: Int) {
        apiClient.logHabit(habitId: habitId, value: value)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    self.loadHabitDetails(habitId: habitId)
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteHabit(habitId: String, completion: @escaping () -> Void) {
        apiClient.deleteHabit(habitId: habitId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { success in
                    if success {
                        completion()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func convertToHive(habitId: String) {
        apiClient.createHiveFromHabit(habitId: habitId, name: nil, backfillDays: 30)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { hive in
                    // Navigate to hive or show success
                    print("Created hive: \(hive.id)")
                }
            )
            .store(in: &cancellables)
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