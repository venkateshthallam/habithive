import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HiveDetailView: View {
    let hiveId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = HiveDetailViewModel()

    @State private var shareContent: ShareContent?
    @State private var showDeleteAlert = false
    @State private var logConfirmation: String?

    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            if let hive = viewModel.hive {
                ScrollView {
                    VStack(spacing: HiveSpacing.lg) {
                        headerCard(for: hive)
                        progressCard(for: hive)
                        membersCard(for: hive)
                        activityCard(for: hive)

                        if viewModel.isOwner {
                            deleteCard
                        }
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.bottom, HiveSpacing.xl)
                    .padding(.top, HiveSpacing.lg)
                }
                .refreshable { viewModel.load(hiveId: hiveId) }
            } else if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(HiveColors.honeyGradientEnd)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: HiveSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(HiveColors.error)
                    Text(error)
                        .font(HiveTypography.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(HiveColors.beeBlack)
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.hive?.name ?? "Hive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $shareContent) { share in
            ActivityView(activityItems: [share.text])
        }
        .alert(logConfirmation ?? "", isPresented: Binding(
            get: { logConfirmation != nil },
            set: { if !$0 { logConfirmation = nil } }
        )) {
            Button("OK", role: .cancel) { }
        }
        .alert("Delete Hive?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let hive = viewModel.hive {
                    viewModel.deleteHive(hiveId: hive.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the hive for everyone. This action cannot be undone.")
        }
        .onReceive(viewModel.$latestInviteCode.compactMap { $0 }) { code in
            shareContent = ShareContent(text: "Join my HabitHive group! Use code: \(code)")
        }
        .onReceive(viewModel.$logConfirmationMessage.compactMap { $0 }) { message in
            logConfirmation = message
        }
        .onReceive(viewModel.$didDelete.filter { $0 }) { _ in
            dismiss()
        }
        .onAppear { viewModel.load(hiveId: hiveId) }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if let hive = viewModel.hive {
                Button { viewModel.createInvite(hiveId: hive.id) } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("Invite members")

                Button { viewModel.logToday(hiveId: hive.id) } label: {
                    Image(systemName: "drop.fill")
                }
                .disabled(viewModel.hasCompletedToday(hive: hive))
                .opacity(viewModel.hasCompletedToday(hive: hive) ? 0.4 : 1)
                .accessibilityLabel("Log today")
            }
        }
    }

    private func headerCard(for hive: HiveDetail) -> some View {
        let subtitle = hive.description?.isEmpty == false
            ? hive.description!
            : "\(hive.targetPerDay) per day goal"

        return VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                Text(hive.emoji ?? "🐝")
                    .font(.system(size: 44))

                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    Text(hive.name)
                        .font(HiveTypography.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(HiveColors.beeBlack)

                    Text(subtitle)
                        .font(HiveTypography.body)
                        .foregroundColor(HiveColors.beeBlack.opacity(0.75))
                }
            }

            HStack(spacing: HiveSpacing.md) {
                summaryStat(title: "Members", value: "\(hive.memberCount ?? hive.members.count)")
                summaryStat(title: "Group Streak", value: "\(hive.currentStreak ?? hive.currentLength ?? 0)")
                summaryStat(title: "Avg Completion", value: "\(Int(hive.avgCompletion.rounded()))%")
            }

            if let inviteCode = hive.inviteCode, !inviteCode.isEmpty {
                Button {
#if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    UIPasteboard.general.string = inviteCode
#endif
                    shareContent = ShareContent(text: "Join my HabitHive group! Use code: \(inviteCode)")
                } label: {
                    HStack(spacing: HiveSpacing.xs) {
                        Image(systemName: "link")
                        Text("Copy invite code • \(inviteCode.uppercased())")
                    }
                    .font(HiveTypography.caption)
                    .foregroundColor(HiveColors.beeBlack)
                    .padding(.horizontal, HiveSpacing.md)
                    .padding(.vertical, HiveSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(Color.white.opacity(0.45))
                    )
                }
            }
        }
        .padding(HiveSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFD166"), Color(hex: "#FF9F1C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(HiveRadius.large)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func progressCard(for hive: HiveDetail) -> some View {
        let theme = themeManager.currentTheme
        let summary = hive.todaySummary

        return VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Today's Hive Progress")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            HiveProgressBar(summary: summary)
                .frame(height: 16)
                .cornerRadius(8)

            HStack(spacing: HiveSpacing.sm) {
                progressLegend(color: HiveColors.mintSuccess, label: "Completed", value: summary.completed)
                progressLegend(color: HiveColors.honeyGradientEnd, label: "In Progress", value: summary.partial)
                progressLegend(color: HiveColors.lightGray, label: "Pending", value: summary.pending)
            }
        }
        .padding(HiveSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 10, x: 0, y: 6)
        )
    }

    private func membersCard(for hive: HiveDetail) -> some View {
        let theme = themeManager.currentTheme
        return VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Members")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            VStack(spacing: HiveSpacing.sm) {
                ForEach(hive.members) { member in
                    memberRow(member: member)
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 10, x: 0, y: 6)
        )
    }

    private func activityCard(for hive: HiveDetail) -> some View {
        let theme = themeManager.currentTheme
        return VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Activity")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            if hive.recentActivity.isEmpty {
                VStack(spacing: HiveSpacing.sm) {
                    Text("✨")
                        .font(.system(size: 28))

                    Text("No recent activity yet")
                        .font(HiveTypography.body)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.lg)
            } else {
                VStack(spacing: HiveSpacing.sm) {
                    ForEach(hive.recentActivity) { event in
                        HStack(spacing: HiveSpacing.md) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(HiveColors.honeyGradientEnd)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(HiveTypography.body)
                                    .foregroundColor(theme.primaryTextColor)

                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(HiveTypography.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                            }

                            Spacer()
                        }
                        .padding(HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.medium)
                                .fill(theme.cardBackgroundColor.opacity(0.95))
                                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.05), radius: 6, x: 0, y: 4)
                        )
                    }
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 10, x: 0, y: 6)
        )
    }

    private var deleteCard: some View {
        let theme = themeManager.currentTheme
        return VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Danger Zone")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.error)

            Text("Deleting the hive removes it for everyone. This cannot be undone.")
                .font(HiveTypography.caption)
                .foregroundColor(theme.secondaryTextColor)

            Button {
                showDeleteAlert = true
            } label: {
                Text("Delete Hive")
                    .font(HiveTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .fill(HiveColors.error)
                    )
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 10, x: 0, y: 6)
        )
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text(value)
                .font(HiveTypography.headline)
                .fontWeight(.bold)
                .foregroundColor(HiveColors.beeBlack)

            Text(title)
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.beeBlack.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressLegend(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: HiveSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text("\(value) \(label)")
                .font(HiveTypography.caption)
                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memberRow(member: HiveMemberStatus) -> some View {
        let theme = themeManager.currentTheme
        let isCurrentUser = member.userId == FastAPIClient.shared.currentUser?.id

        let style: (String, Color) = {
            switch member.status {
            case .completed: return ("Completed today", HiveColors.mintSuccess)
            case .partial: return ("In progress", HiveColors.honeyGradientEnd)
            case .pending: return ("Pending", HiveColors.lightGray)
            }
        }()

        return HStack(spacing: HiveSpacing.md) {
            Circle()
                .fill(style.1)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName ?? "Bee")
                    .font(HiveTypography.body)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                    .foregroundColor(theme.primaryTextColor)

                Text(style.0)
                    .font(HiveTypography.caption)
                    .foregroundColor(style.1)
            }

            Spacer()

            Text("\(member.value)/\(member.targetPerDay)")
                .font(HiveTypography.caption)
                .foregroundColor(theme.primaryTextColor)
                .padding(.horizontal, HiveSpacing.sm)
                .padding(.vertical, HiveSpacing.xs)
                .background(
                    Capsule()
                        .fill(theme.cardBackgroundColor.opacity(0.85))
                )
        }
        .padding(.vertical, HiveSpacing.sm)
        .padding(.horizontal, HiveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(theme.backgroundColor.opacity(theme == .night ? 0.45 : 0.12))
        )
    }
}

