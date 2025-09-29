import SwiftUI

struct MainTabView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HabitsHomeView()
                .tabItem {
                    Label("Habits", systemImage: "hexagon.fill")
                }
                .tag(0)
            
            HivesView()
                .tabItem {
                    Label("Hive", systemImage: "person.2.fill")
                }
                .tag(1)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .accentColor(HiveColors.honeyGradientEnd)
        .tint(HiveColors.honeyGradientEnd)
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - Hives View
struct HivesView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = HivesViewModel()
    @State private var showCreateHive = false
    @State private var showJoinHive = false
    @State private var joinCode = ""

    private var backgroundColor: Color {
        themeManager.currentTheme == .night ? themeManager.currentTheme.backgroundColor : HiveColors.creamBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: HiveSpacing.xl) {
                        headerSection

                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.hives.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: HiveSpacing.lg) {
                                ForEach(viewModel.hives) { hive in
                                    NavigationLink(destination: HiveDetailView(hiveId: hive.id)) {
                                        HiveCard(hive: hive, theme: themeManager.currentTheme)
                                    }
                                }
                            }
                        }

                        LeadersSection(entries: viewModel.leaderboard, theme: themeManager.currentTheme)
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.top, HiveSpacing.lg)
                    .padding(.bottom, HiveSpacing.xxl)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refreshHives()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadHives()
            }
            .alert("Join Hive", isPresented: $showJoinHive) {
                TextField("Enter invite code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                Button("Join") {
                    viewModel.joinHive(code: joinCode)
                    joinCode = ""
                }
                Button("Cancel", role: .cancel) {
                    joinCode = ""
                }
            } message: {
                Text("Enter the invite code to join a hive")
            }
            .sheet(isPresented: $showCreateHive) {
                CreateHiveFromHabitView { _ in
                    viewModel.loadHives()
                }
            }
        }
    }

    private var summaryCard: some View {
        SummaryCard(
            overallCompletion: viewModel.overallCompletion,
            completedToday: viewModel.completedToday,
            theme: themeManager.currentTheme
        )
    }

    private var weeklyProgressCard: some View {
        WeeklyProgressCard(
            weeklyProgress: viewModel.weeklyProgress,
            theme: themeManager.currentTheme
        )
    }

    private var streaksCard: some View {
        StreaksCard(
            currentStreaks: viewModel.currentStreaks,
            theme: themeManager.currentTheme
        )
    }

    private var yearOverviewCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Year Overview")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.beeBlack)

            YearHeatmapView(data: viewModel.yearComb, theme: themeManager.currentTheme)
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
    }

    private var bestHabitCard: some View {
        Group {
            if let best = viewModel.bestPerformer {
                VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                    Text("Best Performing")
                        .font(HiveTypography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(HiveColors.beeBlack)

                    HStack(spacing: HiveSpacing.md) {
                        Text(best.emoji ?? "🏆")
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                            Text(best.name)
                                .font(HiveTypography.body)
                                .foregroundColor(HiveColors.beeBlack)

                            Text(String(format: "%.0f%% completion", best.completionRate))
                                .font(HiveTypography.caption)
                                .foregroundColor(HiveColors.beeBlack.opacity(0.6))
                        }

                        Spacer()
                    }
                }
                .padding(HiveSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
                )
            }
        }
    }
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Your Hives")
                .font(HiveTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(themeManager.currentTheme == .night ? .white : HiveColors.beeBlack)

            Text("Create a hive or join friends to keep the shared streak alive.")
                .font(HiveTypography.body)
                .foregroundColor((themeManager.currentTheme == .night ? Color.white : HiveColors.beeBlack).opacity(0.7))

            HStack(spacing: HiveSpacing.sm) {
                Button {
                    showCreateHive = true
                } label: {
                    Text("Create Hive")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.modal)
                                .fill(themeManager.currentTheme.primaryGradient)
                        )
                        .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                Button {
                    showJoinHive = true
                } label: {
                    Text("Join with Code")
                        .font(HiveTypography.headline)
                        .foregroundColor(themeManager.currentTheme == .night ? .white : HiveColors.beeBlack)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.modal)
                                .stroke(themeManager.currentTheme == .night ? Color.white.opacity(0.5) : HiveColors.borderColor, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: HiveSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Loading hives...")
                .font(HiveTypography.body)
                .foregroundColor((themeManager.currentTheme == .night ? Color.white : HiveColors.beeBlack).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(HiveSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.35 : 0.05), radius: 12, x: 0, y: 6)
        )
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.md) {
            Text("🐝")
                .font(.system(size: 56))
            Text("No hives yet")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme == .night ? .white : HiveColors.beeBlack)
            Text("Create one from a habit or join a friend's hive to start a shared streak.")
                .font(HiveTypography.body)
                .multilineTextAlignment(.center)
                .foregroundColor((themeManager.currentTheme == .night ? Color.white : HiveColors.beeBlack).opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(HiveSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .stroke(HiveColors.borderColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.3 : 0.05), radius: 10, x: 0, y: 6)
        )
    }
}

