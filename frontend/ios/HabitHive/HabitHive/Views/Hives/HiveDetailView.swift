import SwiftUI
import Combine

struct HiveDetailView: View {
    let hiveId: String
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewModel = HiveDetailViewModel()

    var body: some View {
        ZStack {
            // Gradient background like other screens
            themeManager.currentTheme.primaryGradient
                .ignoresSafeArea()

            if let hive = viewModel.hive {
                ScrollView {
                    VStack(spacing: HiveSpacing.xl) {
                        header(hive)
                        membersSection(hive)
                        monthCombPlaceholder()
                        activitySection(hive)
                    }
                    .padding(HiveSpacing.lg)
                }
                .refreshable { viewModel.load(hiveId: hiveId) }
            } else if viewModel.isLoading {
                VStack(spacing: HiveSpacing.lg) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Loading hive...")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                }
            } else if let err = viewModel.errorMessage, !err.isEmpty {
                VStack(spacing: HiveSpacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.8))
                    Text(err)
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HiveSpacing.lg)
                }
            }
        }
        .navigationTitle("Hive")
        .toolbar {
            if let hive = viewModel.hive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Invite") { viewModel.createInvite(hiveId: hive.id) }
                        Button("Log Today") { viewModel.logToday(hiveId: hive.id) }
                    }
                }
            }
        }
        .onAppear { viewModel.load(hiveId: hiveId) }
    }

    private func header(_ hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            HStack {
                Text(hive.name)
                    .font(HiveTypography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: HiveSpacing.lg) {
                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    HStack(spacing: HiveSpacing.xs) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(hive.memberCount ?? hive.members.count)")
                            .font(HiveTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("members")
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    HStack(spacing: HiveSpacing.xs) {
                        Text("🔥")
                        Text("\(hive.currentLength)")
                            .font(HiveTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("streak")
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                    HStack(spacing: HiveSpacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(hive.todayStatus.completeCount)/\(hive.todayStatus.requiredCount)")
                            .font(HiveTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Text("today")
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
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

    private func membersSection(_ hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            Text("Members")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(spacing: HiveSpacing.sm) {
                ForEach(hive.members) { member in
                    let done = hive.todayStatus.membersDone.contains(member.userId)
                    MemberRow(member: member, done: done)
                }
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

    private struct MemberRow: View {
        let member: HiveMember
        let done: Bool

        private var initial: String {
            if let name = member.displayName, let first = name.first {
                return String(first)
            }
            return "🐝"
        }

        var body: some View {
            HStack(spacing: HiveSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(done ? HiveColors.mintSuccess.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(initial)
                                .font(HiveTypography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName ?? "Bee")
                        .font(HiveTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text(member.role.capitalized)
                        .font(HiveTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
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
                RoundedRectangle(cornerRadius: HiveRadius.large)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveRadius.large)
                            .stroke(Color.white.opacity(done ? 0.3 : 0.15), lineWidth: 1)
                    )
            )
        }
    }

    private func monthCombPlaceholder() -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            Text("Shared Month")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(spacing: HiveSpacing.md) {
                Text("🍯")
                    .font(.system(size: 48))

                Text("Month comb coming soon")
                    .font(HiveTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
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

    private func activitySection(_ hive: HiveDetail) -> some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            Text("Activity")
                .font(HiveTypography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if hive.recentActivity.isEmpty {
                VStack(spacing: HiveSpacing.md) {
                    Text("✨")
                        .font(.system(size: 32))

                    Text("No recent activity")
                        .font(HiveTypography.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, HiveSpacing.lg)
            } else {
                VStack(spacing: HiveSpacing.sm) {
                    ForEach(hive.recentActivity) { ev in
                        HStack(spacing: HiveSpacing.md) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(HiveColors.honeyGradientEnd)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(HiveTypography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)

                                Text(ev.createdAt.formatted())
                                    .font(HiveTypography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(HiveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.large)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HiveRadius.large)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                }
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
}

class HiveDetailViewModel: ObservableObject {
    @Published var hive: HiveDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    private let api = APIClient.shared

    func load(hiveId: String) {
        isLoading = true
        api.getHiveDetail(hiveId: hiveId)
            .sink { completion in
                self.isLoading = false
                if case .failure(let err) = completion { self.errorMessage = err.localizedDescription }
            } receiveValue: { detail in
                self.hive = detail
            }
            .store(in: &cancellables)
    }

    func logToday(hiveId: String) {
        // Optimistic update
        if var current = self.hive {
            if current.todayStatus.completeCount < current.todayStatus.requiredCount {
                let me = APIClient.shared.currentUser?.id ?? ""
                var doneSet = Set(current.todayStatus.membersDone)
                doneSet.insert(me)
                current.todayStatus = TodayStatus(
                    completeCount: min(current.todayStatus.completeCount + 1, current.todayStatus.requiredCount),
                    requiredCount: current.todayStatus.requiredCount,
                    membersDone: Array(doneSet)
                )
                self.hive = current
            }
        }
        api.logHiveDay(hiveId: hiveId, value: 1)
            .sink { _ in } receiveValue: { _ in
                // light haptic on completion
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred()
                self.load(hiveId: hiveId)
            }
            .store(in: &cancellables)
    }

    func createInvite(hiveId: String) {
        api.createHiveInvite(hiveId: hiveId)
            .sink { _ in } receiveValue: { invite in
                UIPasteboard.general.string = invite.code
            }
            .store(in: &cancellables)
    }
}
