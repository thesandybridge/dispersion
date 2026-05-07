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
        // Cascade: delete polygons + shots
        let pd = FetchDescriptor<PolygonModel>(predicate: #Predicate { $0.courseId == id })
        for m in try context.fetch(pd) { context.delete(m) }
        let sd = FetchDescriptor<CourseShotModel>(predicate: #Predicate { $0.courseId == id })
        for m in try context.fetch(sd) { context.delete(m) }
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
        context.insert(model)
        try context.save()
        return shot
    }

    public func deleteShots(courseId: String, hole: Int) throws {
        let d = FetchDescriptor<CourseShotModel>(
            predicate: #Predicate { $0.courseId == courseId && $0.holeNumber == hole }
        )
        for m in try context.fetch(d) { context.delete(m) }
        try context.save()
    }
}
