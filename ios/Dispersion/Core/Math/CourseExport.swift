// Export/import individual courses as shareable JSON files.

import Foundation

public enum CourseExport {

    // MARK: - Export

    public static func build(course: Course, holeInfos: [HoleInfo], polygons: [CoursePolygon]) -> Data {
        let payload = CoursePayload(
            version: 1,
            course: .init(
                name: course.name,
                centerLat: course.centerLat,
                centerLng: course.centerLng,
                holeCount: course.holeCount
            ),
            holeInfos: holeInfos.map { info in
                .init(
                    holeNumber: info.holeNumber,
                    par: info.par,
                    handicap: info.handicap,
                    teeBoxes: info.teeBoxes,
                    pinPositions: info.pinPositions
                )
            },
            polygons: polygons.map { poly in
                .init(
                    holeNumber: poly.holeNumber ?? 0,
                    surface: poly.surface.rawValue,
                    coordinates: poly.coordinates
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    // MARK: - Import

    public struct ParsedCourse {
        public var course: Course
        public var holeInfos: [HoleInfo]
        public var polygons: [CoursePolygon]
    }

    public static func parse(_ data: Data) throws -> ParsedCourse {
        let payload = try JSONDecoder().decode(CoursePayload.self, from: data)
        guard payload.version == 1 else {
            throw ExportError.unsupportedVersion(payload.version)
        }

        let courseId = UUID().uuidString.lowercased()
        let course = Course(
            id: courseId,
            name: payload.course.name,
            centerLat: payload.course.centerLat,
            centerLng: payload.course.centerLng,
            holeCount: payload.course.holeCount
        )

        let holeInfos = payload.holeInfos.map { h in
            HoleInfo(
                courseId: courseId,
                holeNumber: h.holeNumber,
                par: h.par,
                handicap: h.handicap,
                teeBoxes: h.teeBoxes,
                pinPositions: h.pinPositions
            )
        }

        let polygons = payload.polygons.map { p in
            CoursePolygon(
                id: UUID().uuidString.lowercased(),
                courseId: courseId,
                holeNumber: p.holeNumber > 0 ? p.holeNumber : nil,
                surface: SurfaceType(rawValue: p.surface) ?? .fairway,
                coordinates: p.coordinates
            )
        }

        return ParsedCourse(course: course, holeInfos: holeInfos, polygons: polygons)
    }

    public enum ExportError: LocalizedError {
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v): return "Unsupported course file version: \(v)"
            }
        }
    }
}

// MARK: - Codable payload

private struct CoursePayload: Codable {
    var version: Int
    var course: CourseEntry
    var holeInfos: [HoleEntry]
    var polygons: [PolygonEntry]

    struct CourseEntry: Codable {
        var name: String
        var centerLat: Double
        var centerLng: Double
        var holeCount: Int
    }

    struct HoleEntry: Codable {
        var holeNumber: Int
        var par: Int
        var handicap: Int
        var teeBoxes: [TeeBox]
        var pinPositions: [HolePinPosition]
    }

    struct PolygonEntry: Codable {
        var holeNumber: Int
        var surface: String
        var coordinates: [Coord]
    }
}
