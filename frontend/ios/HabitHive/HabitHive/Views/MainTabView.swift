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
            .sheet(isPresented: $showJoinHive, onDismiss: {
                viewModel.resetJoinStatus()
            }) {
                JoinHiveSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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

            YearHeatmapView(
                startDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date(),
                endDate: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date(),
                data: viewModel.yearComb,
                maxValue: viewModel.yearComb.values.max() ?? 1,
                accentColor: HiveColors.honeyGradientStart,
                theme: themeManager.currentTheme
            )
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

enum HiveJoinStatus: Equatable {
    case idle
    case joining
    case success(message: String)
    case failure(message: String)
}

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
    @Published var joinStatus: HiveJoinStatus = .idle

    private let apiClient = FastAPIClient.shared
    private var lastLoadedAt: Date?
    private let freshnessInterval: TimeInterval = 120

    func loadHives() {
        Task { await loadHivesAsync(force: false) }
    }

    @MainActor
    func joinHive(code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !normalized.isEmpty else {
            joinStatus = .failure(message: "Enter an invite code to continue.")
            return
        }

        joinStatus = .joining

        do {
            let result = try await apiClient.joinHive(code: normalized)
            await loadHivesAsync(force: true)
            let message = result.message ?? "You're in the hive!"
            joinStatus = .success(message: message)
        } catch {
            joinStatus = .failure(message: humanReadableMessage(for: error))
        }
    }

    @MainActor
    func resetJoinStatus() {
        joinStatus = .idle
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
            // Don't clear existing hives on refresh error - keep cached data
            if !force {
                // Only clear on initial load failure
                self.hives = []
                self.leaderboard = []
                lastLoadedAt = nil
            }
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

    private func humanReadableMessage(for error: Error) -> String {
        if let fastError = error as? FastAPIError {
            switch fastError {
            case .networkError(let message):
                return message
            case .serverError(_, let payload):
                if let data = payload.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(ServerErrorMessage.self, from: data),
                   let detail = decoded.detail {
                    return detail
                }
                if let data = payload.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = json["detail"] as? String {
                    return detail
                }
                return payload
            default:
                return fastError.errorDescription ?? "Something went wrong."
            }
        }
        return error.localizedDescription
    }

    private struct ServerErrorMessage: Decodable {
        let detail: String?
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = InsightsViewModel()

    private var backgroundColor: Color {
        themeManager.currentTheme == .night ? themeManager.currentTheme.backgroundColor : HiveColors.creamBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                insightsContent
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Insights")
                        .font(HiveTypography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor.opacity(0.95), for: .navigationBar)
            .toolbarColorScheme(themeManager.currentTheme == .night ? .dark : .light, for: .navigationBar)
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
                VStack(alignment: .leading, spacing: HiveSpacing.md) {
                    rangePicker
                        .padding(.top, HiveSpacing.sm)
                    statsCards
                    yearOverviewCard
                    habitPerformanceCard
                }
                .padding(.horizontal, HiveSpacing.lg)
                .padding(.bottom, HiveSpacing.xl)
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
        let theme = themeManager.currentTheme
        return Picker("Range", selection: $viewModel.selectedRange) {
            ForEach(InsightRange.allCases, id: \.self) { range in
                Text(range.displayName)
                    .fontWeight(.semibold)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .stroke(HiveColors.honeyGradientEnd.opacity(0.2), lineWidth: 1)
        )
        .tint(HiveColors.honeyGradientEnd)
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

                if !viewModel.heatmapFilters.isEmpty {
                    let selected = viewModel.heatmapFilters.first(where: { $0.id == viewModel.selectedHeatmapFilterID })
                    Menu {
                        ForEach(viewModel.heatmapFilters) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedHeatmapFilterID = option.id
                                }
                            } label: {
                                HStack {
                                    if let emoji = option.emoji {
                                        Text(emoji)
                                    }
                                    Text(option.title)
                                    if option.id == viewModel.selectedHeatmapFilterID {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: HiveSpacing.xs) {
                            if let emoji = selected?.emoji {
                                Text(emoji)
                            }
                            Text(selected?.title ?? "All Habits")
                                .font(HiveTypography.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, HiveSpacing.sm)
                        .padding(.vertical, HiveSpacing.xs)
                        .background(
                            Capsule()
                                .fill(themeManager.currentTheme == .night ? Color.white.opacity(0.08) : Color.white.opacity(0.65))
                        )
                    }
                    .disabled(viewModel.heatmapFilters.count <= 1)
                }
            }

            if let overview = viewModel.yearOverview {
                YearHeatmapView(
                    startDate: overview.startDate,
                    endDate: overview.endDate,
                    data: viewModel.selectedHeatmapData,
                    maxValue: viewModel.selectedHeatmapMaxValue,
                    accentColor: viewModel.selectedHeatmapAccent,
                    theme: themeManager.currentTheme
                )
            } else if viewModel.isLoading {
                HStack(spacing: HiveSpacing.sm) {
                    ProgressView()
                    Text("Building comb view…")
                        .font(HiveTypography.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No check-ins logged for this year yet.")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    @Published var yearOverview: YearOverviewModel?
    @Published var heatmapFilters: [HeatmapFilterOption] = []
    @Published var selectedHeatmapFilterID: String = HeatmapFilterOption.allID

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
            async let dashboardTask = apiClient.getInsightsDashboard()
            async let overviewTask = apiClient.getYearOverview()

            let (dashboard, overview) = try await (dashboardTask, overviewTask)
            self.dashboard = dashboard
            applyYearOverview(overview)
            lastLoadedAt = Date()
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var currentStats: InsightsRangeStatsModel? {
        guard let dashboard else { return nil }
        return dashboard.stats(for: selectedRange)
    }

    var selectedHeatmapData: [String: Int] {
        guard let option = heatmapFilters.first(where: { $0.id == selectedHeatmapFilterID }) else {
            return [:]
        }
        return option.counts
    }

    var selectedHeatmapMaxValue: Int {
        heatmapFilters.first(where: { $0.id == selectedHeatmapFilterID })?.maxValue ?? 0
    }

    var selectedHeatmapAccent: Color {
        heatmapFilters.first(where: { $0.id == selectedHeatmapFilterID })?.accentColor ?? HiveColors.honeyGradientEnd
    }

    private func applyYearOverview(_ overview: YearOverviewModel) {
        yearOverview = overview

        var filters: [HeatmapFilterOption] = [HeatmapFilterOption(
            id: HeatmapFilterOption.allID,
            title: "All Habits",
            emoji: nil,
            counts: overview.totals,
            maxValue: max(overview.maxTotal, 0),
            accentHex: nil
        )]

        for habit in overview.habits {
            let maxValue = habit.counts.values.max() ?? 0
            filters.append(
                HeatmapFilterOption(
                    id: habit.id,
                    title: habit.name,
                    emoji: habit.emoji,
                    counts: habit.counts,
                    maxValue: maxValue,
                    accentHex: habit.colorHex
                )
            )
        }

        heatmapFilters = filters

        if !filters.contains(where: { $0.id == selectedHeatmapFilterID }) {
            selectedHeatmapFilterID = filters.first?.id ?? HeatmapFilterOption.allID
        }
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
    @State private var showEditProfile = false

    private var backgroundColor: Color {
        themeManager.currentTheme == .night ? themeManager.currentTheme.backgroundColor : HiveColors.creamBase
    }

var body: some View {
        NavigationView {
            ZStack {
                backgroundColor
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
                                Text(viewModel.displayName)
                                    .font(HiveTypography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.currentTheme.primaryTextColor)

                                Text(viewModel.phone.isEmpty ? "Add your phone to find friends" : viewModel.phone)
                                    .font(HiveTypography.body)
                                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                                Button {
                                    showEditProfile = true
                                } label: {
                                    Text("Edit Profile")
                                        .font(HiveTypography.caption)
                                        .foregroundColor(HiveColors.honeyGradientEnd)
                                        .padding(.horizontal, HiveSpacing.md)
                                        .padding(.vertical, HiveSpacing.xs)
                                        .background(
                                            Capsule()
                                                .stroke(HiveColors.honeyGradientEnd, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .padding(.top, HiveSpacing.xs)
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
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(viewModel: viewModel)
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

struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var phone: String = ""
    @State private var showSuccessToast = false
    @FocusState private var focusedField: EditProfileField?

    enum EditProfileField {
        case displayName, phone
    }

    private var backgroundColor: Color {
        themeManager.currentTheme == .night ? themeManager.currentTheme.backgroundColor : HiveColors.creamBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: HiveSpacing.lg) {
                        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                            Text("Display Name")
                                .font(HiveTypography.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                            TextField("Enter your name", text: $displayName)
                                .font(HiveTypography.body)
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                                        .fill(themeManager.currentTheme.cardBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                .stroke(themeManager.currentTheme.secondaryTextColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .focused($focusedField, equals: .displayName)
                        }

                        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                            Text("Phone Number")
                                .font(HiveTypography.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                            TextField("Enter your phone number", text: $phone)
                                .font(HiveTypography.body)
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                                        .fill(themeManager.currentTheme.cardBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                .stroke(themeManager.currentTheme.secondaryTextColor.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .focused($focusedField, equals: .phone)
                        }

                        if let error = viewModel.updateError {
                            Text(error)
                                .font(HiveTypography.caption)
                                .foregroundColor(HiveColors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }

                        Button {
                            Task {
                                let success = await viewModel.updateProfile(
                                    displayName: displayName,
                                    phone: phone
                                )
                                if success {
                                    withAnimation {
                                        showSuccessToast = true
                                    }
#if canImport(UIKit)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        dismiss()
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: HiveSpacing.sm) {
                                if viewModel.isUpdatingProfile {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                }
                                Text(viewModel.isUpdatingProfile ? "Saving…" : "Save Changes")
                                    .font(HiveTypography.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HiveSpacing.sm)
                            .background(
                                LinearGradient(
                                    colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .cornerRadius(HiveRadius.modal)
                            )
                            .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isUpdatingProfile || displayName.isEmpty)
                        .opacity(displayName.isEmpty && !viewModel.isUpdatingProfile ? 0.6 : 1)

                        Spacer()
                    }
                    .padding(HiveSpacing.lg)
                }

                if showSuccessToast {
                    VStack {
                        Spacer()
                        HStack(spacing: HiveSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(HiveColors.mintSuccess)
                            Text("Profile updated!")
                                .font(HiveTypography.body)
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                        }
                        .padding(.horizontal, HiveSpacing.lg)
                        .padding(.vertical, HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(themeManager.currentTheme.cardBackgroundColor)
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        )
                        .padding(.bottom, HiveSpacing.xl)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                }
            }
            .onAppear {
                displayName = viewModel.displayName
                phone = viewModel.phone
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    focusedField = .displayName
                }
            }
        }
    }
}


class ProfileViewModel: ObservableObject {
    @Published var displayName = "Bee"
    @Published var phone = ""
    @Published var isLoading = false
    @Published var notificationsEnabled = true
    @Published var dayStartHour = 4
    @Published var showTimeSelector = false
    @Published var selectedStartTime = Date()
    @Published var showDeleteConfirmation = false
    @Published var deleteError: String?
    @Published var isDeletingAccount = false
    @Published var isUpdatingProfile = false
    @Published var updateError: String?

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

    func updateProfile(displayName: String, phone: String) async -> Bool {
        await MainActor.run {
            isUpdatingProfile = true
            updateError = nil
        }
        defer {
            Task { @MainActor in
                isUpdatingProfile = false
            }
        }

        do {
            let update = ProfileUpdate(
                displayName: displayName.isEmpty ? nil : displayName,
                phone: phone.isEmpty ? nil : phone
            )
            let updated = try await apiClient.updateProfile(update)
            await MainActor.run {
                self.displayName = updated.displayName
                self.phone = updated.phone
            }
            return true
        } catch {
            await MainActor.run {
                if let apiError = error as? FastAPIError {
                    updateError = apiError.localizedDescription
                } else {
                    updateError = error.localizedDescription
                }
            }
            return false
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
struct HeatmapFilterOption: Identifiable, Hashable {
    static let allID = "all"

    let id: String
    let title: String
    let emoji: String?
    let counts: [String: Int]
    let maxValue: Int
    let accentHex: String?

    var accentColor: Color {
        guard let hex = accentHex else { return HiveColors.honeyGradientEnd }
        return Color(hex: hex)
    }
}

struct YearHeatmapView: View {
    let startDate: Date
    let endDate: Date
    let data: [String: Int]
    let maxValue: Int
    let accentColor: Color
    let theme: AppTheme

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var weeks: [[Date]] {
        let calendar = calendar
        let start = calendar.startOfWeek(for: startDate)
        guard let paddedEnd = calendar.date(byAdding: .day, value: 6, to: endDate) else {
            return []
        }

        let totalDays = calendar.dateComponents([.day], from: start, to: paddedEnd).day ?? 0
        var days: [Date] = []

        for offset in 0...totalDays {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                days.append(day)
            }
        }

        var result: [[Date]] = []
        var index = 0
        while index < days.count {
            let endIndex = min(index + 7, days.count)
            var week = Array(days[index..<endIndex])
            if week.count < 7, let last = week.last {
                while week.count < 7, let next = calendar.date(byAdding: .day, value: 1, to: week.last ?? last) {
                    week.append(next)
                }
            }
            result.append(week)
            index += 7
        }

        return result
    }

    private var monthLabels: [String] {
        var labels: [String] = []
        var currentMonth: Int?
        let calendar = calendar
        let formatter = monthFormatter

        for week in weeks {
            let validDays = week.filter { $0 >= startDate && $0 <= endDate }
            guard let reference = validDays.first else {
                labels.append(" ")
                continue
            }

            let month = calendar.component(.month, from: reference)
            if month != currentMonth {
                labels.append(formatter.string(from: reference))
                currentMonth = month
            } else {
                labels.append(" ")
            }
        }

        return labels
    }

    private var emptyColor: Color {
        theme == .night ? Color.white.opacity(0.1) : HiveColors.borderColor.opacity(0.25)
    }

    private func cellColor(for value: Int) -> Color {
        guard value > 0, maxValue > 0 else { return emptyColor }
        let ratio = min(Double(value) / Double(maxValue), 1.0)
        let minOpacity = theme == .night ? 0.25 : 0.35
        let maxOpacity = theme == .night ? 0.9 : 0.95
        let opacity = minOpacity + (maxOpacity - minOpacity) * ratio
        return accentColor.opacity(opacity)
    }

    private func value(for date: Date) -> Int {
        let key = Self.dayFormatter.string(from: date)
        return data[key, default: 0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    let labels = monthLabels
                    LazyHStack(alignment: .top, spacing: 4) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            VStack(spacing: 4) {
                                Text(labels[index])
                                    .font(HiveTypography.caption2)
                                    .foregroundColor(theme.secondaryTextColor)
                                    .frame(height: 12)

                                VStack(spacing: 4) {
                                    ForEach(0..<7, id: \.self) { row in
                                        let day = week[row]
                                        HeatmapCell(
                                            value: value(for: day),
                                            color: cellColor(for: value(for: day)),
                                            theme: theme
                                        )
                                    }
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    // Scroll to current month
                    if let currentWeekIndex = currentMonthWeekIndex {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentWeekIndex, anchor: .center)
                            }
                        }
                    }
                }
            }

            if maxValue > 0 {
                HeatmapLegend(accent: accentColor, theme: theme)
            }
        }
    }

    private var currentMonthWeekIndex: Int? {
        let currentMonth = calendar.component(.month, from: Date())
        for (index, week) in weeks.enumerated() {
            let validDays = week.filter { $0 >= startDate && $0 <= endDate }
            guard let reference = validDays.first else { continue }
            let month = calendar.component(.month, from: reference)
            if month == currentMonth {
                return index
            }
        }
        return nil
    }
}

private struct HeatmapCell: View {
    let value: Int
    let color: Color
    let theme: AppTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme == .night ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
            )
            .accessibilityLabel("\(value) completions")
    }
}

private struct HeatmapLegend: View {
    let accent: Color
    let theme: AppTheme

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            Text("Less")
                .font(HiveTypography.caption2)
                .foregroundColor(theme.secondaryTextColor)

            LinearGradient(
                colors: [accent.opacity(theme == .night ? 0.25 : 0.35), accent.opacity(theme == .night ? 0.9 : 0.95)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 80, height: 8)
            .clipShape(Capsule())

            Text("More")
                .font(HiveTypography.caption2)
                .foregroundColor(theme.secondaryTextColor)
        }
    }
}

// MARK: - Join Hive Sheet

struct JoinHiveSheet: View {
    @ObservedObject var viewModel: HivesViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode: String = ""
    @State private var showSuccessState = false
    @State private var successMessage = ""
    @FocusState private var isFocused: Bool

    private var isJoining: Bool {
        if case .joining = viewModel.joinStatus { return true }
        return false
    }

    private var errorMessage: String? {
        if case .failure(let message) = viewModel.joinStatus { return message }
        return nil
    }

    var body: some View {
        ZStack {
            sheetContent
                .blur(radius: showSuccessState ? 6 : 0)
                .allowsHitTesting(!showSuccessState)

            if showSuccessState {
                successView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .interactiveDismissDisabled(isJoining)
        .background(themeManager.currentTheme.backgroundColor.ignoresSafeArea())
        .onAppear {
            inviteCode = ""
            viewModel.resetJoinStatus()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isFocused = true
            }
        }
        .onChange(of: viewModel.joinStatus) { status in
            switch status {
            case .success(let message):
                successMessage = message
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showSuccessState = true
                }
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
                Task {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    dismiss()
                    await MainActor.run {
                        viewModel.resetJoinStatus()
                        showSuccessState = false
                    }
                }
            case .failure:
#if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
            default:
                break
            }
        }
    }

    private var sheetContent: some View {
        VStack(spacing: HiveSpacing.lg) {
            Capsule()
                .fill(themeManager.currentTheme.secondaryTextColor.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, HiveSpacing.sm)

            VStack(spacing: HiveSpacing.xs) {
                Text("Join Hive")
                    .font(HiveTypography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)

                Text("Enter the invite code your friend shared to hop into their hive.")
                    .font(HiveTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .padding(.horizontal, HiveSpacing.lg)
            }

            VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                Text("Invite Code")
                    .font(HiveTypography.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                TextField("ABC123", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .font(HiveTypography.headline)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(themeManager.currentTheme.cardBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: HiveRadius.medium)
                                    .stroke(themeManager.currentTheme.secondaryTextColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .focused($isFocused)
                    .onChange(of: inviteCode) { newValue in
                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        if filtered != inviteCode {
                            inviteCode = filtered
                        }
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(HiveTypography.caption)
                    .foregroundColor(HiveColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Button {
                Task { await viewModel.joinHive(code: inviteCode) }
            } label: {
                HStack(spacing: HiveSpacing.sm) {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(isJoining ? "Joining…" : "Join Hive")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.sm)
                .background(
                    LinearGradient(
                        colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(HiveRadius.modal)
                )
                .shadow(color: HiveColors.honeyGradientEnd.opacity(0.25), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isJoining || inviteCode.count < 4)
            .opacity(inviteCode.count < 4 && !isJoining ? 0.6 : 1)

            Button(role: .cancel) {
                dismiss()
                viewModel.resetJoinStatus()
            } label: {
                Text("Cancel")
                    .font(HiveTypography.body)
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .padding(.vertical, HiveSpacing.sm)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: HiveSpacing.md)
        }
        .padding(.horizontal, HiveSpacing.lg)
        .padding(.bottom, HiveSpacing.xl)
        .background(themeManager.currentTheme.backgroundColor)
    }

    private var successView: some View {
        VStack(spacing: HiveSpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(HiveColors.mintSuccess)
                .font(.system(size: 44))

            Text(successMessage.isEmpty ? "Joined!" : successMessage)
                .font(HiveTypography.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                .padding(.horizontal, HiveSpacing.lg)
        }
        .padding(HiveSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(themeManager.currentTheme == .night ? 0.35 : 0.1), radius: 16, x: 0, y: 8)
        )
        .padding(.horizontal, HiveSpacing.lg)
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
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

            YearHeatmapView(
                startDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
                endDate: Date(),
                data: yearData,
                maxValue: yearData.values.max() ?? 1,
                accentColor: HiveColors.honeyGradientStart,
                theme: theme
            )
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
