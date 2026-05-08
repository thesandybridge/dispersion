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
public final class HoleInfoModel {
    @Attribute(.unique) public var id: String
    public var courseId: String
    public var holeNumber: Int
    public var par: Int = 4
    public var handicap: Int = 0
    // Legacy scalar fields (kept for backward compat with existing data)
    public var yardage: Int = 0
    public var teeLat: Double?
    public var teeLng: Double?
    public var pinLat: Double?
    public var pinLng: Double?
    // New: JSON-encoded arrays for multiple tees and pin positions
    public var teeBoxesJSON: Data?
    public var pinPositionsJSON: Data?

    public init(id: String, courseId: String, holeNumber: Int,
                par: Int = 4, handicap: Int = 0,
                yardage: Int = 0,
                teeLat: Double? = nil, teeLng: Double? = nil,
                pinLat: Double? = nil, pinLng: Double? = nil,
                teeBoxesJSON: Data? = nil, pinPositionsJSON: Data? = nil) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.par = par
        self.handicap = handicap
        self.yardage = yardage
        self.teeLat = teeLat
        self.teeLng = teeLng
        self.pinLat = pinLat
        self.pinLng = pinLng
        self.teeBoxesJSON = teeBoxesJSON
        self.pinPositionsJSON = pinPositionsJSON
    }

    public func toValue() -> HoleInfo {
        // Prefer JSON arrays if available; fall back to legacy scalar fields
        let tees: [TeeBox]
        if let data = teeBoxesJSON, let decoded = try? JSONDecoder().decode([TeeBox].self, from: data), !decoded.isEmpty {
            tees = decoded
        } else if let lat = teeLat, let lng = teeLng {
            tees = [TeeBox(name: "White", color: "white", coord: Coord(lat: lat, lng: lng), yardage: yardage)]
        } else {
            tees = []
        }

        let pins: [HolePinPosition]
        if let data = pinPositionsJSON, let decoded = try? JSONDecoder().decode([HolePinPosition].self, from: data) {
            pins = decoded
        } else if let lat = pinLat, let lng = pinLng {
            pins = [
                HolePinPosition(zone: .front),
                HolePinPosition(zone: .middle, coord: Coord(lat: lat, lng: lng)),
                HolePinPosition(zone: .back)
            ]
        } else {
            pins = PinZone.allCases.map { HolePinPosition(zone: $0) }
        }

        return HoleInfo(
            id: id, courseId: courseId, holeNumber: holeNumber,
            par: par, handicap: handicap,
            teeBoxes: tees, pinPositions: pins
        )
    }
}

@Model
public final class RoundModel {
    @Attribute(.unique) public var id: String
    public var courseId: String
    public var courseName: String
    public var startedAt: Date
    public var completedAt: Date
    public var holeCount: Int = 18
    public var startHole: Int = 1
    public var totalScore: Int = 0
    public var totalPar: Int = 0
    public var holesPlayed: Int = 0
    public var totalPutts: Int = 0
    public var fairwaysHit: Int = 0
    public var fairwaysTotal: Int = 0
    public var greensHit: Int = 0
    public var greensTotal: Int = 0
    public var upAndDowns: Int = 0
    public var upAndDownAttempts: Int = 0
    public var sgTotal: Double = 0
    public var sgAvg: Double = 0
    public var sgShotCount: Int = 0
    public var scoresJSON: Data?

    public init(
        id: String, courseId: String, courseName: String,
        startedAt: Date, completedAt: Date = .now,
        holeCount: Int = 18, startHole: Int = 1,
        totalScore: Int = 0, totalPar: Int = 0, holesPlayed: Int = 0,
        totalPutts: Int = 0,
        fairwaysHit: Int = 0, fairwaysTotal: Int = 0,
        greensHit: Int = 0, greensTotal: Int = 0,
        upAndDowns: Int = 0, upAndDownAttempts: Int = 0,
        sgTotal: Double = 0, sgAvg: Double = 0, sgShotCount: Int = 0,
        scoresJSON: Data? = nil
    ) {
        self.id = id; self.courseId = courseId; self.courseName = courseName
        self.startedAt = startedAt; self.completedAt = completedAt
        self.holeCount = holeCount; self.startHole = startHole
        self.totalScore = totalScore; self.totalPar = totalPar; self.holesPlayed = holesPlayed
        self.totalPutts = totalPutts
        self.fairwaysHit = fairwaysHit; self.fairwaysTotal = fairwaysTotal
        self.greensHit = greensHit; self.greensTotal = greensTotal
        self.upAndDowns = upAndDowns; self.upAndDownAttempts = upAndDownAttempts
        self.sgTotal = sgTotal; self.sgAvg = sgAvg; self.sgShotCount = sgShotCount
        self.scoresJSON = scoresJSON
    }

    public func toValue() -> RoundSummary {
        let scores = scoresJSON.flatMap { try? JSONDecoder().decode([HoleScore].self, from: $0) } ?? []
        return RoundSummary(
            id: id, courseId: courseId, courseName: courseName,
            startedAt: startedAt, completedAt: completedAt,
            holeCount: holeCount, startHole: startHole,
            totalScore: totalScore, totalPar: totalPar, holesPlayed: holesPlayed,
            totalPutts: totalPutts,
            fairwaysHit: fairwaysHit, fairwaysTotal: fairwaysTotal,
            greensHit: greensHit, greensTotal: greensTotal,
            upAndDowns: upAndDowns, upAndDownAttempts: upAndDownAttempts,
            sgTotal: sgTotal, sgAvg: sgAvg, sgShotCount: sgShotCount,
            scores: scores
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
