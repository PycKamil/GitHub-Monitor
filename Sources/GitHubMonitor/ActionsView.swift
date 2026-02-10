import SwiftUI
import Charts

struct ActionsView: View {
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
                    actionsChart
                    runList
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
                Text("Actions")
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
            SummaryCard(title: "Total Runs", value: "\(s.actionsTotal)", icon: "play.circle")
            SummaryCard(title: "Succeeded", value: "\(s.actionsSucceeded)", icon: "checkmark.circle")
            SummaryCard(title: "Failed", value: "\(s.actionsFailed)", icon: "xmark.circle")
            SummaryCard(title: "Failure Rate", value: s.actionsFailureRate, icon: "chart.bar")
        }
    }

    @ViewBuilder
    private var actionsChart: some View {
        if let chart, !chart.actionsSucceeded.isEmpty {
            let allBuckets = chart.actionsSucceeded + chart.actionsFailed

            VStack(alignment: .leading, spacing: 8) {
                Text("Actions Over Time")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Chart(allBuckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.date, unit: period.chartCalendarUnit),
                        y: .value("Count", bucket.value)
                    )
                    .foregroundStyle(by: .value("Status", bucket.category))
                }
                .chartForegroundStyleScale(["Succeeded": Color.green, "Failed": Color.red])
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.border)
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
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
    private var runList: some View {
        let items = monitorData.recentRuns[repoName] ?? []
        if items.isEmpty {
            Text("No recent action runs.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Runs")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 8)

                ForEach(items) { run in
                    HStack(spacing: 10) {
                        Image(systemName: run.isSuccess ? "checkmark.circle.fill" : run.isFailure ? "xmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(run.isSuccess ? Color.green : run.isFailure ? Color.red : Color.orange)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(run.name)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text("\(run.conclusion.isEmpty ? run.status : run.conclusion) · \(formatted(run.createdAt))")
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

struct ActionsView_Previews: PreviewProvider {
    static var previews: some View {
        ActionsView(repoName: "owner/repo")
            .environmentObject(MonitorData())
            .environmentObject(GitHubService())
    }
}
