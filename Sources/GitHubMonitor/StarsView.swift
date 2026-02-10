import SwiftUI
import Charts

@MainActor
struct StarsView: View {
    let repoName: String
    @EnvironmentObject private var monitorData: MonitorData
    @EnvironmentObject private var gitHub: GitHubService
    @State private var isLoadingStars = false

    private var starData: [StarDataPoint] {
        monitorData.starHistory[repoName] ?? []
    }

    private var totalStars: Int {
        starData.last?.cumulativeCount ?? 0
    }

    var body: some View {
        VStack(spacing: 24) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    cumulativeChart
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .task {
            isLoadingStars = true
            await monitorData.fetchStarHistoryIfNeeded(repo: repoName, gitHub: gitHub)
            isLoadingStars = false
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stars")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(repoName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if isLoadingStars { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var summaryCards: some View {
        let recentGrowth = recentMonthlyGrowth()

        let gridColumns = [GridItem(.adaptive(minimum: 180), spacing: 16)]
        LazyVGrid(columns: gridColumns, spacing: 16) {
            SummaryCard(title: "Total Stars", value: formatNumber(totalStars), icon: "star.fill")
            SummaryCard(title: "First Starred", value: firstStarDate(), icon: "calendar")
            SummaryCard(title: "Last Month", value: "+\(formatNumber(recentGrowth))", icon: "arrow.up.right")
            SummaryCard(title: "Avg/Month", value: formatNumber(averageMonthlyStars()), icon: "chart.line.uptrend.xyaxis")
        }
    }

    @ViewBuilder
    private var cumulativeChart: some View {
        if starData.isEmpty && !isLoadingStars {
            Text("No star data available.")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)
        } else if !starData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cumulative Stars Over Time")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(chartSubtitle())
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)

                Chart(starData) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Stars", point.cumulativeCount)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.yellow.opacity(0.4), Color.yellow.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Stars", point.cumulativeCount)
                    )
                    .foregroundStyle(Color.yellow)
                    .lineStyle(StrokeStyle(lineWidth: 2))
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
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.year())
                            .foregroundStyle(Theme.textTertiary)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.border)
                    }
                }
                .frame(height: 250)
            }
            .padding(16)
            .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

            monthlyGrowthChart
        }
    }

    @ViewBuilder
    private var monthlyGrowthChart: some View {
        let growth = monthlyGrowthData()
        if growth.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Star Growth")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                Chart(growth) { bucket in
                    BarMark(
                        x: .value("Month", bucket.date, unit: .month),
                        y: .value("New Stars", bucket.value)
                    )
                    .foregroundStyle(Color.orange.gradient)
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
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.year().month(.abbreviated))
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

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    private func firstStarDate() -> String {
        guard let first = starData.first else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df.string(from: first.date)
    }

    private func chartSubtitle() -> String {
        guard let first = starData.first, let last = starData.last else { return "" }
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: first.date)) — \(df.string(from: last.date))"
    }

    private func recentMonthlyGrowth() -> Int {
        guard starData.count >= 2 else { return 0 }
        let last = starData[starData.count - 1].cumulativeCount
        let prev = starData[starData.count - 2].cumulativeCount
        return last - prev
    }

    private func averageMonthlyStars() -> Int {
        guard starData.count >= 2 else { return 0 }
        return totalStars / max(starData.count, 1)
    }

    private func monthlyGrowthData() -> [ChartBucket] {
        guard starData.count >= 2 else { return [] }
        var result: [ChartBucket] = []
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        for i in 1..<starData.count {
            let growth = starData[i].cumulativeCount - starData[i - 1].cumulativeCount
            result.append(ChartBucket(
                date: starData[i].date,
                label: df.string(from: starData[i].date),
                value: growth,
                category: "New Stars"
            ))
        }
        return result
    }
}

struct StarsView_Previews: PreviewProvider {
    static var previews: some View {
        StarsView(repoName: "owner/repo")
            .environmentObject(MonitorData())
            .environmentObject(GitHubService())
    }
}
