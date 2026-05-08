// Auto-fill: snapshot the map at the crosshair, flood-fill from the center
// pixel, trace the boundary, convert back to coordinates.

import MapKit
import SwiftUI

@MainActor
enum MapAutoFill {

    struct FillResult {
        var coordinates: [Coord]
    }

    enum FillError: LocalizedError {
        case noImage, noPixelData, tooSmall

        var errorDescription: String? {
            switch self {
            case .noImage: return "Could not capture map"
            case .noPixelData: return "Could not read pixels"
            case .tooSmall: return "Region too small — zoom in closer"
            }
        }
    }

    static func fill(
        center: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        tolerance: Int = 20
    ) async throws -> FillResult {
        // Capture 3x wider than viewport so large features (fairways) are
        // fully visible even when zoomed in for precision
        let wideSpan = MKCoordinateSpan(
            latitudeDelta: span.latitudeDelta * 3,
            longitudeDelta: span.longitudeDelta * 3
        )
        let region = MKCoordinateRegion(center: center, span: wideSpan)
        let imgSize = CGSize(width: 768, height: 768)

        // Snapshot with flat standard map (colored surfaces)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = imgSize
        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        config.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = config
        let snapshot = try await MKMapSnapshotter(options: options).start()
        guard let cg = snapshot.image.cgImage else { throw FillError.noImage }

        let scale = snapshot.image.scale
        guard let px = PixelBuffer(cgImage: cg) else { throw FillError.noPixelData }

        // Flood fill from center pixel (= crosshair position)
        let filled = px.floodFill(x: px.width / 2, y: px.height / 2, tolerance: tolerance)
        guard filled.count >= 30 else { throw FillError.tooSmall }

        // Contour trace
        let boundary = contourTrace(filled, w: px.width, h: px.height)
        guard boundary.count >= 6 else { throw FillError.tooSmall }

        // Convert boundary pixels to coordinates
        let mapping = calibrate(snapshot: snapshot, region: region, scale: scale)
        let coords = boundary.map { mapping($0.0, $0.1) }

        // Light simplification
        let simple = simplify(coords, epsilon: 0.0000015)
        guard simple.count >= 3 else { throw FillError.tooSmall }
        return FillResult(coordinates: simple)
    }

    // MARK: - Calibrate pixel→coord mapping

