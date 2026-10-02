// CRUD for courses, polygons, and course shots.

import Foundation
import SwiftData

public struct CoursesRepo {
    public let context: ModelContext

    // MARK: - Courses

    public func list() throws -> [Course] {
        let d = FetchDescriptor<CourseModel>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(d).map { $0.toValue() }
    }

    public func get(id: String) throws -> Course? {
        var d = FetchDescriptor<CourseModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    @discardableResult
    public func createCourse(_ course: Course) throws -> Course {
        let model = CourseModel(
            id: course.id, name: course.name,
            centerLat: course.centerLat, centerLng: course.centerLng,
            holeCount: course.holeCount, fetchedAt: course.fetchedAt
        )
        context.insert(model)
        try context.save()
        return course
    }

    public func deleteCourse(id: String) throws {
        let d = FetchDescriptor<CourseModel>(predicate: #Predicate { $0.id == id })
        for m in try context.fetch(d) { context.delete(m) }
        // Cascade: delete polygons, hole infos, and shots
        let pd = FetchDescriptor<PolygonModel>(predicate: #Predicate { $0.courseId == id })
        for m in try context.fetch(pd) { context.delete(m) }
        let hd = FetchDescriptor<HoleInfoModel>(predicate: #Predicate { $0.courseId == id })
        for m in try context.fetch(hd) { context.delete(m) }
        let sd = FetchDescriptor<CourseShotModel>(predicate: #Predicate { $0.courseId == id })
        for m in try context.fetch(sd) { context.delete(m) }
        try context.save()
    }

    // MARK: - Hole info

    public func holeInfos(courseId: String) throws -> [HoleInfo] {
        let d = FetchDescriptor<HoleInfoModel>(
            predicate: #Predicate { $0.courseId == courseId },
            sortBy: [SortDescriptor(\.holeNumber)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    public func holeInfo(courseId: String, hole: Int) throws -> HoleInfo? {
        var d = FetchDescriptor<HoleInfoModel>(
            predicate: #Predicate { $0.courseId == courseId && $0.holeNumber == hole }
        )
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    public func upsertHoleInfo(_ info: HoleInfo) throws {
        let teeData = try? JSONEncoder().encode(info.teeBoxes)
        let pinData = try? JSONEncoder().encode(info.pinPositions)

        var d = FetchDescriptor<HoleInfoModel>(predicate: #Predicate { $0.id == info.id })
        d.fetchLimit = 1
        if let existing = try context.fetch(d).first {
            existing.par = info.par
            existing.handicap = info.handicap
            existing.teeBoxesJSON = teeData
            existing.pinPositionsJSON = pinData
        } else {
            let model = HoleInfoModel(
                id: info.id, courseId: info.courseId, holeNumber: info.holeNumber,
                par: info.par, handicap: info.handicap,
                teeBoxesJSON: teeData, pinPositionsJSON: pinData
            )
            context.insert(model)
        }
        try context.save()
    }

    public func deleteHoleInfos(courseId: String) throws {
        let d = FetchDescriptor<HoleInfoModel>(predicate: #Predicate { $0.courseId == courseId })
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }

    // MARK: - Polygons

    public func polygons(courseId: String) throws -> [CoursePolygon] {
        let d = FetchDescriptor<PolygonModel>(predicate: #Predicate { $0.courseId == courseId })
        return try context.fetch(d).compactMap { $0.toValue() }
    }

    public func polygons(courseId: String, hole: Int) throws -> [CoursePolygon] {
        let d = FetchDescriptor<PolygonModel>(predicate: #Predicate {
            $0.courseId == courseId && ($0.holeNumber == hole || $0.holeNumber == 0)
        })
        return try context.fetch(d).compactMap { $0.toValue() }
    }

    public func insertPolygons(_ polygons: [CoursePolygon]) throws {
        for p in polygons {
            guard let data = try? JSONEncoder().encode(p.coordinates) else { continue }
            let model = PolygonModel(
                id: p.id, courseId: p.courseId,
                holeNumber: p.holeNumber ?? 0,
                surfaceRaw: p.surface.rawValue,
                coordsJSON: data
            )
            context.insert(model)
        }
        try context.save()
    }

    public func deletePolygon(id: String) throws {
        var d = FetchDescriptor<PolygonModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let m = try context.fetch(d).first {
            context.delete(m)
            try context.save()
        }
    }

    public func deletePolygons(courseId: String, hole: Int) throws {
        let d = FetchDescriptor<PolygonModel>(predicate: #Predicate {
            $0.courseId == courseId && $0.holeNumber == hole
        })
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }

    public func deletePolygons(courseId: String) throws {
        let d = FetchDescriptor<PolygonModel>(predicate: #Predicate { $0.courseId == courseId })
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }

    // MARK: - Course shots

    public func shots(courseId: String, hole: Int) throws -> [CourseShot] {
        let d = FetchDescriptor<CourseShotModel>(
            predicate: #Predicate { $0.courseId == courseId && $0.holeNumber == hole },
            sortBy: [SortDescriptor(\.shotNumber)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    @discardableResult
    public func createShot(_ shot: CourseShot) throws -> CourseShot {
        let model = CourseShotModel(
            id: shot.id, courseId: shot.courseId,
            holeNumber: shot.holeNumber, shotNumber: shot.shotNumber,
            clubId: shot.clubId ?? "",
            startLat: shot.startLat, startLng: shot.startLng,
            endLat: shot.endLat, endLng: shot.endLng,
            accuracy: shot.accuracy, timestamp: shot.timestamp
        )
        model.sessionId = shot.sessionId
        model.kind = shot.kind
        model.excludedFromDistances = shot.excludedFromDistances
        model.penaltyStrokes = shot.penaltyStrokes
        context.insert(model)
        try context.save()
        return shot
    }

    public func shots(sessionId: String) throws -> [CourseShot] {
        let all = try context.fetch(FetchDescriptor<CourseShotModel>(sortBy: [SortDescriptor(\.timestamp)]))
        return all.filter { $0.sessionId == sessionId }.map { $0.toValue() }
    }

    public func shots(clubId: String) throws -> [CourseShot] {
        let descriptor = FetchDescriptor<CourseShotModel>(predicate: #Predicate { $0.clubId == clubId }, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try context.fetch(descriptor).map { $0.toValue() }
    }

    public func updateShot(_ shot: CourseShot) throws {
        let id = shot.id
        guard let model = try context.fetch(FetchDescriptor<CourseShotModel>(predicate: #Predicate { $0.id == id })).first else { return }
        model.clubId = shot.clubId ?? ""
        model.sessionId = shot.sessionId
        model.kind = shot.kind
        model.excludedFromDistances = shot.excludedFromDistances
        model.penaltyStrokes = shot.penaltyStrokes
        model.startLat = shot.startLat; model.startLng = shot.startLng
        model.endLat = shot.endLat; model.endLng = shot.endLng
        model.accuracy = shot.accuracy
        try context.save()
    }

    public func deleteShot(id: String) throws {
        for model in try context.fetch(FetchDescriptor<CourseShotModel>(predicate: #Predicate { $0.id == id })) {
            context.delete(model)
        }
        try context.save()
    }

    public func deleteShots(courseId: String, hole: Int) throws {
        let d = FetchDescriptor<CourseShotModel>(
            predicate: #Predicate { $0.courseId == courseId && $0.holeNumber == hole }
        )
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }

    // MARK: - Rounds

    public func rounds(limit: Int = 100) throws -> [RoundSummary] {
        var d = FetchDescriptor<RoundModel>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        d.fetchLimit = limit
        return try context.fetch(d).map { $0.toValue() }
    }

    public func rounds(courseId: String) throws -> [RoundSummary] {
        let d = FetchDescriptor<RoundModel>(
            predicate: #Predicate { $0.courseId == courseId },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try context.fetch(d).map { $0.toValue() }
    }

    public func round(id: String) throws -> RoundSummary? {
        var d = FetchDescriptor<RoundModel>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first?.toValue()
    }

    @discardableResult
    public func createRound(_ round: RoundSummary) throws -> RoundSummary {
        let model = RoundModel(
            id: round.id, courseId: round.courseId, courseName: round.courseName,
            startedAt: round.startedAt, completedAt: round.completedAt,
            holeCount: round.holeCount, startHole: round.startHole,
            totalScore: round.totalScore, totalPar: round.totalPar,
            holesPlayed: round.holesPlayed, totalPutts: round.totalPutts,
            fairwaysHit: round.fairwaysHit, fairwaysTotal: round.fairwaysTotal,
            greensHit: round.greensHit, greensTotal: round.greensTotal,
            upAndDowns: round.upAndDowns, upAndDownAttempts: round.upAndDownAttempts,
            sgTotal: round.sgTotal, sgAvg: round.sgAvg, sgShotCount: round.sgShotCount,
            scoresJSON: try? JSONEncoder().encode(round.scores)
        )
        context.insert(model)
        try context.save()
        return round
    }

    public func associateLegacyShots(sessionId: String) throws {
        guard let round = try round(id: sessionId) else { return }
        let rounds = try rounds(courseId: round.courseId)
        let models = try context.fetch(FetchDescriptor<CourseShotModel>())
        for model in models where model.sessionId == nil && model.courseId == round.courseId {
            let matches = rounds.filter { model.timestamp >= $0.startedAt && model.timestamp <= $0.completedAt }
            if matches.count == 1, matches[0].id == sessionId { model.sessionId = sessionId }
        }
        try context.save()
    }

    public func updateHoleScore(sessionId: String, hole: Int, score: Int, putts: Int, penalties: Int) throws {
        guard (1...30).contains(score), (0...15).contains(putts), (0...15).contains(penalties), putts + penalties <= score else {
            throw WatchRoundBridge.ImportError.invalidShot
        }
        guard let model = try context.fetch(FetchDescriptor<RoundModel>(predicate: #Predicate { $0.id == sessionId })).first else { return }
        var scores = model.toValue().scores
        guard let index = scores.firstIndex(where: { $0.hole == hole }) else { return }
        scores[index].score = score
        scores[index].putts = putts
        scores[index].penaltyStrokes = penalties
        model.scoresJSON = try JSONEncoder().encode(scores)
        let played = scores.filter { $0.score > 0 }
        model.totalScore = played.reduce(0) { $0 + $1.score }
        model.totalPar = played.reduce(0) { $0 + $1.par }
        model.totalPutts = played.compactMap(\.putts).reduce(0, +)
        model.holesPlayed = played.count
        try context.save()
    }

    public func deleteRound(id: String) throws {
        let d = FetchDescriptor<RoundModel>(predicate: #Predicate { $0.id == id })
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }
}