// MARK: - Hive Card
struct HiveCard: View {
    let hive: Hive
    let theme: AppTheme

    private var titleColor: Color {
        theme == .night ? .white : HiveColors.beeBlack
    }

    private var subtitleColor: Color {
        titleColor.opacity(0.65)
    }

    private var isActiveToday: Bool {
        guard let last = hive.lastAdvancedOn,
              let date = DateFormatter.hiveDayFormatter.date(from: last) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var cadenceText: String {
        if hive.scheduleDaily {
            return "Daily • \(hive.targetPerDay) \(hive.type == .counter ? "per day" : "check-in")"
        }
        return "Custom cadence • \(hive.targetPerDay) target"
    }

    private var targetStatValue: String {
        switch hive.type {
        case .checkbox:
            return "1 / day"
        case .counter:
            return "\(hive.targetPerDay) / day"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack(alignment: .top, spacing: HiveSpacing.sm) {
                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    HStack(spacing: HiveSpacing.xs) {
                        Text(hive.name)
                            .font(HiveTypography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(titleColor)

                        if isActiveToday {
                            ActiveBadge(theme: theme)
                        }
                    }

                    Text(cadenceText)
                        .font(HiveTypography.caption)
                        .foregroundColor(subtitleColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(subtitleColor)
            }

            HiveAvatarStack(memberCount: hive.memberCount ?? 0, accentColor: hive.color, theme: theme)

            HStack(spacing: HiveSpacing.sm) {
            let maxMembers = hive.maxMembers ?? 10
            HiveCardStat(title: "Shared Streak", value: "\(hive.groupStreak) days", theme: theme)
            HiveCardStat(title: "Members", value: "\(hive.memberCount ?? 0)/\(maxMembers)", theme: theme)
            HiveCardStat(title: "Target", value: targetStatValue, theme: theme)
        }
        }
        .padding(HiveSpacing.lg)
        .background(backgroundView)
    }

    private var backgroundView: some View {
        let base = RoundedRectangle(cornerRadius: HiveRadius.large)
            .fill(theme == .night ? Color.white.opacity(0.06) : Color.white)

        let sheen = RoundedRectangle(cornerRadius: HiveRadius.large)
            .fill(
                LinearGradient(
                    colors: [hive.color.opacity(0.15), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        let stroke = RoundedRectangle(cornerRadius: HiveRadius.large)
            .stroke(hive.color.opacity(theme == .night ? 0.18 : 0.22), lineWidth: 1)

        let shadowColor = Color.black.opacity(theme == .night ? 0.35 : 0.06)

        return base
            .overlay(sheen)
            .overlay(stroke)
            .shadow(color: shadowColor, radius: 14, x: 0, y: 10)
    }
}

struct HiveAvatarStack: View {
    let memberCount: Int
    let accentColor: Color
    let theme: AppTheme

    var body: some View {
        HStack(spacing: -12) {
            if memberCount == 0 {
                Circle()
                    .fill(accentColor.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .overlay(Text("🐝"))
                    .overlay(Circle().stroke(theme == .night ? Color.black.opacity(0.3) : Color.white, lineWidth: 2))
            } else {
                ForEach(0..<min(memberCount, 4), id: \.self) { index in
                    Circle()
                        .fill(accentColor.opacity(0.25 + (Double(index) * 0.12)))
                        .frame(width: 36, height: 36)
                        .overlay(Text("🐝"))
                        .overlay(Circle().stroke(theme == .night ? Color.black.opacity(0.3) : Color.white, lineWidth: 2))
                        .zIndex(Double(4 - index))
                }
            }

            if memberCount > 4 {
                Text("+\(memberCount - 4)")
                    .font(HiveTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme == .night ? .white : HiveColors.beeBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(theme == .night ? 0.35 : 0.2))
                    )
            }
        }
    }
}

struct HiveCardStat: View {
    let title: String
    let value: String
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(HiveTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor((theme == .night ? Color.white : HiveColors.beeBlack).opacity(0.55))

            Text(value)
                .font(HiveTypography.headline)
                .foregroundColor(theme == .night ? .white : HiveColors.beeBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(theme == .night ? Color.white.opacity(0.08) : HiveColors.lightGray)
        )
    }
}

struct ActiveBadge: View {
    let theme: AppTheme

    var body: some View {
        Text("Active")
            .font(HiveTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

struct LeadersSection: View {
    let entries: [HiveLeaderboardEntry]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack {
                Text("Today's Leaders")
                    .font(HiveTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme == .night ? .white : HiveColors.beeBlack)

                Spacer()

                if !entries.isEmpty {
                    Text("Top \(min(entries.count, 5))")
                        .font(HiveTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor((theme == .night ? Color.white : HiveColors.beeBlack).opacity(0.6))
                }
            }

            if entries.isEmpty {
                Text("No completions yet — be the first to pour honey today!")
                    .font(HiveTypography.body)
                    .foregroundColor((theme == .night ? Color.white : HiveColors.beeBlack).opacity(0.6))
                    .padding(.vertical, HiveSpacing.md)
            } else {
                VStack(spacing: HiveSpacing.sm) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderRow(entry: entry, rank: index + 1, theme: theme)
                    }
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme == .night ? Color.white.opacity(0.06) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .stroke(HiveColors.borderColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(theme == .night ? 0.3 : 0.05), radius: 12, x: 0, y: 8)
        )
    }
}

struct LeaderRow: View {
    let entry: HiveLeaderboardEntry
    let rank: Int
    let theme: AppTheme

    private var medal: String? {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    private var primaryColor: Color {
        theme == .night ? .white : HiveColors.beeBlack
    }

    var body: some View {
        HStack(spacing: HiveSpacing.md) {
            if let medal {
                Text(medal)
                    .font(.system(size: 24))
            } else {
                Text("🐝")
                    .font(.system(size: 20))
            }

            Circle()
                .fill(entry.avatarColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(entry.initials)
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(HiveTypography.headline)
                    .foregroundColor(primaryColor)

                Text("\(entry.completionPercentage)% today")
                    .font(HiveTypography.caption)
                    .foregroundColor(primaryColor.opacity(0.6))
            }

            Spacer()

            Text("+\(entry.completedToday) 🍯")
                .font(HiveTypography.headline)
                .foregroundColor(primaryColor)
        }
        .padding(.vertical, HiveSpacing.xs)
    }
}

// MARK: - Hives View Model
class HivesViewModel: ObservableObject {
    @Published var hives: [Hive] = []
    @Published var leaderboard: [HiveLeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var overallCompletion: Double = 0
    @Published var completedToday: Int = 0
    @Published var weeklyProgress: [Int] = Array(repeating: 0, count: 7)
    @Published var currentStreaks: [HabitStreakDisplay] = []
    @Published var yearComb: [String: Int] = [:]
    @Published var bestPerformer: HabitPerformanceSummary?

    private let apiClient = FastAPIClient.shared
    private var lastLoadedAt: Date?
    private let freshnessInterval: TimeInterval = 120

    func loadHives() {
        Task { await loadHivesAsync(force: false) }
    }

    func joinHive(code: String) {
        Task {
            do {
                try await apiClient.joinHive(code: code)
                await loadHivesAsync(force: true)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func refreshHives() async {
        await loadHivesAsync(force: true)
    }

    @MainActor
    private func loadHivesAsync(force: Bool) async {
        if !force,
           let lastLoadedAt,
           Date().timeIntervalSince(lastLoadedAt) < freshnessInterval,
           !hives.isEmpty {
            return
        }

        isLoading = true

        do {
            let overview = try await apiClient.getHives()
            self.hives = overview.hives
            self.leaderboard = overview.leaderboard
            lastLoadedAt = Date()
            errorMessage = ""

            if let summary = try? await apiClient.getInsightsSummary() {
                applyInsights(summary)
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.hives = []
            self.leaderboard = []
            lastLoadedAt = nil
        }

        isLoading = false
    }

    @MainActor
    private func applyInsights(_ summary: InsightsSummary) {
        overallCompletion = summary.overallCompletion
        completedToday = summary.completedToday
        weeklyProgress = summary.weeklyProgress
        currentStreaks = summary.currentStreaks
        yearComb = summary.yearComb
        bestPerformer = summary.bestPerforming
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()

                insightsContent
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadInsights()
        }
    }

    @ViewBuilder
    private var insightsContent: some View {
        if viewModel.isLoading {
            VStack(spacing: HiveSpacing.lg) {
                ProgressView()
                Text("Loading insights…")
                    .font(HiveTypography.body)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            }
        } else if let _ = viewModel.dashboard {
            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                    rangePicker
                    statsCards
                    yearOverviewCard
                    habitPerformanceCard
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
                .padding(.top, HiveSpacing.lg)
            }
            .refreshable {
                await viewModel.refreshInsights()
            }
        } else if !viewModel.errorMessage.isEmpty {
            VStack(spacing: HiveSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(HiveColors.error)
                Text(viewModel.errorMessage)
                    .font(HiveTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                Button("Retry") {
                    viewModel.loadInsights()
                }
                .buttonStyle(.borderedProminent)
                .tint(HiveColors.honeyGradientEnd)
            }
            .padding()
        } else {
            Text("No insights yet – start logging habits to see your progress.")
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $viewModel.selectedRange) {
            ForEach(InsightRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statsCards: some View {
        let average = viewModel.currentStats?.averageCompletion ?? 0
        let streak = viewModel.currentStats?.currentStreak ?? 0
        let averageText = String(format: "%.0f%%", average)

        return HStack(spacing: HiveSpacing.lg) {
            InsightStatCard(
                title: "\(viewModel.selectedRange.displayName) Average",
                value: averageText,
                subtitle: "Completion",
                gradient: LinearGradient(
                    colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            InsightStatCard(
                title: "Current Streak",
                value: "\(streak)",
                subtitle: "Best habit",
                gradient: LinearGradient(
                    colors: [Color(hex: "#FF6F61"), Color(hex: "#FF9472")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var yearOverviewCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack {
                Text("Year Overview")
                    .font(HiveTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                Spacer()
                Label("All Habits", systemImage: "chevron.down")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            }

            YearHeatmapView(data: viewModel.yearOverview, theme: themeManager.currentTheme)
        }
        .padding(HiveSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.4 : 0.08), radius: 12, x: 0, y: 8)
        )
    }

    private var habitPerformanceCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Habit Performance")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)

            VStack(spacing: HiveSpacing.sm) {
                if let performance = viewModel.currentStats?.habitPerformance, !performance.isEmpty {
                    ForEach(performance) { item in
                        HabitPerformanceRow(item: item, theme: themeManager.currentTheme)
                            .padding(.vertical, HiveSpacing.xs)
                            .padding(.horizontal, HiveSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.medium)
                                    .fill(themeManager.currentTheme == .night ? Color.white.opacity(0.08) : Color.white)
                            )
                    }
                } else {
                    Text("No data yet for this range.")
                        .font(HiveTypography.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HiveSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                .fill(themeManager.currentTheme == .night ? Color.white.opacity(0.08) : Color.white)
                        )
                }
            }
        }
        .padding(HiveSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.4 : 0.08), radius: 12, x: 0, y: 8)
        )
    }
}

private struct InsightStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text(title)
                .font(HiveTypography.caption)
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(HiveTypography.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(HiveSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            gradient
                .cornerRadius(HiveRadius.large)
        )
        .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 10, x: 0, y: 6)
    }
}

private struct HabitPerformanceRow: View {
    let item: HabitPerformanceDetailModel
    let theme: AppTheme

    var body: some View {
        HStack(spacing: HiveSpacing.md) {
            Text(item.emoji ?? "🐝")
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(item.color.opacity(theme == .night ? 0.3 : 0.18))
                )

            VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                Text(item.name)
                    .font(HiveTypography.headline)
                    .foregroundColor(theme.primaryTextColor)

                Text("Target \(item.targetPerDay) · \(item.type == .counter ? "Counter" : "Checkbox")")
                    .font(HiveTypography.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", item.completionRate))
                    .font(HiveTypography.headline)
                    .foregroundColor(item.color)

                Text("\(item.streak) streak")
                    .font(HiveTypography.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
    }
}


class InsightsViewModel: ObservableObject {
    @Published var dashboard: InsightsDashboard?
    @Published var selectedRange: InsightRange = .week
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let apiClient = FastAPIClient.shared
    private var lastLoadedAt: Date?
    private let freshnessInterval: TimeInterval = 120

    func loadInsights() {
        Task { await loadInsightsAsync(force: false) }
    }

    func refreshInsights() async {
        await loadInsightsAsync(force: true)
    }

    @MainActor
    private func loadInsightsAsync(force: Bool) async {
        if !force,
           let lastLoadedAt,
           Date().timeIntervalSince(lastLoadedAt) < freshnessInterval,
           dashboard != nil {
            return
        }

        isLoading = true

        do {
            let dashboard = try await apiClient.getInsightsDashboard()
            self.dashboard = dashboard
            lastLoadedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var currentStats: InsightsRangeStatsModel? {
        guard let dashboard else { return nil }
        return dashboard.stats(for: selectedRange)
    }

    var yearOverview: [String: Int] {
        dashboard?.yearOverview ?? [:]
    }
}

struct CreateHiveFromHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateHiveViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedHabitId: String?
    @State private var hiveName = ""
    @State private var isCreating = false
    @State private var errorMessage = ""

    let onComplete: (Hive) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                    VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                        Text("Choose a habit")
                            .font(HiveTypography.title3)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                        Text("We'll copy its schedule, target, and history so your hive can start with momentum.")
                            .font(HiveTypography.body)
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading habits...")
                                .font(HiveTypography.body)
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(themeManager.currentTheme.cardBackgroundColor)
                                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: HiveSpacing.sm) {
                                ForEach(viewModel.habits) { habit in
                                    HabitSelectionRow(
                                        habit: habit,
                                        isSelected: selectedHabitId == habit.id,
                                        theme: themeManager.currentTheme
                                    ) {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            selectedHabitId = habit.id
                                        }
                                        if hiveName.isEmpty {
                                            hiveName = "\(habit.name) Hive"
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, HiveSpacing.xs)
                        }
                    }

                    VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                        Text("Hive name")
                            .font(HiveTypography.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                        TextField("Hydration Heroes", text: $hiveName)
                            .font(HiveTypography.body)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            .padding(HiveSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.medium)
                                    .fill(themeManager.currentTheme.cardBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                                            .stroke(HiveColors.borderColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.4 : 0.05), radius: 10, x: 0, y: 4)
                            )
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(HiveTypography.caption)
                            .foregroundColor(HiveColors.error)
                    }

                    Button(action: createHive) {
                        HStack(spacing: HiveSpacing.sm) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Create Hive")
                                    .font(HiveTypography.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(themeManager.currentTheme.primaryGradient)
                                .opacity(canCreate ? 1 : 0.5)
                                .shadow(color: HiveColors.honeyGradientEnd.opacity(0.3), radius: 18, x: 0, y: 10)
                        )
                    }
                    .disabled(!canCreate || isCreating)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.top, HiveSpacing.lg)
            }
            .navigationBarTitle("Create Hive", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadHabits()
            }
        }
    }

    private var canCreate: Bool {
        !hiveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedHabitId != nil
    }

    private func createHive() {
        guard let habitId = selectedHabitId else { return }

        isCreating = true
        errorMessage = ""
        viewModel.createHive(from: habitId, name: hiveName.trimmingCharacters(in: .whitespacesAndNewlines)) { result in
            isCreating = false
            switch result {
            case .success(let hive):
                onComplete(hive)
                dismiss()
            case .failure(let error):
                errorMessage = error.errorDescription ?? "Unable to create hive"
            }
        }
    }
}
struct ProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var apiClient = FastAPIClient.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSettings = false
    @State private var isEditingName = false
    @State private var newDisplayName = ""
    
var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: HiveSpacing.xl) {
                        // Profile header with enhanced styling
                        VStack(spacing: HiveSpacing.lg) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.currentTheme.cardBackgroundColor)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.45 : 0.08), radius: 10, x: 0, y: 5)

                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text("🐝")
                                            .font(.system(size: 50))
                                    )
                            }

                            VStack(spacing: HiveSpacing.sm) {
                                if isEditingName {
                                    TextField("Display Name", text: $newDisplayName)
                                        .font(HiveTypography.title2)
                                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                                        .multilineTextAlignment(.center)
                                        .padding(HiveSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                .fill(themeManager.currentTheme.cardBackgroundColor.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                        .stroke(themeManager.currentTheme.secondaryTextColor.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .frame(maxWidth: 200)
                                        .onSubmit {
                                            viewModel.updateDisplayName(newDisplayName)
                                            isEditingName = false
                                        }
                                } else {
                                    Text(viewModel.displayName)
                                        .font(HiveTypography.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                                        .onTapGesture {
                                            newDisplayName = viewModel.displayName
                                            isEditingName = true
                                        }
                                }

                                Text(viewModel.phone.isEmpty ? "Add your phone to find friends" : viewModel.phone)
                                    .font(HiveTypography.body)
                                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                            }
                        }
                        .padding(HiveSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                .fill(themeManager.currentTheme.cardBackgroundColor)
                                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.45 : 0.08), radius: 12, x: 0, y: 6)
                        )
                        .padding(.horizontal, HiveSpacing.lg)
                        .padding(.top, HiveSpacing.xl)

                        // Settings card with enhanced styling
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                value: viewModel.notificationsEnabled ? "On" : "Off",
                                action: {
                                    viewModel.toggleNotifications()
                                },
                                theme: themeManager.currentTheme
                            )

                            Divider()
                                .background(themeManager.currentTheme.secondaryTextColor.opacity(0.15))

                            SettingsRow(
                                icon: "moon",
                                title: "Theme",
                                value: themeManager.currentTheme.rawValue.capitalized,
                                action: {
                                    viewModel.showThemeSelector = true
                                },
                                theme: themeManager.currentTheme
                            )

                            Divider()
                                .background(themeManager.currentTheme.secondaryTextColor.opacity(0.15))

                            SettingsRow(
                                icon: "clock",
                                title: "Day Start Time",
                                value: viewModel.dayStartTime,
                                action: {
                                    viewModel.showTimeSelector = true
                                },
                                theme: themeManager.currentTheme
                            )

                            Divider()
                                .background(themeManager.currentTheme.secondaryTextColor.opacity(0.15))

                            SettingsRow(
                                icon: "arrow.right.square",
                                title: "Sign Out",
                                isDestructive: true,
                                action: {
                                    apiClient.logout()
                                },
                                theme: themeManager.currentTheme
                            )

                            Divider()
                                .background(themeManager.currentTheme.secondaryTextColor.opacity(0.15))

                            SettingsRow(
                                icon: "trash",
                                title: "Delete Account",
                                isDestructive: true,
                                action: {
                                    viewModel.requestDeleteAccount()
                                },
                                theme: themeManager.currentTheme
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                .fill(themeManager.currentTheme.cardBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                        .stroke(themeManager.currentTheme.secondaryTextColor.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.45 : 0.08), radius: 10, x: 0, y: 6)
                        )
                        .padding(.horizontal, HiveSpacing.lg)

                        Spacer(minLength: 100)
                    }
                }
            }
            .overlay {
                if viewModel.isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()

                        ProgressView("Deleting account…")
                            .progressViewStyle(.circular)
                            .tint(HiveColors.honeyGradientEnd)
                            .padding(.horizontal, HiveSpacing.xl)
                            .padding(.vertical, HiveSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.large)
                                    .fill(themeManager.currentTheme.cardBackgroundColor)
                                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                            )
                    }
                }
            }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .onAppear {
                viewModel.loadProfile()
            }
            .actionSheet(isPresented: $viewModel.showThemeSelector) {
                ActionSheet(
                    title: Text("Choose Theme"),
                    buttons: [
                        .default(Text("Honey")) {
                            themeManager.setTheme(.honey)
                        },
                        .default(Text("Mint")) {
                            themeManager.setTheme(.mint)
                        },
                        .default(Text("Night")) {
                            themeManager.setTheme(.night)
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $viewModel.showTimeSelector) {
                NavigationStack {
                    VStack(spacing: HiveSpacing.lg) {
                        Text("When does your day start?")
                            .font(HiveTypography.title2)
                            .foregroundColor(HiveColors.slateText)
                            .padding(.top)

                        DatePicker(
                            "Day Start Time",
                            selection: $viewModel.selectedStartTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)

                        Button("Save") {
                            viewModel.saveDayStartTime()
                        }
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.md)
                        .background(themeManager.currentTheme.primaryGradient)
                        .cornerRadius(HiveRadius.large)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Day Start Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                viewModel.showTimeSelector = false
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete Account?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    viewModel.confirmDeleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove your habits, hives, and profile data. This action cannot be undone.")
            }
            .alert(
                "Couldn't Delete Account",
                isPresented: Binding(
                    get: { viewModel.deleteError != nil },
                    set: { newValue in
                        if !newValue {
                            viewModel.deleteError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteError ?? "Please try again later.")
            }
        }
    }

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void
    let theme: AppTheme

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : theme.primaryTextColor)
                    .frame(width: 30)

                Text(title)
                    .font(HiveTypography.body)
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : theme.primaryTextColor)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(HiveTypography.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .padding(.vertical, HiveSpacing.md)
            .padding(.horizontal, HiveSpacing.lg)
        }
    }
}


