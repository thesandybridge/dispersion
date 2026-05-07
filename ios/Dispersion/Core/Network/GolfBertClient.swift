// GolfBert API client with AWS Signature V4 authentication.
// Provides course search, hole data, tee boxes, polygons, and scorecards.

import CommonCrypto
import Foundation

public enum GolfBertClient {
    private static let accessKey = "AKIAY4WGH3URHAEQSAEV"
    private static let secretKey = "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"
    private static let apiKey = "fRDCjl0ZQd1ioug9oEQb26WtZobeYZmT3tCN5IM5"
    private static let host = "api.golfbert.com"
    private static let region = "us-east-1"
    private static let service = "execute-api"

    // MARK: - Public API

    public static func searchCourses(name: String? = nil, lat: Double? = nil, lng: Double? = nil, limit: Int = 20) async throws -> [GBCourse] {
        var params: [(String, String)] = [("limit", "\(limit)")]
        if let name { params.append(("name", name)) }
        if let lat { params.append(("lat", "\(lat)")) }
        if let lng { params.append(("lng", "\(lng)")) }
        let data = try await fetch("/v1/courses", params)
        let resp = try JSONDecoder().decode(GBListResponse<GBCourse>.self, from: data)
        return resp.resources
    }

    public static func getHoles(courseId: Int) async throws -> [GBHole] {
        let data = try await fetch("/v1/courses/\(courseId)/holes")
        let resp = try JSONDecoder().decode(GBListResponse<GBHole>.self, from: data)
        return resp.resources
    }

    public static func getScorecard(courseId: Int) async throws -> GBScorecard {
        let data = try await fetch("/v1/courses/\(courseId)/scorecard")
        return try JSONDecoder().decode(GBScorecard.self, from: data)
    }

    public static func getPolygons(holeId: Int) async throws -> [GBPolygon] {
        let data = try await fetch("/v1/holes/\(holeId)/polygons")
        let resp = try JSONDecoder().decode(GBListResponse<GBPolygon>.self, from: data)
        return resp.resources
    }

    // MARK: - Response types

    public struct GBListResponse<T: Codable>: Codable {
        public let resources: [T]
    }

    public struct GBCourse: Codable, Identifiable {
        public let id: Int
        public let name: String
        public let address: GBAddress?
        public let phonenumber: String?
        public let coordinates: GBCoord?
    }

    public struct GBAddress: Codable {
        public let street: String?
        public let city: String?
        public let state: String?
        public let zip: String?
        public let country: String?

        public var displayString: String {
            [city, state].compactMap { $0 }.joined(separator: ", ")
        }
    }

    public struct GBCoord: Codable {
        public let lat: Double
        public let long: Double
    }

    public struct GBHole: Codable, Identifiable {
        public let id: Int
        public let number: Int
        public let courseid: Int
        public let rotation: Double?
        public let vectors: [GBVector]?
        public let flagcoords: GBCoord?

        public var flagPosition: Coord? {
            flagcoords.map { Coord(lat: $0.lat, lng: $0.long) }
        }

        public func teePosition(color: String) -> Coord? {
            vectors?.first(where: { $0.type == color }).map { Coord(lat: $0.lat, lng: $0.long) }
        }
    }

    public struct GBVector: Codable {
        public let type: String  // "Flag", "Blue", "White", "Red"
        public let lat: Double
        public let long: Double
    }

    public struct GBScorecard: Codable {
        public let courseid: Int
        public let holeteeboxes: [GBHoleTeebox]
    }

    public struct GBHoleTeebox: Codable {
        public let holeid: Int
        public let holenumber: Int
        public let color: String
        public let length: Int
        public let par: Int
        public let handicap: Int
        public let teeboxtype: String
    }

    public struct GBPolygon: Codable {
        public let holeid: Int
        public let surfacetype: String
        public let polygon: [GBCoord]

        public var surface: SurfaceType? {
            switch surfacetype.lowercased() {
            case "fairway": return .fairway
            case "green": return .green
            case "bunker", "sand": return .bunker
            case "water": return .water
            case "tee", "teebox": return .tee
            case "rough": return .rough
            default: return nil
            }
        }
    }

    // MARK: - AWS Sig V4

    private static func fetch(_ path: String, _ params: [(String, String)] = []) async throws -> Data {
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        df.timeZone = TimeZone(identifier: "UTC")
        let amzDate = df.string(from: now)
        let dateStamp = String(amzDate.prefix(8))

        let sorted = params.sorted { $0.0 < $1.0 }
        let queryString = sorted.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        }.joined(separator: "&")

        let payloadHash = sha256("")
        let canonicalHeaders = "host:\(host)\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-date"
        let canonicalRequest = "GET\n\(path)\n\(queryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(credentialScope)\n\(sha256(canonicalRequest))"

        let kDate = hmacSHA256(key: "AWS4\(secretKey)".data(using: .utf8)!, data: dateStamp.data(using: .utf8)!)
        let kRegion = hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        let signature = hmacSHA256(key: kSigning, data: stringToSign.data(using: .utf8)!)
            .map { String(format: "%02x", $0) }.joined()

        let auth = "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var urlString = "https://\(host)\(path)"
        if !queryString.isEmpty { urlString += "?\(queryString)" }

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GBError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { kp in
            data.withUnsafeBytes { dp in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       kp.baseAddress!, key.count,
                       dp.baseAddress!, data.count, &hash)
            }
        }
        return Data(hash)
    }

    private static func sha256(_ str: String) -> String {
        let data = str.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress!, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    public enum GBError: LocalizedError {
        case httpError(Int)
        public var errorDescription: String? {
            switch self {
            case .httpError(let code): return "GolfBert API returned HTTP \(code)"
            }
        }
    }
}
