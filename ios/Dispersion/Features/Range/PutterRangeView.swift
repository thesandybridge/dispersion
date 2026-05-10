// Putter practice mode. Pick a distance, attempt putts, log makes and
// misses. The session is independent of the live range / round Session
// model — we keep a local sessionId so putts are grouped without
// polluting SessionStore. Save commits the session (putts persist),
// End discards (deletes the session's putts), Undo removes only the
// last putt.

import SwiftData
import SwiftUI

public struct PutterRangeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \PutterModel.createdAt) private var putterModels: [PutterModel]

    public init() {}

    @State private var settings = SettingsStore.shared

    @State private var practiceFeet: Double = 6
    @State private var sessionId: String?
    @State private var sessionPutts: [Putt] = []
    @State private var lastLanding: CGPoint?
    @State private var dragReadout: PuttingGreenField.Tap?
    @State private var endConfirm: Bool = false
    @State private var saveBanner: Bool = false

    private var activePutter: Putter? {
        putterModels.first?.toValue()
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

                    HStack(alignment: .top, spacing: 10) {
                        sessionDotColumn
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
                            if saveBanner {
                                savedBanner
                                    .padding(.top, 12)
                            }
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
            Button("Discard \(sessionPutts.count) putt\(sessionPutts.count == 1 ? "" : "s")", role: .destructive) {
                discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every putt logged in this session. Cannot be undone.")
        }
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

    // MARK: - Session dots

    /// Vertical column of dots tracking each putt this session — newest at
    /// the top, oldest fades out. Made putts fill with accent; misses are
    /// hollow rings.
    private var sessionDotColumn: some View {
        VStack(spacing: 6) {
            // Counter pill
            VStack(spacing: 2) {
                Text("\(sessionPutts.count)")
                    .font(DispersionType.mono(13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.foreground)
                Text("PUTTS")
                    .font(DispersionType.mono(7, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(width: 36)
            .background(ThemedCardFill(cornerRadius: 10))

            if !sessionPutts.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 5) {
                        // Newest at the top; reverse the array.
                        ForEach(Array(sessionPutts.reversed().prefix(40).enumerated()), id: \.element.id) { idx, putt in
                            dot(for: putt, opacity: max(0.35, 1 - Double(idx) * 0.025))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: 36)
                .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(width: 36)
    }

    private func dot(for putt: Putt, opacity: Double) -> some View {
        Group {
            if putt.made {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
            } else {
                Circle()
                    .strokeBorder(DesignTokens.foreground.opacity(0.55), lineWidth: 1.4)
                    .frame(width: 10, height: 10)
            }
        }
        .opacity(opacity)
        .help(putt.made
              ? "Made from \(Int(putt.distanceFeet)) ft"
              : "Missed from \(Int(putt.distanceFeet)) ft \(putt.residualFeet.map { "· \(String(format: "%.1f", $0)) ft left" } ?? "")")
    }

    // MARK: - Toolbar

    private var sessionToolbar: some View {
        HStack(spacing: 8) {
            if !sessionPutts.isEmpty {
                rangePill("arrow.uturn.backward", "Undo") {
                    undoLast()
                }
            }
            if !sessionPutts.isEmpty {
                rangePillTinted("checkmark.circle.fill", "Save", tint: accent) {
                    saveSession()
                }
                rangePillTinted("trash.fill", "End", tint: DesignTokens.destructive) {
                    endConfirm = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionPutts.count)
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

    // MARK: - Drag readout

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

    private var savedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 12, weight: .semibold))
            Text("SESSION SAVED")
                .font(DispersionType.mono(11, weight: .semibold))
                .tracking(1.2)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.black.opacity(0.65))
                .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
        if sessionId == nil {
            // Create a SessionModel so the session shows up in the History
            // tab. SessionStore is intentionally NOT touched — putter
            // practice doesn't compete with the live range / round session.
            let id = UUID().uuidString.lowercased()
            let label = "Putting · \(Date.now.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
            let s = Session(id: id, kind: .putt, label: label, createdAt: .now)
            try? SessionsRepo(context: modelContext).create(s)
            sessionId = id
        }
        let putt = Putt(
            id: UUID().uuidString.lowercased(),
            putterId: putter.id,
            sessionId: sessionId,
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

    /// Save: commit the session. Putts already persist on log; saving just
    /// clears the in-flight session so the user can start fresh. Shows a
    /// brief banner so it doesn't feel like a no-op.
    private func saveSession() {
        sessionId = nil
        sessionPutts = []
        lastLanding = nil
        dragReadout = nil
        Haptics.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            saveBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                saveBanner = false
            }
        }
    }

    /// End: discard the session entirely. Deletes every putt that belongs
    /// to this session id, plus the SessionModel record itself, so the
    /// session disappears from History.
    private func discardSession() {
        if let sid = sessionId {
            for p in sessionPutts {
                try? PuttsRepo(context: modelContext).delete(id: p.id)
            }
            try? SessionsRepo(context: modelContext).delete(id: sid)
        }
        sessionId = nil
        sessionPutts = []
        lastLanding = nil
        dragReadout = nil
        Haptics.medium()
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
