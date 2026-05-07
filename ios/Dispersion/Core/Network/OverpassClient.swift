// Fetches golf course polygon data from OpenStreetMap via the Overpass API.
// One-time import per course — results are persisted locally and never
// re-fetched unless explicitly refreshed.

import Foundation

public enum OverpassClient {
    private static let endpoint = "https://overpass-api.de/api/interpreter"

    public struct CourseResult: Sendable {
        public var name: String
        public var center: Coord
        public var polygons: [CoursePolygon]
        public var missingSurfaces: [SurfaceType]
    }

    // MARK: - Search for courses near a location

    public static func searchCourses(lat: Double, lng: Double, radiusMeters: Double = 10000) async throws -> [(name: String, center: Coord)] {
        let query = """
        [out:json][timeout:25];
        (
          way["leisure"="golf_course"](around:\(Int(radiusMeters)),\(lat),\(lng));
          relation["leisure"="golf_course"](around:\(Int(radiusMeters)),\(lat),\(lng));
        );
        out center;
        """
        let data = try await post(query: query)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let elements = json?["elements"] as? [[String: Any]] ?? []

        return elements.compactMap { el in
            let tags = el["tags"] as? [String: String] ?? [:]
            let name = tags["name"] ?? "Unknown Course"
            if let center = el["center"] as? [String: Double],
               let lat = center["lat"], let lng = center["lon"] {
                return (name, Coord(lat: lat, lng: lng))
            }
            if let lat = el["lat"] as? Double, let lng = el["lon"] as? Double {
                return (name, Coord(lat: lat, lng: lng))
            }
            return nil
        }
    }

    // MARK: - Fetch polygons for a specific course area

    public static func fetchCourse(name: String, center: Coord, radiusMeters: Double = 1500) async throws -> CourseResult {
        let lat = center.lat
        let lng = center.lng
        let r = Int(radiusMeters)

        let query = """
        [out:json][timeout:30];
        (
          way["golf"="green"](around:\(r),\(lat),\(lng));
          way["golf"="fairway"](around:\(r),\(lat),\(lng));
          way["golf"="tee"](around:\(r),\(lat),\(lng));
          way["golf"="bunker"](around:\(r),\(lat),\(lng));
          way["golf"="water_hazard"](around:\(r),\(lat),\(lng));
          way["natural"="water"](around:\(r),\(lat),\(lng));
          way["golf"="rough"](around:\(r),\(lat),\(lng));
        );
        out body;
        >;
        out skel qt;
        """

        let data = try await post(query: query)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let elements = json?["elements"] as? [[String: Any]] ?? []

        // Build node lookup (id → lat/lng)
        var nodes: [Int: Coord] = [:]
        for el in elements {
            guard el["type"] as? String == "node",
                  let id = el["id"] as? Int,
                  let lat = el["lat"] as? Double,
                  let lng = el["lon"] as? Double
            else { continue }
            nodes[id] = Coord(lat: lat, lng: lng)
        }

        // Parse ways into polygons
        let courseId = UUID().uuidString.lowercased()
        var polygons: [CoursePolygon] = []
        var foundSurfaces: Set<SurfaceType> = []

        for el in elements {
            guard el["type"] as? String == "way",
                  let nodeIds = el["nodes"] as? [Int],
                  let tags = el["tags"] as? [String: String]
            else { continue }

            let surface = parseSurface(tags)
            guard let surface else { continue }

            let coords = nodeIds.compactMap { nodes[$0] }
            guard coords.count >= 3 else { continue }

            let holeNumber = parseHoleNumber(tags)
            foundSurfaces.insert(surface)

            polygons.append(CoursePolygon(
                id: UUID().uuidString.lowercased(),
                courseId: courseId,
                holeNumber: holeNumber,
                surface: surface,
                coordinates: coords
            ))
        }

        let missing = SurfaceType.allCases.filter { !foundSurfaces.contains($0) }

        return CourseResult(
            name: name,
            center: center,
            polygons: polygons,
            missingSurfaces: missing
        )
    }

    // MARK: - Helpers

    private static func parseSurface(_ tags: [String: String]) -> SurfaceType? {
        if let golf = tags["golf"] {
            switch golf {
            case "green": return .green
            case "fairway": return .fairway
            case "tee", "tee_box": return .tee
            case "bunker": return .bunker
            case "water_hazard": return .water
            case "rough": return .rough
            default: break
            }
        }
        if tags["natural"] == "water" { return .water }
        return nil
    }

    private static func parseHoleNumber(_ tags: [String: String]) -> Int? {
        if let ref = tags["ref"], let n = Int(ref) { return n }
        if let name = tags["name"] {
            let digits = name.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let n = Int(digits), n >= 1 && n <= 18 { return n }
        }
        return nil
    }

    private static func post(query: String) async throws -> Data {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = "data=\(query)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OverpassError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    public enum OverpassError: LocalizedError {
        case httpError(Int)
        public var errorDescription: String? {
            switch self {
            case .httpError(let code): return "Overpass API returned HTTP \(code)"
            }
        }
    }
}
