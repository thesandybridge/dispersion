// Port of app/src/db/shots.ts and app/src/db/shotsAll.ts.

import Foundation
import SwiftData

public struct ShotsRepo {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func listBySession(_ sessionId: String) throws -> [Shot] {
        let d = FetchDescriptor<ShotModel>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    public func listByClub(_ clubId: String, limit: Int? = nil) throws -> [Shot] {
        var d = FetchDescriptor<ShotModel>(
            predicate: #Predicate { $0.clubId == clubId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { d.fetchLimit = limit }
        return try context.fetch(d).map { $0.toValue() }
    }

    public func listAll(limit: Int? = nil) throws -> [Shot] {
        var d = FetchDescriptor<ShotModel>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { d.fetchLimit = limit }
        return try context.fetch(d).map { $0.toValue() }
    }

    public func count(since date: Date) throws -> Int {
        let d = FetchDescriptor<ShotModel>(
            predicate: #Predicate { $0.timestamp >= date }
        )
        return try context.fetchCount(d)
    }

    @discardableResult
    public func create(_ shot: Shot) throws -> Shot {
        guard shot.targetDistanceYards.isFinite, shot.targetDistanceYards > 0 else {
            throw ValidationError.invalidDistance(shot.targetDistanceYards)
        }
        guard shot.longDelta.isFinite else {
            throw ValidationError.invalidDelta("longDelta", shot.longDelta)
        }
        guard shot.latDelta.isFinite else {
            throw ValidationError.invalidDelta("latDelta", shot.latDelta)
        }
        let model = ShotModel(
            id: shot.id,
            sessionId: shot.sessionId,
            clubId: shot.clubId,
            targetDistanceYards: shot.targetDistanceYards,
            longDelta: shot.longDelta,
            latDelta: shot.latDelta,
            outcomeRaw: Outcomes.encode(shot.outcomes),
            timestamp: shot.timestamp
        )
        context.insert(model)
        try context.save()
        return shot
    }

    public func delete(id: String) throws {
        let d = FetchDescriptor<ShotModel>(predicate: #Predicate { $0.id == id })
        for model in try context.fetch(d) {
            context.delete(model)
        }
        try context.save()
    }

    public func deleteBySession(_ sessionId: String) throws {
        let d = FetchDescriptor<ShotModel>(predicate: #Predicate { $0.sessionId == sessionId })
        for model in try context.fetch(d) {
            context.delete(model)
        }
        try context.save()
    }

    public func deleteByClub(_ clubId: String) throws {
        let d = FetchDescriptor<ShotModel>(predicate: #Predicate { $0.clubId == clubId })
        for model in try context.fetch(d) {
            context.delete(model)
        }
        try context.save()
    }

    public func countAll() throws -> Int {
        try context.fetchCount(FetchDescriptor<ShotModel>())
    }

    public func deleteAll() throws {
        try context.delete(model: ShotModel.self)
        try context.save()
    }
}
