import SwiftUI

struct BranchHealthView: View {
    let repoName: String
    @EnvironmentObject private var monitorData: MonitorData

    private var branches: [BranchInfo] {
        monitorData.branches[repoName] ?? []
    }

    var body: some View {
        VStack(spacing: 24) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    branchList
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Branch Health")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(repoName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if monitorData.isLoading { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var summaryCards: some View {
        let total = branches.count
        let stale = branches.filter { $0.isStale }.count
        let protected_ = branches.filter { $0.isProtected }.count

        let gridColumns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
        LazyVGrid(columns: gridColumns, spacing: 16) {
            SummaryCard(title: "Total Branches", value: "\(total)", icon: "point.3.connected.trianglepath.dotted")
            SummaryCard(title: "Stale (30+ days)", value: "\(stale)", icon: "exclamationmark.triangle")
            SummaryCard(title: "Protected", value: "\(protected_)", icon: "lock.shield")
        }
    }

    @ViewBuilder
    private var branchList: some View {
        let staleBranches = branches.filter { $0.isStale }
        let activeBranches = branches.filter { !$0.isStale }

        VStack(alignment: .leading, spacing: 16) {
            if staleBranches.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("No stale branches")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stale Branches (\(staleBranches.count))")
                        .font(.headline)
                        .foregroundStyle(Color.orange)

                    ForEach(staleBranches.prefix(20)) { branch in
                        HStack {
                            Text(branch.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            if let date = branch.lastCommitDate {
                                Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }

            if !activeBranches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Branches (\(activeBranches.count))")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)

                    ForEach(activeBranches.prefix(20)) { branch in
                        HStack {
                            HStack(spacing: 6) {
                                if branch.isProtected {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundStyle(Theme.accent)
                                        .font(.caption2)
                                }
                                Text(branch.name)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let date = branch.lastCommitDate {
                                Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
    }
}

struct BranchHealthView_Previews: PreviewProvider {
    static var previews: some View {
        BranchHealthView(repoName: "owner/repo")
            .environmentObject(MonitorData())
    }
}
