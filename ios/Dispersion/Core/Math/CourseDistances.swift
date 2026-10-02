import Foundation

struct CourseDistanceStats: Equatable {
    var count: Int
    var median: Double
    var low: Double
    var high: Double

    static func calculate(_ shots: [CourseShot]) -> CourseDistanceStats? {
        let values = shots.filter(\.usableDistance).map(\.distanceYards).sorted()
        guard !values.isEmpty else { return nil }
        func percentile(_ fraction: Double) -> Double {
            let position = fraction * Double(values.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, values.count - 1)
            return values[lower] + (values[upper] - values[lower]) * (position - Double(lower))
        }
        return CourseDistanceStats(count: values.count, median: percentile(0.5), low: percentile(0.2), high: percentile(0.8))
    }
}
