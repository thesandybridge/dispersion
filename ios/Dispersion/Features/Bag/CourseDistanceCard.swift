import SwiftData
import SwiftUI

struct CourseDistanceCard: View {
    @Environment(\.modelContext) private var context
    @Environment(\.themeAccent) private var accent
    @Query private var storedShots: [CourseShotModel]
    var club: Club
    @State private var history = false

    private var shots: [CourseShot] { storedShots.filter { $0.clubId == club.id }.map { $0.toValue() } }
    private func distance(_ yards: Double) -> String {
        "\(Int(Units.from(yards: yards, in: SettingsStore.shared.unit).rounded()))"
    }

    var body: some View {
        Button { history = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("On-course distance").eyebrow(color: accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                if let stats = CourseDistanceStats.calculate(shots) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(distance(stats.median)).font(DispersionType.display(36))
                        Text("\(SettingsStore.shared.unit.label) median total").font(.subheadline)
                    }
                    Text("Typical: \(distance(stats.low))–\(distance(stats.high)) \(SettingsStore.shared.unit.label) · \(stats.count) full shots")
                        .font(.subheadline)
                    if stats.count < 5 { Text("Early estimate — keep tracking.").font(.caption) }
                } else {
                    Text("Learn this club on the course").font(.headline)
                    Text("Track full shots on your Watch or iPhone to see your typical total distance.").font(.subheadline)
                }
                Text("Includes roll. Separate from your carry calibration. Typical range is the middle 60% of eligible shots.")
                    .font(.caption).foregroundStyle(DesignTokens.mutedForeground)
            }
            .foregroundStyle(DesignTokens.foreground)
            .padding(18)
            .background(ThemedCardFill())
        }
        .buttonStyle(.plain)
        .dispersionSheet(isPresented: $history, detents: [.large], scrollable: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(club.name) on course").font(DispersionType.display(28))
                    Text("Exclude chips, recovery shots and unreliable locations. Excluding a distance does not remove the shot or change your score.")
                        .font(.subheadline).foregroundStyle(DesignTokens.mutedForeground)
                    ForEach(shots.sorted { $0.timestamp > $1.timestamp }) { shot in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(distance(shot.distanceYards)) \(SettingsStore.shared.unit.label)").font(.headline)
                                Spacer()
                                Text(shot.timestamp, style: .date).font(.caption)
                            }
                            Text("Hole \(shot.holeNumber) · \(shot.kind ?? "full") · GPS ±\(Int(shot.accuracy)) m")
                                .font(.caption).foregroundStyle(DesignTokens.mutedForeground)
                            Toggle("Exclude from distances", isOn: Binding(
                                get: { shot.excludedFromDistances == true },
                                set: { excluded in
                                    var updated = shot
                                    updated.excludedFromDistances = excluded
                                    do { try CoursesRepo(context: context).updateShot(updated) }
                                    catch { errorMessage = error.localizedDescription }
                                }
                            ))
                            if !shot.usableDistance && shot.excludedFromDistances != true {
                                Text("Not a full measured shot, or outside the GPS/distance limits.").font(.caption)
                            }
                        }.padding(14).background(ThemedCardFill())
                    }
                    if shots.isEmpty { Text("No recorded course shots yet.").padding(.vertical) }
                    if let errorMessage { Text(errorMessage).foregroundStyle(DesignTokens.destructive) }
                }.padding()
            }
        }
    }

    @State private var errorMessage: String?
}
