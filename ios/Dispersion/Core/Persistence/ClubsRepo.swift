// Port of app/src/db/clubs.ts. CRUD against SwiftData.

import Foundation
import SwiftData

public struct ClubsRepo {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func list() throws -> [Club] {
        let descriptor = FetchDescriptor<ClubModel>(
            sortBy: [SortDescriptor(\.carryYards, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toValue() }
    }

    public func get(id: String) throws -> Club? {
        var d = FetchDescriptor<ClubModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    @discardableResult
    public func create(_ club: Club) throws -> Club {
        try Self.validate(club)
        let model = ClubModel(
            id: club.id,
            name: club.name,
            carryYards: club.carryYards,
            carrySd: club.carrySd,
            lateralSd: club.lateralSd,
            createdAt: club.createdAt,
            updatedAt: club.updatedAt,
            threeQuarter: club.threeQuarter,
            half: club.half
        )
        context.insert(model)
        try context.save()
        return club
    }

    public struct Patch {
        public var name: String?
        public var carryYards: Double?
        public var carrySd: Double?
        public var lateralSd: Double?
        /// Updating a partial-swing profile.
        /// `.some(nil)` clears it; `.some(profile)` writes/replaces; `.none`
        /// leaves it alone.
        public var threeQuarter: SwingProfile??
        public var half: SwingProfile??
        public init(
            name: String? = nil,
            carryYards: Double? = nil,
            carrySd: Double? = nil,
            lateralSd: Double? = nil,
            threeQuarter: SwingProfile?? = nil,
            half: SwingProfile?? = nil
        ) {
            self.name = name
            self.carryYards = carryYards
            self.carrySd = carrySd
            self.lateralSd = lateralSd
            self.threeQuarter = threeQuarter
            self.half = half
        }
    }

    public func update(id: String, patch: Patch) throws {
        try Self.validatePatch(patch)
        var d = FetchDescriptor<ClubModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        guard let model = try context.fetch(d).first else { return }
        if let v = patch.name { model.name = v }
        if let v = patch.carryYards { model.carryYards = v }
        if let v = patch.carrySd { model.carrySd = v }
        if let v = patch.lateralSd { model.lateralSd = v }
        if let tq = patch.threeQuarter {
            model.threeQuarterCarryYards = tq?.carryYards
            model.threeQuarterCarrySd = tq?.carrySd
            model.threeQuarterLateralSd = tq?.lateralSd
            model.threeQuarterSamples = tq?.sampleCount
        }
        if let h = patch.half {
            model.halfCarryYards = h?.carryYards
            model.halfCarrySd = h?.carrySd
            model.halfLateralSd = h?.lateralSd
            model.halfSamples = h?.sampleCount
        }
        model.updatedAt = .now
        try context.save()
    }

    public func delete(id: String) throws {
        // Cascade: remove associated shots and face strikes first
        try ShotsRepo(context: context).deleteByClub(id)
        try FaceStrikesRepo(context: context).deleteByClub(id)

        var d = FetchDescriptor<ClubModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let model = try context.fetch(d).first {
            context.delete(model)
            try context.save()
        }
    }

    public func deleteAll() throws {
        // SwiftData's `context.delete(model:)` bulk-delete API has known
        // reliability issues — silently no-ops in some iOS builds, leaves
        // rows in the persistent store. Explicit fetch + per-row delete
        // is the only path that consistently wipes the table.
        for m in try context.fetch(FetchDescriptor<ClubModel>()) {
            context.delete(m)
        }
        try context.save()
    }

    // MARK: - Validation

    static func validate(_ club: Club) throws {
        let name = club.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw ValidationError.emptyName }
        guard club.carryYards.isFinite, club.carryYards >= 0 else {
            throw ValidationError.invalidCarry(club.carryYards)
        }
        guard club.carrySd.isFinite, club.carrySd >= 0 else {
            throw ValidationError.invalidSigma("carrySd", club.carrySd)
        }
        guard club.lateralSd.isFinite, club.lateralSd >= 0 else {
            throw ValidationError.invalidSigma("lateralSd", club.lateralSd)
        }
    }

    static func validatePatch(_ patch: Patch) throws {
        if let name = patch.name {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.emptyName
            }
        }
        if let v = patch.carryYards {
            guard v.isFinite, v >= 0 else { throw ValidationError.invalidCarry(v) }
        }
        if let v = patch.carrySd {
            guard v.isFinite, v >= 0 else { throw ValidationError.invalidSigma("carrySd", v) }
        }
        if let v = patch.lateralSd {
            guard v.isFinite, v >= 0 else { throw ValidationError.invalidSigma("lateralSd", v) }
        }
    }
}
