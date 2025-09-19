import SwiftUI
import Combine

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
                HiveCardStat(title: "Shared Streak", value: "\(hive.currentLength) days", theme: theme)
                HiveCardStat(title: "Members", value: "\(hive.memberCount ?? 0)", theme: theme)
                HiveCardStat(title: "Target", value: targetStatValue, theme: theme)
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme == .night ? Color.white.opacity(0.06) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(
                            LinearGradient(
                                colors: [hive.color.opacity(0.15), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipped()
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .stroke(hive.color.opacity(theme == .night ? 0.18 : 0.22), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(theme == .night ? 0.35 : 0.06), radius: 14, x: 0, y: 10)
        )
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

    private let apiClient = APIClient.shared
    private var cancellables = Set<Combine.AnyCancellable>()

    func loadHives() {
        Task {
            await loadHivesAsync()
        }
    }

    func joinHive(code: String) {
        apiClient.joinHive(code: code)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    self.loadHives()
                }
            )
            .store(in: &cancellables)
    }

    func refreshHives() async {
        await loadHivesAsync()
    }

    @MainActor
    private func loadHivesAsync() async {
        isLoading = true

        do {
            let hives = try await fetchHives()
            self.hives = hives
            let leaders = await fetchLeaderboard(for: hives)
            self.leaderboard = leaders
        } catch {
            self.errorMessage = error.localizedDescription
            self.hives = []
            self.leaderboard = []
        }

        isLoading = false
    }

    private func fetchHives() async throws -> [Hive] {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getHives()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { hives in
                        continuation.resume(returning: hives)
                    }
                )
                .store(in: &cancellables)
        }
    }

    private func fetchLeaderboard(for hives: [Hive]) async -> [HiveLeaderboardEntry] {
        guard !hives.isEmpty else { return [] }

        var accumulator: [String: HiveLeaderboardEntry] = [:]

        for hive in hives {
            do {
                let detail = try await fetchHiveDetail(hiveId: hive.id)
                let membersDone = Set(detail.todayStatus.membersDone)

                for member in detail.members {
                    var entry = accumulator[member.userId] ?? HiveLeaderboardEntry(
                        id: member.userId,
                        displayName: member.displayName ?? "Bee",
                        avatarURL: member.avatarUrl,
                        completedToday: 0,
                        totalHives: 0
                    )

                    entry.totalHives += 1
                    if membersDone.contains(member.userId) {
                        entry.completedToday += 1
                    }

                    accumulator[member.userId] = entry
                }
            } catch {
                continue
            }
        }

        return accumulator.values
            .sorted { lhs, rhs in
                if lhs.completedToday == rhs.completedToday {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.completedToday > rhs.completedToday
            }
            .prefix(5)
            .map { $0 }
    }

    private func fetchHiveDetail(hiveId: String) async throws -> HiveDetail {
        try await withCheckedThrowingContinuation { continuation in
            apiClient.getHiveDetail(hiveId: hiveId)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { detail in
                        continuation.resume(returning: detail)
                    }
                )
                .store(in: &cancellables)
        }
    }
}

struct HiveLeaderboardEntry: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String?
    var completedToday: Int
    var totalHives: Int

    var completionPercentage: Int {
        guard totalHives > 0 else { return 0 }
        return Int(round((Double(completedToday) / Double(totalHives)) * 100))
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return String(displayName.prefix(1)).uppercased()
    }

    var avatarColor: Color {
        let colors = HiveColors.habitColors
        let index = abs(id.hashValue) % max(colors.count, 1)
        return colors[index]
    }
}

