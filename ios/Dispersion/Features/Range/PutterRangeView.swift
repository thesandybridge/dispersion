// Putter practice mode. Pick a distance, attempt putts, log makes and
// misses. Live session stats track make % at this distance and average
// lag proximity. Plays nicely against the PuttingGreenField — tap on the
// green to log where the ball stopped (cup-area = make).

import SwiftData
import SwiftUI

public struct PutterRangeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \PutterModel.createdAt) private var putterModels: [PutterModel]
    @Query(sort: \SessionModel.createdAt, order: .reverse) private var sessionModels: [SessionModel]

    public init() {}

    @State private var settings = SettingsStore.shared
    @State private var session = SessionStore.shared

    @State private var practiceFeet: Double = 6
    @State private var sessionPutts: [Putt] = []
    @State private var lastLanding: CGPoint?
    @State private var dragReadout: PuttingGreenField.Tap?
    @State private var pendingMiss: PuttingGreenField.Tap?
    @State private var endConfirm: Bool = false

    private var activePutter: Putter? {
        putterModels.first?.toValue()
    }

    private var sessionId: String? {
        if let s = session.active, s.kind == .range { return s.id }
        return nil
    }

    private var stats: SessionPuttStats {
        SessionPuttStats.compute(sessionPutts, practiceFeet: practiceFeet)
    }

    private static let presetDistances: [Double] = [2, 3, 5, 8, 10, 15, 20, 30]

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            if activePutter != nil {
                VStack(spacing: 12) {
                    distancePicker
                    statsCard
                    PuttingGreenField(
                        practiceDistanceFeet: practiceFeet,
                        lastLandingFeet: lastLanding,
                        onLog: { tap in handleTap(tap) },
                        onDrag: { tap in dragReadout = tap }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1)
                    )
                    .overlay(alignment: .top) {
                        if let r = dragReadout {
                            dragReadoutBadge(r)
                                .padding(.top, 12)
                        }
                    }
                    sessionToolbar
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 12)
            } else {
                noPutterState
            }
        }
        .alert("End putting session?", isPresented: $endConfirm) {
            Button("End session", role: .destructive) {
                if sessionPutts.isEmpty, let id = sessionId {
                    try? SessionsRepo(context: modelContext).delete(id: id)
                }
                session.clear()
                sessionPutts = []
                lastLanding = nil
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sessionPutts.isEmpty
                 ? "No putts to keep."
                 : "\(sessionPutts.count) putt\(sessionPutts.count == 1 ? "" : "s") stay logged.")
        }
        .onAppear { reload() }
    }

    // MARK: - Distance picker

    private var distancePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.presetDistances, id: \.self) { d in
                    Button {
                        practiceFeet = d
                        Haptics.light()
                    } label: {
                        Text("\(Int(d)) ft")
                            .font(DispersionType.mono(12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(practiceFeet == d ? DesignTokens.primaryForeground : DesignTokens.foreground)
                            .background(
                                Capsule().fill(practiceFeet == d
                                               ? accent
                                               : DesignTokens.surface)
                            )
                            .overlay(
                                Capsule().strokeBorder(practiceFeet == d
                                                       ? Color.clear
                                                       : DesignTokens.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCol("This distance", "\(stats.makesAtDistance)/\(stats.attemptsAtDistance)")
            DSeparator(.vertical).frame(height: 32)
            statCol("Make %", stats.attemptsAtDistance > 0
                    ? "\(Int((stats.makePctAtDistance * 100).rounded()))%"
                    : "—")
            DSeparator(.vertical).frame(height: 32)
            statCol("Avg lag", stats.avgLag.map { String(format: "%.1f ft", $0) } ?? "—")
            DSeparator(.vertical).frame(height: 32)
            statCol("Session", "\(stats.totalPutts)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    private func statCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label.uppercased())
                .font(DispersionType.mono(8, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(DesignTokens.foreground.opacity(0.45))
            Text(value)
                .font(DispersionType.display(18, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar

    private var sessionToolbar: some View {
        HStack(spacing: 8) {
            if let last = sessionPutts.last {
                rangePill("arrow.uturn.backward", "Undo last \(last.made ? "make" : "miss")") {
                    undoLast()
                }
            }
            if !sessionPutts.isEmpty {
                rangePillTinted("stop.circle.fill", "End", tint: DesignTokens.destructive) {
                    endConfirm = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private func rangePill(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.light() } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(DispersionType.mono(11, weight: .medium))
            }
            .floatingPillStyle()
        }
        .buttonStyle(.plain)
    }

    private func rangePillTinted(_ icon: String, _ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.light() } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(DispersionType.mono(11, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignTokens.popover.opacity(0.92))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drag readout badge

    /// Floating capsule that shows live "made / X.X ft" while the finger is
    /// down. Same idiom as the range's drag-readout — gives the user
    /// confidence about exactly where they're going to log before they
    /// release.
    private func dragReadoutBadge(_ tap: PuttingGreenField.Tap) -> some View {
        let label: String
        let tint: Color
        if tap.made {
            label = "MADE"
            tint = accent
        } else {
            label = String(format: "%.1f ft", tap.residualFeet)
            tint = DesignTokens.foreground
        }
        return HStack(spacing: 6) {
            Image(systemName: tap.made ? "checkmark.circle.fill" : "ruler")
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(DispersionType.mono(13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.65))
                .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: tap.made)
    }

    // MARK: - Empty state

    private var noPutterState: some View {
        VStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 32))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
            Text("Add a putter first")
                .font(DispersionType.display(24, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Putters live separately from your other clubs. Add one in the Bag to start logging putts here.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func handleTap(_ tap: PuttingGreenField.Tap) {
        guard let putter = activePutter else { return }
        let sid = ensureSession()
        let putt = Putt(
            id: UUID().uuidString.lowercased(),
            putterId: putter.id,
            sessionId: sid,
            distanceFeet: practiceFeet,
            made: tap.made,
            residualFeet: tap.made ? nil : tap.residualFeet,
            landingX: tap.x,
            landingY: tap.y,
            context: .practice,
            timestamp: .now
        )
        do {
            try PuttsRepo(context: modelContext).create(putt)
            sessionPutts.append(putt)
            lastLanding = CGPoint(x: tap.x, y: tap.y)
            tap.made ? Haptics.success() : Haptics.light()
        } catch {
            Haptics.error()
        }
    }

    private func undoLast() {
        guard let last = sessionPutts.popLast() else { return }
        try? PuttsRepo(context: modelContext).delete(id: last.id)
        lastLanding = sessionPutts.last.flatMap { p in
            guard let x = p.landingX, let y = p.landingY else { return nil }
            return CGPoint(x: x, y: y)
        }
        Haptics.medium()
    }

    private func ensureSession() -> String {
        if let id = sessionId { return id }
        let id = UUID().uuidString.lowercased()
        let label = "Putting · \(Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
        let s = Session(id: id, kind: .range, label: label, createdAt: .now)
        do {
            try SessionsRepo(context: modelContext).create(s)
            session.setActive(ActiveSession(id: id, kind: .range, label: label))
        } catch {
            Haptics.error()
        }
        return id
    }

    private func reload() {
        if let sid = sessionId {
            let raw = (try? PuttsRepo(context: modelContext).listBySession(sid)) ?? []
            sessionPutts = raw
            if let last = raw.last, let x = last.landingX, let y = last.landingY {
                lastLanding = CGPoint(x: x, y: y)
            }
        }
    }
}

// MARK: - Session-scope stats

struct SessionPuttStats {
    var totalPutts: Int
    var attemptsAtDistance: Int
    var makesAtDistance: Int
    var makePctAtDistance: Double
    var avgLag: Double?

    static func compute(_ putts: [Putt], practiceFeet: Double) -> SessionPuttStats {
        let atDistance = putts.filter { abs($0.distanceFeet - practiceFeet) < 0.01 }
        let makes = atDistance.filter { $0.made }.count
        let attempts = atDistance.count
        let pct = attempts > 0 ? Double(makes) / Double(attempts) : 0
        let residuals = putts.filter { !$0.made }.compactMap { $0.residualFeet }
        let avg: Double? = residuals.isEmpty
            ? nil
            : residuals.reduce(0, +) / Double(residuals.count)
        return SessionPuttStats(
            totalPutts: putts.count,
            attemptsAtDistance: attempts,
            makesAtDistance: makes,
            makePctAtDistance: pct,
            avgLag: avg
        )
    }
}
