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
                        membersCard(for: hive)
                        sharedProgressCard(for: hive)
                        activityCard(for: hive)

                        if viewModel.isOwner {
                            deleteCard
                        }
                    }
                    .padding(.horizontal, HiveSpacing.lg)
                    .padding(.bottom, HiveSpacing.xl)
                    .padding(.top, HiveSpacing.lg)
                }
                .refreshable {
                    viewModel.load(hiveId: hiveId)
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
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
        .onAppear {
            viewModel.load(hiveId: hiveId)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if let hive = viewModel.hive {
                Button {
                    viewModel.createInvite(hiveId: hive.id)
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("Invite members")

                Button {
                    viewModel.logToday(hiveId: hive.id)
                } label: {
                    Image(systemName: "drop.fill")
                }
                .disabled(viewModel.hasLoggedToday(hive))
                .opacity(viewModel.hasLoggedToday(hive) ? 0.4 : 1)
                .accessibilityLabel("Log today")
            }
        }
    }

    private func headerCard(for hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    Text(hive.name)
                        .font(HiveTypography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(HiveColors.beeBlack)

                    Text(hive.rule == "all_must_complete" ? "All members complete each day" : "Shared goal")
                        .font(HiveTypography.caption)
                        .foregroundColor(HiveColors.beeBlack.opacity(0.6))
                }

                Spacer()

                Text("🐝")
                    .font(.system(size: 32))
            }

            HStack(spacing: HiveSpacing.sm) {
                statPill(title: "Members", value: "\(hive.memberCount ?? hive.members.count)")
                statPill(title: "Streak", value: "\(hive.currentLength) 🔥")
                statPill(title: "Today", value: "\(hive.todayStatus.completeCount)/\(hive.todayStatus.requiredCount)")
            }

            HStack(spacing: HiveSpacing.sm) {
                Button {
                    viewModel.logToday(hiveId: hive.id)
                } label: {
                    Text(viewModel.hasLoggedToday(hive) ? "Logged for Today" : "Log Today")
                        .font(HiveTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(themeManager.currentTheme.primaryGradient)
                                .opacity(viewModel.hasLoggedToday(hive) ? 0.5 : 1)
                        )
                }
                .disabled(viewModel.hasLoggedToday(hive))

                Button {
                    viewModel.createInvite(hiveId: hive.id)
                } label: {
                    Text("Invite")
                        .font(HiveTypography.headline)
                        .foregroundColor(HiveColors.honeyGradientEnd)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HiveSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .stroke(HiveColors.honeyGradientEnd, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
        )
    }

    private func membersCard(for hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Members")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.beeBlack)

            VStack(spacing: HiveSpacing.sm) {
                ForEach(hive.members) { member in
                    memberRow(member: member, done: hive.todayStatus.membersDone.contains(member.userId))
                }
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private func sharedProgressCard(for hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Shared Progress")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.beeBlack)

            if hive.todayStatus.completeCount == hive.todayStatus.requiredCount {
                Text("Everyone has poured honey for today.🍯")
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.mintSuccess)
            } else {
                Text("Waiting on \(hive.todayStatus.requiredCount - hive.todayStatus.completeCount) bees")
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.beeBlack)
            }

            // Placeholder for future comb heatmap
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(HiveColors.lightGray)
                .frame(height: 120)
                .overlay(
                    Text("Month comb coming soon")
                        .font(HiveTypography.caption)
                        .foregroundColor(HiveColors.beeBlack.opacity(0.6))
                )
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private func activityCard(for hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            Text("Activity")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.beeBlack)

            if hive.recentActivity.isEmpty {
                VStack(spacing: HiveSpacing.sm) {
                    Text("✨")
                        .font(.system(size: 28))

                    Text("No recent activity yet")
                        .font(HiveTypography.body)
                        .foregroundColor(HiveColors.beeBlack.opacity(0.6))
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
                                    .foregroundColor(HiveColors.beeBlack)

                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(HiveTypography.caption)
                                    .foregroundColor(HiveColors.beeBlack.opacity(0.6))
                            }

                            Spacer()
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
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            Text("Danger Zone")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.error)

            Text("Deleting the hive removes shared progress for everyone.")
                .font(HiveTypography.body)
                .foregroundColor(HiveColors.beeBlack.opacity(0.6))

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Hive")
                    .font(HiveTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HiveSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .fill(HiveColors.error.opacity(0.1))
                    )
            }
        }
        .padding(HiveSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.large)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(HiveTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(HiveColors.beeBlack.opacity(0.55))
            Text(value)
                .font(HiveTypography.headline)
                .foregroundColor(HiveColors.beeBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, HiveSpacing.sm)
        .padding(.horizontal, HiveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(HiveColors.lightGray)
        )
    }

    private func memberRow(member: HiveMember, done: Bool) -> some View {
        HStack(spacing: HiveSpacing.md) {
            Circle()
                .fill(done ? HiveColors.mintSuccess.opacity(0.3) : HiveColors.lightGray)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(memberInitial(for: member))
                        .font(HiveTypography.headline)
                        .foregroundColor(HiveColors.beeBlack)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? "Bee")
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.beeBlack)

                Text(member.role.capitalized)
                    .font(HiveTypography.caption)
                    .foregroundColor(HiveColors.beeBlack.opacity(0.6))
            }

            Spacer()

            if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(HiveColors.mintSuccess)
            }
        }
        .padding(HiveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }

    private func memberInitial(for member: HiveMember) -> String {
        guard let displayName = member.displayName,
              let firstCharacter = displayName.first else {
            return "🐝"
        }
        return String(firstCharacter).uppercased()
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

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

    func hasLoggedToday(_ hive: HiveDetail) -> Bool {
        guard let me = api.currentUser?.id else { return false }
        return hive.todayStatus.membersDone.contains(me)
    }

    func load(hiveId: String) {
        Task { await loadHiveAsync(hiveId: hiveId) }
    }

    func logToday(hiveId: String) {
        guard let currentHive = hive else { return }
        if hasLoggedToday(currentHive) { return }

        Task {
            do {
                _ = try await api.logHiveDay(hiveId: hiveId, value: 1)
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
                await MainActor.run {
                    self.logConfirmationMessage = "Honey poured for today!"
                }
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
