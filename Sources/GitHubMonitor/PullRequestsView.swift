import SwiftUI
import Charts

struct PullRequestsView: View {
    let repoName: String
    @EnvironmentObject private var monitorData: MonitorData
    @EnvironmentObject private var gitHub: GitHubService
    @State private var period: TimePeriod = .monthly

    private var currentStats: RepoPeriodStats? {
        monitorData.stats[repoName]?[period]
    }

    private var chart: GitHubService.ChartData? {
        monitorData.chartData[repoName]?[period]
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            periodPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    prChart
                    prList
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .task(id: period) {
            await monitorData.fetchStatsIfNeeded(repo: repoName, period: period, gitHub: gitHub)
            await monitorData.fetchChartIfNeeded(repo: repoName, period: period, gitHub: gitHub)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pull Requests")
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

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(TimePeriod.allCases) { p in
                PillToggle(title: p.rawValue, isSelected: period == p) { period = p }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var summaryCards: some View {
        let s = currentStats ?? RepoPeriodStats()
        let gridColumns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
        LazyVGrid(columns: gridColumns, spacing: 16) {
            SummaryCard(title: "Created", value: "\(s.prCreated)", icon: "plus.circle")
            SummaryCard(title: "Merged", value: "\(s.prMerged)", icon: "checkmark.circle")
            SummaryCard(title: "Open", value: "\(s.prOpen)", icon: "circle.dashed")
        }
    }

    @ViewBuilder
    private var prChart: some View {
        if let chart, !chart.prCreated.isEmpty {
            let allBuckets = chart.prCreated + chart.prMerged

            VStack(alignment: .leading, spacing: 8) {
                Text("Pull Requests Over Time")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Chart(allBuckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.date, unit: period.chartCalendarUnit),
                        y: .value("Count", bucket.value)
                    )
                    .foregroundStyle(by: .value("Type", bucket.category))
                    .position(by: .value("Type", bucket.category))
                }
                .chartForegroundStyleScale(["Created": Color.blue, "Merged": Color.purple])
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.border)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
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
    private var prList: some View {
        let items = monitorData.recentPRs[repoName] ?? []
        if items.isEmpty {
            Text("No recent pull requests.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 8)

                ForEach(items) { pr in
                    HStack(spacing: 10) {
                        Image(systemName: pr.isMerged ? "checkmark.circle.fill" : pr.isOpen ? "circle" : "xmark.circle")
                            .foregroundStyle(pr.isMerged ? Color.purple : pr.isOpen ? Color.green : Color.red)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text("#\(pr.number) by \(pr.author) · \(formatted(pr.createdAt))")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
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

struct PullRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        PullRequestsView(repoName: "owner/repo")
            .environmentObject(MonitorData())
            .environmentObject(GitHubService())
    }
}
