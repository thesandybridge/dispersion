// Course map data models. Separate from the club/shot models since these
// deal with absolute GPS coordinates and polygon geometry.

import Foundation

// MARK: - Surface types from OSM golf=* tags

public enum SurfaceType: String, Codable, CaseIterable, Sendable {
    case green
    case fairway
    case tee
    case bunker
    case water
    case rough

    public var zOrder: Int {
        switch self {
        case .rough:   return 0
        case .fairway: return 1
        case .bunker:  return 2
        case .water:   return 3
        case .green:   return 4
        case .tee:     return 5
        }
    }
}

// MARK: - Coordinate

public struct Coord: Hashable, Codable, Sendable {
    public var lat: Double
    public var lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

// MARK: - Course

public struct Course: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var centerLat: Double
    public var centerLng: Double
    public var holeCount: Int
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
}

// MARK: - Course polygon

public struct CoursePolygon: Identifiable, Hashable, Sendable {
    public var id: String
    public var courseId: String
    public var holeNumber: Int?
    public var surface: SurfaceType
    public var coordinates: [Coord]

    public init(id: String, courseId: String, holeNumber: Int? = nil,
                surface: SurfaceType, coordinates: [Coord]) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.surface = surface
        self.coordinates = coordinates
    }
}

// MARK: - Course hole (derived from polygons)

public struct CourseHole: Identifiable, Hashable, Sendable {
    public var id: Int { number }
    public var number: Int
    public var par: Int
    public var polygons: [CoursePolygon]

    public var greenCenter: Coord? {
        polygons.first(where: { $0.surface == .green }).map { centroid($0.coordinates) }
    }

    public var teeCenter: Coord? {
        polygons.first(where: { $0.surface == .tee }).map { centroid($0.coordinates) }
    }

    public var estimatedYards: Int? {
        guard let tee = teeCenter, let green = greenCenter else { return nil }
        return Int(haversineYards(from: tee, to: green))
    }
}

// MARK: - Tee box

public struct TeeBox: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var name: String       // display name ("Tips", "Members", etc.)
    public var color: String      // "blue", "white", "red", "gold", "black"
    public var coord: Coord?
    public var yardage: Int

    public init(id: String = UUID().uuidString.lowercased(),
                name: String, color: String, coord: Coord? = nil, yardage: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.coord = coord
        self.yardage = yardage
    }

    public static let defaultColors: [(name: String, color: String)] = [
        ("Blue", "blue"), ("White", "white"), ("Red", "red"), ("Gold", "gold")
    ]
}

// MARK: - Pin position

public enum PinZone: String, Codable, CaseIterable, Sendable {
    case front, middle, back

    public var label: String { rawValue.capitalized }
}

public struct HolePinPosition: Hashable, Codable, Sendable {
    public var zone: PinZone
    public var coord: Coord?

    public init(zone: PinZone, coord: Coord? = nil) {
        self.zone = zone
        self.coord = coord
    }
}

// MARK: - Hole info (local-first)

public struct HoleInfo: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var courseId: String
    public var holeNumber: Int
    public var par: Int
    public var handicap: Int
    public var teeBoxes: [TeeBox]
    public var pinPositions: [HolePinPosition]

    public init(
        id: String = UUID().uuidString.lowercased(),
        courseId: String, holeNumber: Int,
        par: Int = 4, handicap: Int = 0,
        teeBoxes: [TeeBox] = [],
        pinPositions: [HolePinPosition] = PinZone.allCases.map { HolePinPosition(zone: $0) }
    ) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.par = par
        self.handicap = handicap
        self.teeBoxes = teeBoxes
        self.pinPositions = pinPositions
    }

    public func teeBox(named name: String) -> TeeBox? {
        teeBoxes.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public func pin(_ zone: PinZone) -> Coord? {
        pinPositions.first { $0.zone == zone }?.coord
    }

    public func yardage(tee name: String) -> Int {
        teeBox(named: name)?.yardage ?? 0
    }

    // Convenience: first tee with a coord
    public var firstTeeCoord: Coord? { teeBoxes.first(where: { $0.coord != nil })?.coord }
    // Convenience: active pin (middle preferred, then first available)
    public var defaultPinCoord: Coord? {
        pin(.middle) ?? pin(.front) ?? pin(.back)
    }
}

