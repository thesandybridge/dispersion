// SwiftData models for course map data. Polygons stored as JSON-encoded
// coordinate arrays to keep the schema simple.

import Foundation
import SwiftData

@Model
public final class CourseModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var centerLat: Double
    public var centerLng: Double
    public var holeCount: Int = 18
    public var fetchedAt: Date

    public init(id: String, name: String, centerLat: Double, centerLng: Double,
                holeCount: Int = 18, fetchedAt: Date = .now) {
        self.id = id
        self.name = name
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.holeCount = holeCount
        self.fetchedAt = fetchedAt
    }

    public func toValue() -> Course {
        Course(id: id, name: name, centerLat: centerLat, centerLng: centerLng,
               holeCount: holeCount, fetchedAt: fetchedAt)
    }
}

@Model
public final class PolygonModel {
    @Attribute(.unique) public var id: String
    public var courseId: String
    public var holeNumber: Int = 0
    public var surfaceRaw: String
    public var coordsJSON: Data

    public init(id: String, courseId: String, holeNumber: Int = 0,
                surfaceRaw: String, coordsJSON: Data) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.surfaceRaw = surfaceRaw
        self.coordsJSON = coordsJSON
    }

    public func toValue() -> CoursePolygon? {
        guard let surface = SurfaceType(rawValue: surfaceRaw),
              let coords = try? JSONDecoder().decode([Coord].self, from: coordsJSON)
        else { return nil }
        return CoursePolygon(
            id: id, courseId: courseId,
            holeNumber: holeNumber > 0 ? holeNumber : nil,
            surface: surface, coordinates: coords
        )
    }
}

@Model
public final class CourseShotModel {
    @Attribute(.unique) public var id: String
    public var courseId: String
    public var holeNumber: Int
    public var shotNumber: Int
    public var clubId: String = ""
    public var startLat: Double
    public var startLng: Double
    public var endLat: Double
    public var endLng: Double
    public var accuracy: Double = 0
    public var timestamp: Date

    public init(id: String, courseId: String, holeNumber: Int, shotNumber: Int,
                clubId: String = "", startLat: Double, startLng: Double,
                endLat: Double, endLng: Double,
                accuracy: Double = 0, timestamp: Date = .now) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.shotNumber = shotNumber
        self.clubId = clubId
        self.startLat = startLat
        self.startLng = startLng
        self.endLat = endLat
        self.endLng = endLng
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    public func toValue() -> CourseShot {
        CourseShot(id: id, courseId: courseId, holeNumber: holeNumber,
                   shotNumber: shotNumber, clubId: clubId.isEmpty ? nil : clubId,
                   startLat: startLat, startLng: startLng,
                   endLat: endLat, endLng: endLng,
                   accuracy: accuracy, timestamp: timestamp)
    }
}
