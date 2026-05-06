// Port of app/src/db/faceStrikes.ts.

import Foundation
import SwiftData

public struct FaceStrikesRepo {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func listByClub(_ clubId: String) throws -> [FaceStrike] {
        let d = FetchDescriptor<FaceStrikeModel>(
            predicate: #Predicate { $0.clubId == clubId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    @discardableResult
    public func create(_ strike: FaceStrike) throws -> FaceStrike {
        let model = FaceStrikeModel(
            id: strike.id,
            clubId: strike.clubId,
            x: strike.x,
            y: strike.y,
            timestamp: strike.timestamp
        )
        context.insert(model)
        try context.save()
        return strike
    }

    public func delete(id: String) throws {
        var d = FetchDescriptor<FaceStrikeModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let model = try context.fetch(d).first {
            context.delete(model)
            try context.save()
        }
    }
}
