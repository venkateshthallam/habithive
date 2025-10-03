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
    @State private var showLeaveAlert = false
    @State private var logConfirmation: String?
    @State private var toastMessage: String?
    @State private var isErrorToast = false

    var body: some View {
        ZStack {
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            if let hive = viewModel.hive {
                ScrollView {
                    VStack(spacing: HiveSpacing.lg) {
                        headerCard(for: hive)
                        progressCard(for: hive)
                        heatmapCard(for: hive)
                        membersCard(for: hive)
                        activityCard(for: hive)

                        if viewModel.isOwner {
                            deleteCard
                        } else {
                            leaveCard
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
            .disabled(viewModel.isDeleting)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the hive for everyone. This action cannot be undone.")
        }
        .alert("Leave Hive?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) {
                if let hive = viewModel.hive {
                    viewModel.leaveHive(hiveId: hive.id)
                }
            }
            .disabled(viewModel.isLeaving)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will no longer be a member of this hive.")
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
        .onReceive(viewModel.$didLeave.filter { $0 }) { _ in
            toastMessage = "Left hive successfully"
            isErrorToast = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
        .onReceive(viewModel.$errorMessage.compactMap { $0 }) { error in
            toastMessage = error
            isErrorToast = true
        }
        .overlay(alignment: .top) {
            if let message = toastMessage {
                ToastView(message: message, isError: isErrorToast)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
            }
        }
        .onAppear { viewModel.load(hiveId: hiveId) }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // Toolbar items removed - log button moved to header card
        }
    }

    private func headerCard(for hive: HiveDetail) -> some View {
        let subtitle = hive.description?.isEmpty == false
            ? hive.description!
            : "\(hive.targetPerDay) per day goal"

        return VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                    Text(hive.emoji ?? "🐝")
                        .font(.system(size: 44))

                    VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                        Text(hive.name)
                            .font(HiveTypography.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)

                        Text(subtitle)
                            .font(HiveTypography.body)
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                    }
                }

                Spacer()

                Button {
                    viewModel.logToday(hiveId: hive.id)
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.hasCompletedToday(hive: hive) ? HiveColors.mintSuccess.opacity(0.3) : Color.white.opacity(0.85))
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                        if viewModel.hasCompletedToday(hive: hive) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(HiveColors.mintSuccess)
                        } else {
                            Text("🐝")
                                .font(.system(size: 28))
                        }
                    }
                }
                .disabled(viewModel.hasCompletedToday(hive: hive))
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
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .padding(.horizontal, HiveSpacing.md)
                    .padding(.vertical, HiveSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.medium)
                            .fill(Color.white.opacity(0.25))
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

    private func heatmapCard(for hive: HiveDetail) -> some View {
        let theme = themeManager.currentTheme
        return VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Last 30 Days")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            HiveHeatmapView(heatmap: hive.heatmap)
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
                HStack(spacing: HiveSpacing.sm) {
                    if viewModel.isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(viewModel.isDeleting ? "Deleting…" : "Delete Hive")
                        .font(HiveTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(HiveColors.error)
                )
            }
            .disabled(viewModel.isDeleting)
            .opacity(viewModel.isDeleting ? 0.7 : 1)
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(theme == .night ? 0.45 : 0.06), radius: 10, x: 0, y: 6)
        )
    }

    private var leaveCard: some View {
        let theme = themeManager.currentTheme
        return VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Leave Hive")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryTextColor)

            Text("You will no longer be a member of this hive.")
                .font(HiveTypography.caption)
                .foregroundColor(theme.secondaryTextColor)

            Button {
                showLeaveAlert = true
            } label: {
                HStack(spacing: HiveSpacing.sm) {
                    if viewModel.isLeaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(viewModel.isLeaving ? "Leaving…" : "Leave Hive")
                        .font(HiveTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.large)
                        .fill(HiveColors.warning)
                )
            }
            .disabled(viewModel.isLeaving)
            .opacity(viewModel.isLeaving ? 0.7 : 1)
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
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)

            Text(title)
                .font(HiveTypography.caption)
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
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
        let isOwner = viewModel.hive?.ownerId == member.userId

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
                HStack(spacing: HiveSpacing.xs) {
                    Text(member.displayName ?? "Bee")
                        .font(HiveTypography.body)
                        .fontWeight(isCurrentUser ? .semibold : .regular)
                        .foregroundColor(theme.primaryTextColor)

                    if isOwner {
                        Text("• Owner")
                            .font(HiveTypography.caption)
                            .foregroundColor(HiveColors.honeyGradientEnd)
                    }
                }

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

private struct ToastView: View {
    let message: String
    let isError: Bool
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? HiveColors.error : HiveColors.mintSuccess)

            Text(message)
                .font(HiveTypography.body)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
        }
        .padding(.horizontal, HiveSpacing.lg)
        .padding(.vertical, HiveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(themeManager.currentTheme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, HiveSpacing.lg)
    }
}

@MainActor
class HiveDetailViewModel: ObservableObject {
    @Published var hive: HiveDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var latestInviteCode: String?
    @Published var logConfirmationMessage: String?
    @Published var didDelete = false
    @Published var isDeleting = false
    @Published var didLeave = false
    @Published var isLeaving = false

    private let api = FastAPIClient.shared

    var isOwner: Bool {
        guard let hive, let me = api.currentUser?.id else {
            return false
        }
        // Normalize both IDs to lowercase for comparison (handles UUID case sensitivity)
        let normalizedOwnerId = hive.ownerId.lowercased()
        let normalizedUserId = me.lowercased()
        return normalizedOwnerId == normalizedUserId
    }

    func hasCompletedToday(hive: HiveDetail) -> Bool {
        guard let me = api.currentUser?.id else { return false }
        let normalizedMe = me.lowercased()
        let member = hive.members.first { $0.userId.lowercased() == normalizedMe }
        return member?.status == .completed
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
            await MainActor.run { self.isDeleting = true }

            // Optimistically dismiss
            await MainActor.run { self.didDelete = true }

            do {
                try await api.deleteHive(hiveId: hiveId)
                await MainActor.run { self.isDeleting = false }
            } catch {
                await MainActor.run {
                    self.isDeleting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func leaveHive(hiveId: String) {
        Task {
            await MainActor.run { self.isLeaving = true }
            do {
                try await api.leaveHive(hiveId: hiveId)
                await MainActor.run {
                    self.isLeaving = false
                    self.didLeave = true
                }
            } catch {
                await MainActor.run {
                    self.isLeaving = false
                    self.errorMessage = error.localizedDescription
                }
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
