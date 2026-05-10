// CRUD for putters + putts. Putts cascade-delete with their owner putter.

import Foundation
import SwiftData

public struct PuttersRepo {
    public let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func list() throws -> [Putter] {
        let descriptor = FetchDescriptor<PutterModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toValue() }
    }

    public func get(id: String) throws -> Putter? {
        var d = FetchDescriptor<PutterModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    @discardableResult
    public func create(_ putter: Putter) throws -> Putter {
        try Self.validate(putter)
        let model = PutterModel(
            id: putter.id,
            name: putter.name,
            lengthInches: putter.lengthInches,
            headTypeRaw: putter.headType.rawValue,
            loftDegrees: putter.loftDegrees,
            createdAt: putter.createdAt,
            updatedAt: putter.updatedAt
        )
        context.insert(model)
        try context.save()
        return putter
    }

    public struct Patch {
        public var name: String?
        public var lengthInches: Double?
        public var headType: PutterHeadType?
        public var loftDegrees: Double?
        public init(
            name: String? = nil,
            lengthInches: Double? = nil,
            headType: PutterHeadType? = nil,
            loftDegrees: Double? = nil
        ) {
            self.name = name
            self.lengthInches = lengthInches
            self.headType = headType
            self.loftDegrees = loftDegrees
        }
    }

    public func update(id: String, patch: Patch) throws {
        var d = FetchDescriptor<PutterModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        guard let m = try context.fetch(d).first else { return }
        if let v = patch.name {
            let trimmed = v.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { throw ValidationError.emptyName }
            m.name = trimmed
        }
        if let v = patch.lengthInches { m.lengthInches = v }
        if let v = patch.headType { m.headTypeRaw = v.rawValue }
        if let v = patch.loftDegrees { m.loftDegrees = v }
        m.updatedAt = .now
        try context.save()
    }

    public func delete(id: String) throws {
        // Cascade: remove all putts for this putter first.
        try PuttsRepo(context: context).deleteByPutter(id)

        var d = FetchDescriptor<PutterModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let m = try context.fetch(d).first {
            context.delete(m)
            try context.save()
        }
    }

    public func deleteAll() throws {
        for m in try context.fetch(FetchDescriptor<PutterModel>()) {
            context.delete(m)
        }
        try context.save()
    }

    static func validate(_ p: Putter) throws {
        let name = p.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}

public struct PuttsRepo {
    public let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func list(putterId: String, limit: Int? = nil) throws -> [Putt] {
        var d = FetchDescriptor<PuttModel>(
            predicate: #Predicate { $0.putterId == putterId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { d.fetchLimit = limit }
        return try context.fetch(d).map { $0.toValue() }
    }

    public func listAll() throws -> [Putt] {
        let d = FetchDescriptor<PuttModel>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    public func listBySession(_ sessionId: String) throws -> [Putt] {
        let d = FetchDescriptor<PuttModel>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    public func count(putterId: String) throws -> Int {
        let d = FetchDescriptor<PuttModel>(predicate: #Predicate { $0.putterId == putterId })
        return try context.fetchCount(d)
    }

    @discardableResult
    public func create(_ putt: Putt) throws -> Putt {
        let model = PuttModel(
            id: putt.id,
            putterId: putt.putterId,
            sessionId: putt.sessionId,
            distanceFeet: putt.distanceFeet,
            made: putt.made,
            residualFeet: putt.residualFeet,
            landingX: putt.landingX,
            landingY: putt.landingY,
            contextRaw: putt.context.rawValue,
            timestamp: putt.timestamp
        )
        context.insert(model)
        try context.save()
        return putt
    }

    public func delete(id: String) throws {
        var d = FetchDescriptor<PuttModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let m = try context.fetch(d).first {
            context.delete(m)
            try context.save()
        }
    }

    public func deleteByPutter(_ putterId: String) throws {
        let d = FetchDescriptor<PuttModel>(predicate: #Predicate { $0.putterId == putterId })
        let models = try context.fetch(d)
        for m in models { context.delete(m) }
        try context.save()
    }

    public func deleteAll() throws {
        for m in try context.fetch(FetchDescriptor<PuttModel>()) {
            context.delete(m)
        }
        try context.save()
    }
}