class ProfileViewModel: ObservableObject {
    @Published var displayName = "Bee"
    @Published var phone = ""
    @Published var isLoading = false
    @Published var notificationsEnabled = true
    @Published var dayStartHour = 4
    @Published var showThemeSelector = false
    @Published var showTimeSelector = false
    @Published var selectedStartTime = Date()
    @Published var showDeleteConfirmation = false
    @Published var deleteError: String?
    @Published var isDeletingAccount = false

    private let apiClient = FastAPIClient.shared

    var dayStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        let dateWithHour = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: dateWithHour)
    }

    func loadProfile() {
        Task { await loadProfileAsync() }
    }

    func updateDisplayName(_ name: String) {
        let update = ProfileUpdate(displayName: name)
        Task {
            do {
                let updated = try await apiClient.updateProfile(update)
                await MainActor.run { self.displayName = updated.displayName }
            } catch {
                print("Failed to update profile: \(error)")
            }
        }
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
    }

    func saveDayStartTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedStartTime)
        dayStartHour = hour

        let update = ProfileUpdate(dayStartHour: hour)
        Task {
            do {
                _ = try await apiClient.updateProfile(update)
            } catch {
                print("Failed to update day start time: \(error)")
            }
        }

        showTimeSelector = false
    }

    func requestDeleteAccount() {
        guard !isDeletingAccount else { return }
        showDeleteConfirmation = true
    }

    func confirmDeleteAccount() {
        guard !isDeletingAccount else { return }
        Task {
            await deleteAccountAsync()
        }
    }

    @MainActor
    private func deleteAccountAsync() async {
        isDeletingAccount = true
        deleteError = nil
        showDeleteConfirmation = false
        defer { isDeletingAccount = false }

        do {
            try await apiClient.deleteAccount()
        } catch {
            if let localized = (error as? LocalizedError)?.errorDescription {
                deleteError = localized
            } else {
                deleteError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadProfileAsync() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await apiClient.getMyProfile()
            displayName = user.displayName
            phone = user.phone
            dayStartHour = user.dayStartHour

            let calendar = Calendar.current
            selectedStartTime = calendar.date(bySettingHour: self.dayStartHour, minute: 0, second: 0, of: Date()) ?? Date()
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}

class CreateHiveViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false

    private let apiClient = FastAPIClient.shared

    func loadHabits() {
        Task {
            await loadHabitsAsync()
        }
    }

    func createHive(from habitId: String, name: String, completion: @escaping (Result<Hive, APIError>) -> Void) {
        Task {
            do {
                let hive = try await apiClient.createHiveFromHabit(habitId: habitId, name: name, backfillDays: 30)
                completion(.success(hive))
            } catch let error as APIError {
                completion(.failure(error))
            } catch {
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }

    @MainActor
    private func loadHabitsAsync() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let habits = try await apiClient.getHabits(includeLogs: false, days: 1)
            self.habits = habits.filter { $0.isActive }
        } catch {
            self.habits = []
        }
    }
}

#Preview {
    MainTabView()
}