private extension DateFormatter {
    static let hiveDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Insights View

struct InsightsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = InsightsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background like other screens
                themeManager.currentTheme.primaryGradient
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: HiveSpacing.lg) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Loading insights...")
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: HiveSpacing.lg) {
                            // Summary Card
                            summaryCard

                            // Weekly Stats
                            weeklyStatsCard

                            // Habit Performance
                            habitPerformanceCard
                        }
                        .padding(HiveSpacing.lg)
                    }
                    .refreshable {
                        await viewModel.refreshInsights()
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .onAppear {
                viewModel.loadInsights()
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: HiveSpacing.lg) {
            Text("Today's Summary")
                .font(HiveTypography.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: HiveSpacing.xl) {
                StatView(
                    value: "\(viewModel.completedToday)",
                    label: "Completed",
                    color: HiveColors.mintSuccess
                )

                StatView(
                    value: "\(viewModel.totalHabits)",
                    label: "Total",
                    color: HiveColors.honeyGradientEnd
                )

                StatView(
                    value: "\(viewModel.bestStreak)",
                    label: "Best Streak",
                    color: .orange
                )
            }
        }
        .padding(HiveSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var weeklyStatsCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            Text("This Week")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            HStack(spacing: HiveSpacing.sm) {
                ForEach(0..<7) { day in
                    VStack(spacing: HiveSpacing.xs) {
                        RoundedRectangle(cornerRadius: HiveRadius.small)
                            .fill(
                                day < 5 ?
                                Color.white.opacity(0.8) :
                                Color.white.opacity(0.2)
                            )
                            .frame(width: 35, height: CGFloat.random(in: 30...80))

                        Text(["S", "M", "T", "W", "T", "F", "S"][day])
                            .font(HiveTypography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, HiveSpacing.sm)
        }
        .padding(HiveSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var habitPerformanceCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            Text("Habit Performance")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if viewModel.habitStats.isEmpty {
                VStack(spacing: HiveSpacing.md) {
                    Text("🐝")
                        .font(.system(size: 48))

                    Text("No habits to track yet")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.lg)
            } else {
                VStack(spacing: HiveSpacing.md) {
                    ForEach(viewModel.habitStats.prefix(5)) { stat in
                        HStack(spacing: HiveSpacing.md) {
                            Text(stat.emoji)
                                .font(.system(size: 24))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.name)
                                    .font(HiveTypography.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)

                                Text("\(stat.completionRate)% completion")
                                    .font(HiveTypography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            HStack(spacing: HiveSpacing.xs) {
                                Text("\(stat.streak)")
                                    .font(HiveTypography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("🔥")
                                    .font(HiveTypography.caption)
                            }
                            .padding(.horizontal, HiveSpacing.sm)
                            .padding(.vertical, HiveSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                        .padding(.vertical, HiveSpacing.xs)
                    }
                }
            }
        }
        .padding(HiveSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: HiveSpacing.sm) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundColor(color)

            Text(label)
                .font(HiveTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}

struct ProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSettings = false
    @State private var isEditingName = false
    @State private var newDisplayName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background like other screens
                themeManager.currentTheme.primaryGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: HiveSpacing.xl) {
                        // Profile header with enhanced styling
                        VStack(spacing: HiveSpacing.lg) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

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
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(HiveSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
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
                                        .foregroundColor(.white)
                                        .onTapGesture {
                                            newDisplayName = viewModel.displayName
                                            isEditingName = true
                                        }
                                }

                                Text(viewModel.phone)
                                    .font(HiveTypography.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.top, HiveSpacing.xl)

                        // Settings card with enhanced styling
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                value: viewModel.notificationsEnabled ? "On" : "Off",
                                action: {
                                    viewModel.toggleNotifications()
                                }
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SettingsRow(
                                icon: "moon",
                                title: "Theme",
                                value: themeManager.currentTheme.rawValue.capitalized,
                                action: {
                                    viewModel.showThemeSelector = true
                                }
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SettingsRow(
                                icon: "clock",
                                title: "Day Start Time",
                                value: viewModel.dayStartTime,
                                action: {
                                    viewModel.showTimeSelector = true
                                }
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SettingsRow(
                                icon: "arrow.right.square",
                                title: "Sign Out",
                                isDestructive: true,
                                action: {
                                    apiClient.logout()
                                }
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HiveRadius.xlarge)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, HiveSpacing.lg)

                        Spacer(minLength: 100)
                    }
                }
            }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : .white)
                    .frame(width: 30)

                Text(title)
                    .font(HiveTypography.body)
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : .white)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, HiveSpacing.md)
            .padding(.horizontal, HiveSpacing.lg)
        }
    }
}

// MARK: - Insights Models
struct HabitStat: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let completionRate: Int
    let streak: Int
}

// MARK: - InsightsViewModel
class InsightsViewModel: ObservableObject {
    @Published var completedToday = 0
    @Published var totalHabits = 0
    @Published var bestStreak = 0
    @Published var habitStats: [HabitStat] = []
    @Published var isLoading = false

    private let apiClient = APIClient.shared
    private var cancellables = Set<Combine.AnyCancellable>()

    func loadInsights() {
        isLoading = true

        apiClient.getInsightsSummary()
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("Failed to load insights: \(error)")
                    }
                },
                receiveValue: { summary in
                    self.completedToday = summary.completedToday
                    self.totalHabits = summary.totalHabits
                    self.bestStreak = summary.bestStreak
                }
            )
            .store(in: &cancellables)

        // Load habit stats
        apiClient.getHabits(includeLogs: true, days: 7)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { habits in
                    self.habitStats = habits.map { habit in
                        HabitStat(
                            name: habit.name,
                            emoji: habit.emoji ?? "🎯",
                            completionRate: Int(habit.completionRate ?? 0),
                            streak: habit.currentStreak ?? 0
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }

    func refreshInsights() async {
        await loadInsightsAsync()
    }

    @MainActor
    private func loadInsightsAsync() async {
        isLoading = true

        do {
            let summary = try await withCheckedThrowingContinuation { continuation in
                apiClient.getInsightsSummary()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { summary in
                            continuation.resume(returning: summary)
                        }
                    )
                    .store(in: &cancellables)
            }

            self.completedToday = summary.completedToday
            self.totalHabits = summary.totalHabits
            self.bestStreak = summary.bestStreak
        } catch {
            print("Failed to load insights: \(error)")
        }

        isLoading = false
    }
}

