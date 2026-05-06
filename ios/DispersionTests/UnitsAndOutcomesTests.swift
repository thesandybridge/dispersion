import Testing
import Foundation
@testable import Dispersion

@Suite("Units")
struct UnitsTests {
    @Test("yards round-trip preserves value")
    func yardsIdentity() {
        let y = 165.5
        #expect(Units.from(yards: y, in: .yards) == y)
        #expect(Units.toYards(y, from: .yards) == y)
    }

    @Test("meters conversion is symmetric")
    func metersSymmetry() {
        let yards = 200.0
        let meters = Units.from(yards: yards, in: .meters)
        let back = Units.toYards(meters, from: .meters)
        #expect(abs(back - yards) < 1e-9)
    }
}

@Suite("Outcomes")
struct OutcomesTests {
    @Test("toggle 'in' clears directional misses")
    func inExclusive() {
        let next = Outcomes.toggle(in: [.long, .right], tag: .in)
        #expect(next == [.in])
    }

    @Test("adding directional miss removes 'in'")
    func directionalClearsIn() {
        let next = Outcomes.toggle(in: [.in], tag: .long)
        #expect(next == [.long])
    }

    @Test("long ↔ short are mutually exclusive")
    func longShortExclusive() {
        let next = Outcomes.toggle(in: [.short, .right], tag: .long)
        #expect(next == [.long, .right])
    }

    @Test("encode/decode round trip")
    func encodeDecode() {
        let original: Set<ShotOutcomeTag> = [.long, .right, .penalty]
        let encoded = Outcomes.encode(original)
        #expect(Outcomes.decode(encoded) == original)
    }
}

@Suite("ClubCategory")
struct CategoryTests {
    @Test("driver name → driver category")
    func driverByName() {
        #expect(ClubCategoryRegistry.categorize(name: "Driver", carryYards: 100) == .driver)
    }

    @Test("falls back to carry distance when name is generic")
    func carryFallback() {
        // No matching pattern → uses carry-based fallback
        #expect(ClubCategoryRegistry.categorize(name: "Mystery Club", carryYards: 270) == .driver)
        #expect(ClubCategoryRegistry.categorize(name: "Mystery Club", carryYards: 80) == .wedge)
    }

    @Test("wedge variants all categorize as wedge")
    func wedgeVariants() {
        for n in ["Pitching Wedge", "PW", "Lob Wedge", "SW", "GW"] {
            #expect(ClubCategoryRegistry.categorize(name: n, carryYards: 110) == .wedge)
        }
    }
}