// MARK: - Course shot (absolute GPS)

public struct CourseShot: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var courseId: String
    public var holeNumber: Int
    public var shotNumber: Int
    public var clubId: String?
    public var startLat: Double
    public var startLng: Double
    public var endLat: Double
    public var endLng: Double
    public var accuracy: Double
    public var timestamp: Date

    public init(id: String, courseId: String, holeNumber: Int, shotNumber: Int,
                clubId: String? = nil,
                startLat: Double, startLng: Double,
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

    public var distanceYards: Double {
        haversineYards(from: Coord(lat: startLat, lng: startLng),
                       to: Coord(lat: endLat, lng: endLng))
    }
}

// MARK: - Round summary (persisted after round completion)

public struct RoundSummary: Identifiable, Hashable, Sendable {
    public var id: String
    public var courseId: String
    public var courseName: String
    public var startedAt: Date
    public var completedAt: Date
    public var holeCount: Int
    public var startHole: Int
    public var totalScore: Int
    public var totalPar: Int
    public var holesPlayed: Int
    public var totalPutts: Int
    public var fairwaysHit: Int
    public var fairwaysTotal: Int
    public var greensHit: Int
    public var greensTotal: Int
    public var upAndDowns: Int
    public var upAndDownAttempts: Int
    public var sgTotal: Double
    public var sgAvg: Double
    public var sgShotCount: Int
    public var scores: [HoleScore]

    public var toPar: Int { totalScore - totalPar }
    public var girPct: Double { greensTotal > 0 ? Double(greensHit) / Double(greensTotal) : 0 }
    public var firPct: Double { fairwaysTotal > 0 ? Double(fairwaysHit) / Double(fairwaysTotal) : 0 }
    public var puttsPerHole: Double { holesPlayed > 0 ? Double(totalPutts) / Double(holesPlayed) : 0 }
}

// MARK: - Geo math

public func haversineYards(from a: Coord, to b: Coord) -> Double {
    let R = 6371000.0 // earth radius meters
    let dLat = (b.lat - a.lat) * .pi / 180
    let dLng = (b.lng - a.lng) * .pi / 180
    let lat1 = a.lat * .pi / 180
    let lat2 = b.lat * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
    let c = 2 * atan2(sqrt(h), sqrt(1 - h))
    let meters = R * c
    return meters * 1.09361 // meters to yards
}

public func centroid(_ coords: [Coord]) -> Coord {
    guard !coords.isEmpty else { return Coord(lat: 0, lng: 0) }
    let n = Double(coords.count)
    let lat = coords.reduce(0.0) { $0 + $1.lat } / n
    let lng = coords.reduce(0.0) { $0 + $1.lng } / n
    return Coord(lat: lat, lng: lng)
}

/// Ray casting point-in-polygon test
public func pointInPolygon(_ point: Coord, polygon: [Coord]) -> Bool {
    guard polygon.count >= 3 else { return false }
    var inside = false
    var j = polygon.count - 1
    for i in 0..<polygon.count {
        let pi = polygon[i], pj = polygon[j]
        if (pi.lng > point.lng) != (pj.lng > point.lng) {
            let intersectLat = (pj.lat - pi.lat) * (point.lng - pi.lng) / (pj.lng - pi.lng) + pi.lat
            if point.lat < intersectLat { inside.toggle() }
        }
        j = i
    }
    return inside
}

public func boundingBox(_ coords: [Coord]) -> (min: Coord, max: Coord) {
    guard let first = coords.first else {
        return (Coord(lat: 0, lng: 0), Coord(lat: 0, lng: 0))
    }
    var minLat = first.lat, maxLat = first.lat
    var minLng = first.lng, maxLng = first.lng
    for c in coords {
        minLat = min(minLat, c.lat)
        maxLat = max(maxLat, c.lat)
        minLng = min(minLng, c.lng)
        maxLng = max(maxLng, c.lng)
    }
    return (Coord(lat: minLat, lng: minLng), Coord(lat: maxLat, lng: maxLng))
}
