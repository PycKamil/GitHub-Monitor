import SwiftUI

struct ReleasesView: View {
    let repoName: String
    @EnvironmentObject private var monitorData: MonitorData

    private var releases: [ReleaseInfo] {
        (monitorData.releases[repoName] ?? []).sorted { $0.publishedAt > $1.publishedAt }
    }

    var body: some View {
        VStack(spacing: 24) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    timeline
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
                Text("Releases")
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
        let total = releases.count
        let prerelease = releases.filter { $0.isPrerelease }.count
        let latest = releases.first

        let gridColumns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
        LazyVGrid(columns: gridColumns, spacing: 16) {
            SummaryCard(title: "Total Releases", value: "\(total)", icon: "tag")
            SummaryCard(title: "Pre-releases", value: "\(prerelease)", icon: "tag.circle")
            SummaryCard(title: "Latest", value: latest?.tagName ?? "—", icon: "star")
        }
    }

    @ViewBuilder
    private var timeline: some View {
        if releases.isEmpty {
            Text("No releases found.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 8)

                ForEach(Array(releases.prefix(30).enumerated()), id: \.offset) { _, release in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(release.isPrerelease ? Color.orange : Theme.accent)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(release.tagName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.textPrimary)
                                if release.isPrerelease {
                                    Text("pre")
                                        .font(.caption2)
                                        .foregroundStyle(Color.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .glassCapsule(tint: Color.orange.opacity(0.3), interactive: false, fallbackFill: Color.orange.opacity(0.15))
                                }
                            }
                            Text(formatted(release.publishedAt))
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(16)
            .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

struct ReleasesView_Previews: PreviewProvider {
    static var previews: some View {
        ReleasesView(repoName: "owner/repo")
            .environmentObject(MonitorData())
    }
}