// MARK: - ProfileViewModel
class ProfileViewModel: ObservableObject {
    @Published var displayName = "Bee"
    @Published var phone = ""
    @Published var isLoading = false
    @Published var notificationsEnabled = true
    @Published var dayStartHour = 4
    @Published var showThemeSelector = false
    @Published var showTimeSelector = false
    @Published var selectedStartTime = Date()

    private let apiClient = APIClient.shared
    private var cancellables = Set<Combine.AnyCancellable>()

    var dayStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let calendar = Calendar.current
        let dateWithHour = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: dateWithHour)
    }

    func loadProfile() {
        isLoading = true

        apiClient.getMyProfile()
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("Failed to load profile: \(error)")
                    }
                },
                receiveValue: { user in
                    self.displayName = user.displayName
                    self.phone = user.phone
                    self.dayStartHour = user.dayStartHour

                    // Update selectedStartTime for the picker
                    let calendar = Calendar.current
                    self.selectedStartTime = calendar.date(bySettingHour: self.dayStartHour, minute: 0, second: 0, of: Date()) ?? Date()
                }
            )
            .store(in: &cancellables)
    }

    func updateDisplayName(_ name: String) {
        let update = ProfileUpdate(displayName: name)

        apiClient.updateProfile(update)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to update profile: \(error)")
                    }
                },
                receiveValue: { user in
                    self.displayName = user.displayName
                }
            )
            .store(in: &cancellables)
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        // Note: Notifications preference is stored locally for now
        // Could be extended to sync with backend when notification settings are added to profiles table
    }

    func saveDayStartTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedStartTime)
        dayStartHour = hour

        let update = ProfileUpdate(dayStartHour: hour)

        apiClient.updateProfile(update)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to update day start time: \(error)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        showTimeSelector = false
    }
}

// MARK: - Create Hive From Habit View
struct CreateHiveFromHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateHiveViewModel()
    @State private var selectedHabitId: String?
    @State private var hiveName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    let onComplete: (Hive) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: HiveSpacing.lg) {
                Text("Select a habit to create a hive from")
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.slateText)
                    .padding(.top)

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: HiveSpacing.sm) {
                            ForEach(viewModel.habits) { habit in
                                HabitSelectionRow(
                                    habit: habit,
                                    isSelected: selectedHabitId == habit.id
                                ) {
                                    selectedHabitId = habit.id
                                    if hiveName.isEmpty {
                                        hiveName = "\(habit.name) Hive"
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                TextField("Hive Name", text: $hiveName)
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.slateText)
                    .padding(HiveSpacing.sm)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(HiveRadius.medium)

                Button(action: createHive) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Hive")
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .font(HiveTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.md)
                    .background(
                        LinearGradient(
                            colors: [HiveColors.honeyGradientStart, HiveColors.honeyGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(canCreate ? 1 : 0.5)
                    )
                    .cornerRadius(HiveRadius.large)
                }
                .disabled(!canCreate || isLoading)

                Spacer()
            }
            .padding(HiveSpacing.lg)
            .navigationTitle("Create Hive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadHabits()
        }
    }

    private var canCreate: Bool {
        !hiveName.isEmpty && selectedHabitId != nil
    }

    private func createHive() {
        guard let habitId = selectedHabitId else { return }

        isLoading = true
        viewModel.createHive(from: habitId, name: hiveName) { hive in
            onComplete(hive)
            dismiss()
        }
    }
}

// MARK: - Habit Selection Row
struct HabitSelectionRow: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(habit.color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(habit.emoji ?? "🎯")
                        .font(.system(size: 20))
                )

            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.slateText)

                Text(habit.type == .counter ? "Counter: \(habit.targetPerDay)/day" : "Daily habit")
                    .font(HiveTypography.caption)
                    .foregroundColor(HiveColors.slateText.opacity(0.7))
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(HiveColors.honeyGradientEnd)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(isSelected ? HiveColors.honeyGradientStart.opacity(0.1) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                        .stroke(isSelected ? HiveColors.honeyGradientEnd : Color.gray.opacity(0.2))
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Create Hive View Model
class CreateHiveViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false

    private let apiClient = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    func loadHabits() {
        isLoading = true

        apiClient.getHabits(includeLogs: false, days: 1)
            .sink(
                receiveCompletion: { _ in
                    self.isLoading = false
                },
                receiveValue: { habits in
                    self.habits = habits.filter { $0.isActive }
                }
            )
            .store(in: &cancellables)
    }

    func createHive(from habitId: String, name: String, completion: @escaping (Hive) -> Void) {
        apiClient.createHiveFromHabit(habitId: habitId, name: name, backfillDays: 30)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { hive in
                    completion(hive)
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    MainTabView()
}
