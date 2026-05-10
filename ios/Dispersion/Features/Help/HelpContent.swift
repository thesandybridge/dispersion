// Help / tutorials content. Declarative registry — add a topic by appending
// to `HelpContent.topics`. Sections are plain text + optional inline visuals
// (mini DispersionViz, captioned SF Symbol rows) so the Help UI can render
// without needing per-topic custom views.

import SwiftUI

public struct HelpTopic: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let summary: String
    public let icon: String
    public let sections: [HelpSection]
}

public struct HelpSection: Hashable {
    public let heading: String?
    public let body: String
    public let visual: HelpVisual?

    public init(heading: String? = nil, body: String = "", visual: HelpVisual? = nil) {
        self.heading = heading
        self.body = body
        self.visual = visual
    }
}

public enum HelpVisual: Hashable {
    /// A mini dispersion viz — useful for the math + calculator topics.
    case dispersion(carry: Double, sd: Double, lat: Double, target: Double, width: Double, depth: Double)
    /// SF-symbol icons with captions, laid out in a row. For "what these
    /// glyphs mean" cheat sheets.
    case iconLegend([(icon: String, caption: String)])

    // Hashable conformance — tuples in `iconLegend` need manual handling.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .dispersion(c, s, l, t, w, d):
            hasher.combine(0); hasher.combine(c); hasher.combine(s)
            hasher.combine(l); hasher.combine(t); hasher.combine(w); hasher.combine(d)
        case let .iconLegend(items):
            hasher.combine(1)
            for (icon, caption) in items {
                hasher.combine(icon); hasher.combine(caption)
            }
        }
    }

    public static func == (lhs: HelpVisual, rhs: HelpVisual) -> Bool {
        switch (lhs, rhs) {
        case let (.dispersion(c1, s1, l1, t1, w1, d1), .dispersion(c2, s2, l2, t2, w2, d2)):
            return c1 == c2 && s1 == s2 && l1 == l2 && t1 == t2 && w1 == w2 && d1 == d2
        case let (.iconLegend(a), .iconLegend(b)):
            return a.count == b.count && zip(a, b).allSatisfy { $0.icon == $1.icon && $0.caption == $1.caption }
        default:
            return false
        }
    }
}

public enum HelpContent {

    public static let topics: [HelpTopic] = [
        calculator,
        dispersionMath,
        range,
        courseBuilder,
        playingARound,
        bagAndCalibration,
    ]

    // MARK: - Calculator

    private static let calculator = HelpTopic(
        id: "calculator",
        title: "The calculator",
        summary: "Pick a club, set the distance, see what's most likely to land where you want.",
        icon: "scope",
        sections: [
            HelpSection(
                body: "The calculator's job is to answer one question: which club gives me the highest probability of landing in my safe zone? Everything on the screen is in service of that answer."
            ),
            HelpSection(
                heading: "Set the situation",
                body: "Drag vertically anywhere on the dispersion to change the target distance. Drag horizontally to bias your aim left or right of center — handy when you've got a known dispersion lean. Double-tap to reset aim. The pin pill picks front / middle / back, and the zone preset on the right switches between fairway, lay-up, green, and tight pin."
            ),
            HelpSection(
                heading: "Read the recommendation",
                body: "The big card at the bottom shows the club with the highest probability for your scenario. The dial shows the percentage; the σ values tell you how tight that club's dispersion is. Alternate clubs run along the bottom — tap any of them to see the dispersion overlay swap and a side-by-side breakdown explaining why the recommended club beats it."
            ),
            HelpSection(
                heading: "What to look at",
                visual: .iconLegend([
                    ("circle.fill", "Mean — where the average shot lands"),
                    ("flag.fill", "Pin — what you're aiming AT (greens)"),
                    ("scope", "Aim crosshair — fairway-style targets"),
                    ("circle.dashed", "Probability contours — outermost = far misses"),
                ])
            ),
        ]
    )

    // MARK: - Dispersion math

