// Port of app/src/db/sessions.ts.

import Foundation
import SwiftData

public struct SessionsRepo {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func list(limit: Int = 200) throws -> [Session] {
        var d = FetchDescriptor<SessionModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        d.fetchLimit = limit
        return try context.fetch(d).map { $0.toValue() }
    }

    public func get(id: String) throws -> Session? {
        var d = FetchDescriptor<SessionModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    @discardableResult
    public func create(_ session: Session) throws -> Session {
        let model = SessionModel(
            id: session.id,
            kindRaw: session.kind.rawValue,
            label: session.label,
            createdAt: session.createdAt
        )
        context.insert(model)
        try context.save()
        return session
    }

    public func delete(id: String) throws {
        let d = FetchDescriptor<SessionModel>(predicate: #Predicate { $0.id == id })
        for model in try context.fetch(d) {
            context.delete(model)
        }
        try context.save()
    }

    public func deleteAll() throws {
        for m in try context.fetch(FetchDescriptor<SessionModel>()) {
            context.delete(m)
        }
        try context.save()
    }
}