// MARK: - Year Heatmap View
struct YearHeatmapView: View {
    let data: [String: Int]
    let theme: AppTheme

    var body: some View {
        Text("Comb view coming soon")
            .font(HiveTypography.body)
            .foregroundColor(theme.secondaryTextColor)
    }
}

// MARK: - Habit Selection Row
struct HabitSelectionRow: View {
    let habit: Habit
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HiveSpacing.md) {
                Text(habit.emoji ?? "🐝")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    Text(habit.name)
                        .font(HiveTypography.body)
                        .foregroundColor(theme.primaryTextColor)
                        .multilineTextAlignment(.leading)

                    Text("\(habit.targetPerDay) per day")
                        .font(HiveTypography.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(HiveColors.honeyGradientEnd)
                } else {
                    Circle()
                        .stroke(HiveColors.borderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(HiveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.large)
                    .fill(isSelected ? HiveColors.honeyGradientEnd.opacity(0.1) : theme.cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .stroke(isSelected ? HiveColors.honeyGradientEnd : HiveColors.borderColor.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(theme == .night ? 0.4 : 0.05), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Card Components
struct SummaryCard: View {
    let overallCompletion: Double
    let completedToday: Int
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Overall Completion")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                HStack(alignment: .lastTextBaseline) {
                    Text(String(format: "%.0f%%", overallCompletion))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryTextColor)

                    Spacer()

                    VStack(alignment: .trailing, spacing: HiveSpacing.xs) {
                        Text("Today")
                            .font(HiveTypography.caption)
                            .foregroundColor(theme.secondaryTextColor)
                        Text("\(completedToday) logged")
                            .font(HiveTypography.caption)
                            .foregroundColor(HiveColors.honeyGradientEnd)
                    }
                }

                ProgressView(value: min(max(overallCompletion / 100, 0), 1))
                    .tint(HiveColors.mintSuccess)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 12, x: 0, y: 8)
        )
    }
}