    private static let dispersionMath = HelpTopic(
        id: "math",
        title: "How the math thinks",
        summary: "σ, probability bands, and the short-side penalty.",
        icon: "function",
        sections: [
            HelpSection(
                body: "Every shot is a point pulled from a 2D distribution: a bell curve along the carry axis (σ↕) and another along the lateral axis (σ↔). The calculator's only job is integrating that distribution over your safe zone and ranking clubs by who has the most of their cloud landing inside it."
            ),
            HelpSection(
                heading: "What σ means",
                body: "σ↕ (sigma long) is one standard deviation of carry distance. About 68% of your shots fall within ±σ of your average carry, and ~95% within ±2σ. So a 7-iron with a 6-yard σ↕ means most shots end up within 6 yards long-or-short of the average carry. σ↔ is the same idea sideways."
            ),
            HelpSection(
                heading: "Live preview",
                body: "Below is a 7-iron's worth of dispersion against a green-sized safe zone. The colored heat shows where shots cluster.",
                visual: .dispersion(carry: 150, sd: 6, lat: 8, target: 150, width: 25, depth: 25)
            ),
            HelpSection(
                heading: "Short-side penalty",
                body: "The recommendation engine penalizes clubs that fall short of the target. A club expected to come up 5 yards short loses about 25% of its raw probability score; 10 yards short loses ~45%. Short of the green is almost always worse than long. You can dial the penalty up or down in Settings → Recommendation."
            ),
        ]
    )

    // MARK: - Range mode

    private static let range = HelpTopic(
        id: "range",
        title: "Range mode",
        summary: "Log practice shots, watch your σ tighten in real time, save calibration when you're confident.",
        icon: "target",
        sections: [
            HelpSection(
                body: "Range mode is where you teach the app your dispersion. Pick a club, set a target, log shots — either by tapping the radar where each shot lands or via Manual entry — and the live stats show your σ updating shot by shot."
            ),
            HelpSection(
                heading: "Logging a shot",
                body: "Tap on the radar where the ball ended up relative to the target. The shot-confirm sheet pops up with the long/lateral readout, swing-type chips (full / 3⁄4 / half), outcome tags (in / short / long / left / right / penalty), and a club-face strike pad. Tag what you can — the more metadata, the better the analytics get later."
            ),
            HelpSection(
                heading: "Watching σ live",
                body: "The session stats strip across the top of every shot-confirm sheet shows shots-this-session, current σ↕, and σ↔, with arrows that show how the shot you just hit moved each metric. Down arrow = tightening, up arrow = loosening. Personal-best banners fire when this shot crowns a session-best."
            ),
            HelpSection(
                heading: "Saving calibration",
                body: "Once you've logged enough shots, the Save button in the toolbar opens the calibration sheet. It shows confidence-rated sample size (need ≥10 for 'Good', ≥30 for 'High'), side-by-side stored vs measured ellipses, and a numeric diff. Saving overwrites the club's stored carry / σ↕ / σ↔ with the measured values."
            ),
            HelpSection(
                heading: "Toolbar",
                visual: .iconLegend([
                    ("arrow.triangle.2.circlepath", "Switch club"),
                    ("scope", "Set target distance"),
                    ("pencil", "Manual shot entry"),
                    ("arrow.uturn.backward", "Undo last shot"),
                    ("square.and.arrow.down", "Save calibration"),
                    ("stop.circle.fill", "End session"),
                ])
            ),
        ]
    )

    // MARK: - Course builder

