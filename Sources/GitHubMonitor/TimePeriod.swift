import Foundation

enum TimePeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }

    var chartCalendarUnit: Calendar.Component {
        switch self {
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }

    var dateFormat: String {
        switch self {
        case .weekly: return "MMM d"
        case .monthly: return "MMM yyyy"
        case .yearly: return "yyyy"
        }
    }

    func startDate(from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: -12, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: -12, to: now) ?? now
        case .yearly:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }

    func bucketLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    func bucketKey(for date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: comps) ?? date
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? date
        case .yearly:
            let comps = calendar.dateComponents([.year], from: date)
            return calendar.date(from: comps) ?? date
        }
    }

    /// Returns date ranges for each bucket in the period
    func dateBuckets(from now: Date = Date()) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let start = startDate(from: now)
        var buckets: [(start: Date, end: Date)] = []
        var current = bucketKey(for: start)

        while current <= now {
            let next: Date
            switch self {
            case .weekly:
                next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
            case .monthly:
                next = calendar.date(byAdding: .month, value: 1, to: current) ?? current
            case .yearly:
                next = calendar.date(byAdding: .year, value: 1, to: current) ?? current
            }
            let end = min(calendar.date(byAdding: .day, value: -1, to: next) ?? current, now)
            buckets.append((start: current, end: end))
            current = next
        }
        return buckets
    }
}
