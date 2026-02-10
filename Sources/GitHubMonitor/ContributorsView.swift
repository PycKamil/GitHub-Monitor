import SwiftUI
import Charts

struct ContributorsView: View {
    let repoName: String
    @EnvironmentObject private var monitorData: MonitorData

    private var contributors: [ContributorStat] {
        (monitorData.contributors[repoName] ?? []).sorted { $0.contributions > $1.contributions }
    }

    private var weeklyCommits: [ChartBucket] {
        // Aggregate all contributors' weekly data into single weekly totals
        var weekMap: [Date: Int] = [:]
        for contributor in contributors {
            for week in contributor.weeks {
                weekMap[week.week, default: 0] += week.commits
            }
        }
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return weekMap.sorted { $0.key < $1.key }.map { (date, commits) in
            ChartBucket(date: date, label: df.string(from: date), value: commits, category: "Commits")
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    commitsChart
                    contributorList
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
                Text("Contributors")
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
        let totalContributors = contributors.count
        let totalCommits = contributors.reduce(0) { $0 + $1.contributions }

        let gridColumns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
        LazyVGrid(columns: gridColumns, spacing: 16) {
            SummaryCard(title: "Contributors", value: "\(totalContributors)", icon: "person.3")
            SummaryCard(title: "Total Commits", value: "\(totalCommits)", icon: "arrow.up.circle")
        }
    }

    @ViewBuilder
    private var commitsChart: some View {
        if !weeklyCommits.isEmpty {
            let firstDate = weeklyCommits.first?.date ?? Date()
            let lastDate = weeklyCommits.last?.date ?? Date()
            let subtitle = formatDateRange(firstDate, lastDate)

            VStack(alignment: .leading, spacing: 8) {
                Text("Commits Over Time")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)

                Chart(weeklyCommits) { bucket in
                    BarMark(
                        x: .value("Week", bucket.date, unit: .weekOfYear),
                        y: .value("Contributions", bucket.value)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.border)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .year)) { _ in
                        AxisValueLabel(format: .dateTime.year())
                            .foregroundStyle(Theme.textTertiary)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.border)
                    }
                }
                .frame(height: 200)
            }
            .padding(16)
            .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var contributorList: some View {
        if contributors.isEmpty {
            Text("No contributor data available.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top Contributors")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 4)

                let maxContrib = contributors.first?.contributions ?? 1
                ForEach(contributors.prefix(20)) { contributor in
                    HStack(spacing: 12) {
                        Text(contributor.login)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 140, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            let pct = CGFloat(contributor.contributions) / CGFloat(max(maxContrib, 1))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.accent.opacity(0.6))
                                .frame(width: geo.size.width * pct, height: 16)
                        }
                        .frame(height: 16)

                        Text("\(contributor.contributions)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "Weekly from \(df.string(from: start)) to \(df.string(from: end))"
    }
}

struct ContributorsView_Previews: PreviewProvider {
    static var previews: some View {
        ContributorsView(repoName: "owner/repo")
            .environmentObject(MonitorData())
    }
}