    private static let courseBuilder = HelpTopic(
        id: "course-builder",
        title: "Course builder",
        summary: "Trace tees, pins, fairways and greens on satellite imagery.",
        icon: "map",
        sections: [
            HelpSection(
                body: "The course builder lets you turn any course on Earth into a playable map. Add a course by name, then walk through each hole placing tee boxes, pin positions, and tracing the playable surfaces."
            ),
            HelpSection(
                heading: "The flow per hole",
                body: "Each hole has three steps shown as the Tees / Pins / Draw pills under the header: (1) drop tee boxes for as many tee colors as you want, (2) place pin positions for front / middle / back, (3) trace the fairway, green, bunkers, and water polygons. Move between holes with the chevrons in the hole nav pill."
            ),
            HelpSection(
                heading: "Auto fill vs manual draw",
                body: "While drawing, the Auto / Manual pill above the bottom toolbar toggles between two modes. Auto uses Apple's place-recognition to flood-fill regions of similar terrain — usually best for clean, well-defined fairways. Manual lets you tap to drop polygon vertices yourself — better for hand-shaping greens, irregular bunkers, or tight tee corridors."
            ),
            HelpSection(
                heading: "Map controls",
                visual: .iconLegend([
                    ("checkmark", "Done — saves and exits"),
                    ("list.number", "Edit scorecard (par, yardage, handicap)"),
                    ("chevron.left", "Previous hole"),
                    ("chevron.right", "Next hole"),
                    ("wand.and.stars", "Auto fill from satellite"),
                    ("pencil.tip", "Manual polygon draw"),
                    ("view.3d", "3D / 2D map toggle"),
                ])
            ),
            HelpSection(
                heading: "Editing existing polygons",
                body: "Tap any drawn polygon to select it. The active polygon shows its vertex handles; drag a handle to reshape, or hit Undo to step back. Long-press a polygon to delete it."
            ),
        ]
    )

    // MARK: - Playing a round

    private static let playingARound = HelpTopic(
        id: "play",
        title: "Playing a round",
        summary: "GPS shot tracking, smart club picks, hole-by-hole scoring.",
        icon: "flag.2.crossed",
        sections: [
            HelpSection(
                body: "Tap a course in the Course tab to start a round. The app picks the longest tee shot club by default at par 4/5 tees, then auto-suggests clubs as you walk in based on remaining distance."
            ),
            HelpSection(
                heading: "Logging a shot on course",
                body: "Drag the map crosshair to where your ball landed, then tap Log shot. The club picker opens with your recommended club preselected — one tap confirms. Or use the GPS button to capture your current location instead. Non-dispersion shots (drops, chips, punches, sand recoveries) don't count toward your stored σ stats."
            ),
            HelpSection(
                heading: "Scoring",
                body: "When the ball ends up on the green, the bottom panel switches to putting mode — increment putts, then Finish hole opens the score editor. FIR / GIR / Up & Down toggles let you tag situational outcomes. Penalty strokes have their own +1 button."
            ),
            HelpSection(
                heading: "Strokes gained",
                body: "After saving a round, the post-round summary computes Strokes Gained per shot using Broadie's tour baseline. SG positive = better than tour expectation from that distance; negative = worse. The Round History tab graphs SG over time so you can see if your scoring is genuinely improving."
            ),
        ]
    )

    // MARK: - Bag & calibration

    private static let bagAndCalibration = HelpTopic(
        id: "bag",
        title: "Bag & calibration",
        summary: "What σ values to start with, when to update them, the bag tag.",
        icon: "bag",
        sections: [
            HelpSection(
                body: "Each club in your bag has a stored carry, σ↕, and σ↔. The calculator uses those to model the club's dispersion. The honest truth: you start with educated guesses and tighten them up as you log range shots."
            ),
            HelpSection(
                heading: "Reasonable starting σ",
                body: "If you have no real data: σ↕ ≈ 4–8 yards for irons (lower number = more consistent striker), σ↔ ≈ 5–10. Wedges trend tighter; driver is usually 8–14 / 12–18. Don't agonize — just put in something plausible and let Range mode dial it in."
            ),
            HelpSection(
                heading: "When to recalibrate",
                body: "If the calculator's recommendations feel wrong (consistently coming up short, missing right when the math says you should be centered), it's a calibration drift. Log 10–20 shots in Range mode with the offending club, then save calibration. The sigma-tightening insight in your bag will tell you when a club's stored σ is meaningfully off from recent data."
            ),
            HelpSection(
                heading: "The bag tag",
                body: "The tag icon in the Bag header opens a 3D bag tag with your name, accent, and motto rendered onto a real metallic-feeling card. Spin to see the back, tap a finish (silver / black / gold / rose gold) to swap materials. Share via the action button — exports the front face as an image."
            ),
        ]
    )
}