private struct HiveProgressBar: View {
    let summary: HiveTodaySummary

    private struct Segment: Identifiable {
        let id = UUID()
        let fraction: Double
        let color: Color
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        if summary.completedFraction > 0 {
            result.append(Segment(fraction: summary.completedFraction, color: HiveColors.mintSuccess))
        }
        if summary.partialFraction > 0 {
            result.append(Segment(fraction: summary.partialFraction, color: HiveColors.honeyGradientEnd))
        }
        if summary.pendingFraction > 0 {
            result.append(Segment(fraction: summary.pendingFraction, color: HiveColors.lightGray))
        }
        if result.isEmpty {
            result.append(Segment(fraction: 1, color: HiveColors.lightGray.opacity(0.4)))
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    segment.color
                        .frame(width: geometry.size.width * segment.fraction)
                }
            }
        }
    }
}

private struct ShareContent: Identifiable {
    let id = UUID()
    let text: String
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

@MainActor
class HiveDetailViewModel: ObservableObject {
    @Published var hive: HiveDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var latestInviteCode: String?
    @Published var logConfirmationMessage: String?
    @Published var didDelete = false

    private let api = FastAPIClient.shared

    var isOwner: Bool {
        guard let hive, let me = api.currentUser?.id else { return false }
        return hive.ownerId == me
    }

    func hasCompletedToday(hive: HiveDetail) -> Bool {
        guard let me = api.currentUser?.id else { return false }
        return hive.members.first(where: { $0.userId == me })?.status == .completed
    }

    func load(hiveId: String) {
        Task { await loadHiveAsync(hiveId: hiveId) }
    }

    func logToday(hiveId: String) {
        guard let hive = hive, !hasCompletedToday(hive: hive) else { return }

        Task {
            do {
                _ = try await api.logHiveDay(hiveId: hiveId, value: 1)
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
                await MainActor.run { self.logConfirmationMessage = "Honey poured for today!" }
                await loadHiveAsync(hiveId: hiveId)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func createInvite(hiveId: String) {
        Task {
            do {
                let invite = try await api.createHiveInvite(hiveId: hiveId)
#if canImport(UIKit)
                UIPasteboard.general.string = invite.code
#endif
                await MainActor.run { self.latestInviteCode = invite.code }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteHive(hiveId: String) {
        Task {
            do {
                try await api.deleteHive(hiveId: hiveId)
                await MainActor.run { self.didDelete = true }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    @MainActor
    private func loadHiveAsync(hiveId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await api.getHiveDetail(hiveId: hiveId)
            self.hive = detail
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
