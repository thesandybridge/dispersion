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
        let model = ClubModel(
            id: club.id,
            name: club.name,
            carryYards: club.carryYards,
            carrySd: club.carrySd,
            lateralSd: club.lateralSd,
            createdAt: club.createdAt,
            updatedAt: club.updatedAt
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

        public init(
            name: String? = nil,
            carryYards: Double? = nil,
            carrySd: Double? = nil,
            lateralSd: Double? = nil
        ) {
            self.name = name
            self.carryYards = carryYards
            self.carrySd = carrySd
            self.lateralSd = lateralSd
        }
    }

    public func update(id: String, patch: Patch) throws {
        var d = FetchDescriptor<ClubModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        guard let model = try context.fetch(d).first else { return }
        if let v = patch.name { model.name = v }
        if let v = patch.carryYards { model.carryYards = v }
        if let v = patch.carrySd { model.carrySd = v }
        if let v = patch.lateralSd { model.lateralSd = v }
        model.updatedAt = .now
        try context.save()
    }

    public func delete(id: String) throws {
        var d = FetchDescriptor<ClubModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let model = try context.fetch(d).first {
            context.delete(model)
            try context.save()
        }
    }

    public func deleteAll() throws {
        try context.delete(model: ClubModel.self)
        try context.save()
    }
}