struct WeeklyProgressCard: View {
    let weeklyProgress: [Int]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("This Week")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            HStack(alignment: .bottom, spacing: HiveSpacing.sm) {
                let labels = ["S","M","T","W","T","F","S"]
                let maxValue = max(weeklyProgress.max() ?? 1, 1)
                ForEach(Array(weeklyProgress.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: HiveSpacing.xs) {
                        RoundedRectangle(cornerRadius: HiveRadius.small)
                            .fill(HiveColors.honeyGradientEnd.opacity(0.85))
                            .frame(width: 24, height: max(CGFloat(value) / CGFloat(maxValue), 0.05) * 90)

                        Text(labels[index % labels.count])
                            .font(HiveTypography.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 12, x: 0, y: 8)
        )
    }
}

struct StreaksCard: View {
    let currentStreaks: [HabitStreakDisplay]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Current Streaks")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            if currentStreaks.isEmpty {
                Text("No streaks yet — start pouring honey!")
                    .font(HiveTypography.body)
                    .foregroundColor(theme.secondaryTextColor)
            } else {
                VStack(spacing: HiveSpacing.sm) {
                    ForEach(currentStreaks) { streak in
                        HStack(spacing: HiveSpacing.md) {
                            Text(streak.emoji ?? "🐝")
                                .font(.system(size: 28))
                            Text(streak.name)
                                .font(HiveTypography.body)
                                .foregroundColor(theme.primaryTextColor)
                            Spacer()
                            Text("\(streak.streak) 🔥")
                                .font(HiveTypography.headline)
                                .foregroundColor(HiveColors.honeyGradientEnd)
                        }
                        .padding(HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                .fill(HiveColors.lightGray)
                        )
                    }
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 12, x: 0, y: 8)
        )
    }
}

struct YearOverviewCard: View {
    let yearData: [String: Int]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Year Overview")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            YearHeatmapView(data: yearData, theme: theme)
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 12, x: 0, y: 8)
        )
    }
}

struct BestHabitCard: View {
    let bestPerformer: HabitPerformanceSummary?
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Best Performing")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            if let best = bestPerformer {
                HStack(spacing: HiveSpacing.md) {
                    Text(best.emoji ?? "🏆")
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                        Text(best.name)
                            .font(HiveTypography.body)
                            .foregroundColor(theme.primaryTextColor)

                        Text(String(format: "%.0f%% complete", best.completionRate))
                            .font(HiveTypography.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }

                    Spacer()
                }
            } else {
                Text("Keep logging to unlock your top habit")
                    .font(HiveTypography.body)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 12, x: 0, y: 8)
        )
    }
}