    /// Uses two points WITHIN the region to derive the linear mapping from
    /// snapshot pixels to geographic coordinates.
    private static func calibrate(
        snapshot: MKMapSnapshotter.Snapshot,
        region: MKCoordinateRegion,
        scale: CGFloat
    ) -> (Int, Int) -> Coord {
        // Two reference coords inside the region
        let refA = CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta * 0.25,
            longitude: region.center.longitude - region.span.longitudeDelta * 0.25
        )
        let refB = CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta * 0.25,
            longitude: region.center.longitude + region.span.longitudeDelta * 0.25
        )
        // Their pixel positions in the snapshot (in point space)
        let pA = snapshot.point(for: refA)
        let pB = snapshot.point(for: refB)

        // Degrees per pixel (in raw pixel space, accounting for scale)
        let dLat = (refB.latitude - refA.latitude) / ((pB.y - pA.y) * scale)
        let dLng = (refB.longitude - refA.longitude) / ((pB.x - pA.x) * scale)

        // Reference pixel position (in raw pixel space)
        let rpxA = pA.x * scale
        let rpyA = pA.y * scale

        return { pixelX, pixelY in
            Coord(
                lat: refA.latitude + (Double(pixelY) - rpyA) * dLat,
                lng: refA.longitude + (Double(pixelX) - rpxA) * dLng
            )
        }
    }

    // MARK: - Pixel buffer

    private final class PixelBuffer {
        let width: Int, height: Int
        private let data: [UInt8]
        private let bpr: Int

        init?(cgImage: CGImage) {
            width = cgImage.width; height = cgImage.height
            bpr = width * 4
            var buf = [UInt8](repeating: 0, count: bpr * height)
            guard let ctx = CGContext(
                data: &buf, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bpr,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.data = buf
        }

        func floodFill(x startX: Int, y startY: Int, tolerance: Int) -> Set<Int> {
            let o = startY * bpr + startX * 4
            let tr = Int(data[o]), tg = Int(data[o+1]), tb = Int(data[o+2])
            let tolSq = tolerance * tolerance * 3
            // Cap at 15% of image to prevent leaking into background
            let maxPixels = width * height * 15 / 100
            var filled = Set<Int>(minimumCapacity: 8192)
            var stack = [startY * width + startX]
            filled.insert(stack[0])
            while !stack.isEmpty {
                guard filled.count < maxPixels else { break }
                let idx = stack.removeLast()
                let x = idx % width, y = idx / width
                for (nx, ny) in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)] {
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let nIdx = ny * width + nx
                    guard !filled.contains(nIdx) else { continue }
                    let no = ny * bpr + nx * 4
                    let dr = Int(data[no]) - tr
                    let dg = Int(data[no+1]) - tg
                    let db = Int(data[no+2]) - tb
                    if dr*dr + dg*dg + db*db <= tolSq {
                        filled.insert(nIdx)
                        stack.append(nIdx)
                    }
                }
            }
            return filled
        }
    }

    // MARK: - Boundary extraction (scan-line outline)

    /// For each row of the image, find the leftmost and rightmost filled pixel.
    /// Walk down the left edge, then back up the right edge → ordered contour.
    private static func contourTrace(_ filled: Set<Int>, w: Int, h: Int) -> [(Int, Int)] {
        // Find min/max X per row
        var rowMin = [Int](repeating: Int.max, count: h)
        var rowMax = [Int](repeating: -1, count: h)
        for idx in filled {
            let x = idx % w, y = idx / w
            if x < rowMin[y] { rowMin[y] = x }
            if x > rowMax[y] { rowMax[y] = x }
        }

        // Collect active rows
        var activeRows: [Int] = []
        for y in 0..<h where rowMax[y] >= 0 {
            activeRows.append(y)
        }
        guard activeRows.count >= 2 else { return [] }

        // Walk down the left edge
        var left: [(Int, Int)] = []
        for y in activeRows { left.append((rowMin[y], y)) }

        // Walk up the right edge
        var right: [(Int, Int)] = []
        for y in activeRows.reversed() { right.append((rowMax[y], y)) }

        let full = left + right

        // Sample evenly — target ~400 points
        let target = min(full.count, 400)
        let step = max(1, full.count / target)
        var sampled: [(Int, Int)] = []
        for i in stride(from: 0, to: full.count, by: step) {
            sampled.append(full[i])
        }
        return sampled
    }

    // MARK: - Simplify

    private static func simplify(_ pts: [Coord], epsilon: Double) -> [Coord] {
        guard pts.count > 2 else { return pts }
        var dm = 0.0, idx = 0
        let end = pts.count - 1
        for i in 1..<end {
            let d = pdist(pts[i], pts[0], pts[end])
            if d > dm { dm = d; idx = i }
        }
        if dm > epsilon {
            let l = simplify(Array(pts[0...idx]), epsilon: epsilon)
            let r = simplify(Array(pts[idx...end]), epsilon: epsilon)
            return Array(l.dropLast()) + r
        }
        return [pts[0], pts[end]]
    }

    private static func pdist(_ p: Coord, _ a: Coord, _ b: Coord) -> Double {
        let dx = b.lng-a.lng, dy = b.lat-a.lat, ls = dx*dx+dy*dy
        guard ls > 0 else { return sqrt(pow(p.lng-a.lng,2)+pow(p.lat-a.lat,2)) }
        let t = max(0, min(1, ((p.lng-a.lng)*dx+(p.lat-a.lat)*dy)/ls))
        return sqrt(pow(p.lng-(a.lng+t*dx),2) + pow(p.lat-(a.lat+t*dy),2))
    }
}
